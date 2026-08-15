"""The dashboard, and the process the copy loop runs inside.

Five pages -- Copier, Trade, Accounts, Orders, Positions -- server-rendered
with Flask and Jinja. No database, no login, no build step, no client
framework, and deliberately no auto-refresh: each page renders fresh on load
and the viewer reloads for new data. Every page stamps the time it was
rendered, so a stale tab is obviously a stale tab.

CONFIGURATION IS VIEW-ONLY. Accounts, sizing and settings live in `.env`, so
the pages report them and name the variable to change. There is no accounts
screen and no settings form, because an app with no database has nowhere to put
what such a form would collect.

TRADE IS THE EXCEPTION, AND IT IS NOT REALLY ONE. Its form stores nothing: it
hands an order to the broker, which is where that order lives. It places on the
MASTER only, and then stops -- the copier notices it on its next pass exactly
as it would notice an order placed on the broker's own website. Copying from
the form would place every trade twice.

EVERY PAGE ALWAYS LOADS. A broker that cannot be reached, credentials that
stopped working, a copy loop that has never run -- all of these are reported on
the page, per account, and none of them may produce a blank screen or a stack
trace.
"""

import logging
import threading
import uuid
from datetime import datetime, timezone

from flask import Flask, redirect, render_template, request, url_for

import broker
import config
import copier

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-8s %(name)s: %(message)s",
)
log = logging.getLogger("webapp")

app = Flask(__name__)
app.config["SECRET_KEY"] = config.flask_secret_key() or "dev-only-not-a-secret"

# How many of the master's orders the Copier page reads across.
COPIER_ROWS = 12

# Order types, and which extra price each one needs. The form shows only the
# fields the chosen type actually uses, and clears the others.
ORDER_TYPES = [
    ("market", "Market", []),
    ("limit", "Limit", ["limit_price"]),
    ("stop", "Stop", ["stop_price"]),
    ("stop_limit", "Stop-Limit", ["limit_price", "stop_price"]),
]

DURATIONS = [
    ("day", "Day"),
    ("gtc", "GTC -- good till cancelled"),
    ("ioc", "IOC -- immediate or cancel"),
    ("fok", "FOK -- fill or kill"),
    ("opg", "OPG -- at the open"),
    ("cls", "CLS -- at the close"),
]


# --- the engine, started once, in this same process ----------------------

ENGINE = {"copier": None, "error": None}
_ENGINE_LOCK = threading.Lock()


def start_engine():
    """Start the copy loop alongside the web pages.

    A failure here is REPORTED, not raised: a master account that cannot be
    read means there is nothing to copy, but the dashboard still has to load
    and say exactly that. A dashboard that 500s because the config is wrong is
    the one screen that cannot tell you the config is wrong.
    """
    with _ENGINE_LOCK:
        if ENGINE["copier"] is not None:
            return
        try:
            engine, _thread = copier.start()
            ENGINE["copier"] = engine
            ENGINE["error"] = None
            log.info("copy loop started")
        except Exception as error:
            ENGINE["error"] = f"{type(error).__name__}: {error}"
            log.error("the copy loop could not start: %s", ENGINE["error"])


def accounts():
    """(master, followers, problems) -- never raises.

    Returns (None, [], [problem]) when even the master is unusable, so callers
    can render the reason instead of failing.
    """
    try:
        return config.load_accounts()
    except config.ConfigError as error:
        return None, [], [config.SlotProblem(1, "ACCOUNT_1", str(error))]


def safely(call, *args, **kwargs):
    """Run one broker call and return (value, error-text).

    Every read on every page goes through this. One account's credentials
    expiring must not blank the page for the others, so a failure becomes a
    sentence next to that account rather than an exception on the way out.
    """
    try:
        return call(*args, **kwargs), None
    except Exception as error:
        message = getattr(error, "message", None) or str(error)
        log.warning("%s failed: %s", getattr(call, "__name__", call), message)
        return None, message


@app.context_processor
def shared():
    """Everything the frame needs, on every page."""
    state = copier.STATE.snapshot()
    return {
        "rendered_at": datetime.now(timezone.utc),
        "state": state,
        "engine_error": ENGINE["error"],
        "copying_enabled": config.copying_enabled(),
        "poll_seconds": config.poll_seconds(),
        "stale_order_seconds": config.stale_order_seconds(),
        # So a template can colour a status without hard-coding the list of
        # statuses that mean "this was never a trade".
        "dead": copier.DEAD_STATUSES,
    }


@app.template_filter("clock")
def clock(value):
    """A timestamp a person can scan: 21:56:35 UTC, with the date if it is old."""
    if not value:
        return "--"
    if isinstance(value, str):
        text = value.replace("Z", "+00:00")
        try:
            value = datetime.fromisoformat(text)
        except ValueError:
            return value
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    value = value.astimezone(timezone.utc)
    today = datetime.now(timezone.utc).date()
    if value.date() == today:
        return value.strftime("%H:%M:%S UTC")
    return value.strftime("%d %b %H:%M UTC")


@app.template_filter("ago")
def ago(value):
    """How long since something happened, in words."""
    if not value:
        return "never"
    if isinstance(value, str):
        try:
            value = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return value
    seconds = (datetime.now(timezone.utc) - value).total_seconds()
    if seconds < 5:
        return "just now"
    if seconds < 90:
        return "%ds ago" % int(seconds)
    if seconds < 5400:
        return "%dm ago" % int(seconds / 60)
    return "%dh ago" % int(seconds / 3600)


@app.template_filter("shares")
def shares(value):
    """Whole shares read as whole shares; fractions keep their decimals."""
    if value is None:
        return "--"
    try:
        number = float(value)
    except (TypeError, ValueError):
        return value
    return "%d" % number if number == int(number) else ("%g" % number)


@app.template_filter("money")
def money(value):
    """Cash and buying power. Operational facts only -- this app never renders
    a profit or a loss, so there is no signed or coloured variant of this."""
    if value is None:
        return "--"
    try:
        return "{:,.2f}".format(float(value))
    except (TypeError, ValueError):
        return value


# --- Copier: the page this whole app exists for --------------------------


def copy_state(master_order, follower, follower_orders, live_outcomes):
    """What became of ONE master order in ONE follower account.

    The authority is the STAMP at the broker, not anything held in memory:
    that is what makes this page still correct after a restart, when the
    activity list is empty but the copies themselves are still there.

    In-memory outcomes fill in what the broker cannot know -- why something was
    deliberately not copied.
    """
    stamp = copier.stamp_for(master_order["id"], follower)
    placed = follower_orders.get(stamp)

    if placed:
        status = placed.get("status")
        if status == "filled":
            tone = "fill"
        elif status in copier.DEAD_STATUSES:
            tone = "reject"
        else:
            tone = "pending"
        return {
            "tone": tone,
            "label": status,
            "qty": placed.get("qty"),
            "filled_qty": placed.get("filled_qty"),
            "price": placed.get("filled_avg_price"),
            "detail": None,
        }

    # Nothing at the broker. The copier may still have decided something about
    # it this pass -- a skip with a reason, or a refusal in the broker's words.
    row = live_outcomes.get((master_order["id"], follower.slot))
    if row:
        return {
            "tone": "reject" if row["state"] == "failed" else "skip",
            "label": row["state"],
            "qty": row.get("qty"),
            "filled_qty": None,
            "price": None,
            "detail": row.get("detail"),
        }

    return {
        "tone": "idle",
        "label": "not copied",
        "qty": None,
        "filled_qty": None,
        "price": None,
        "detail": None,
    }


@app.route("/")
def copier_page():
    master, followers, problems = accounts()
    rows = []
    master_error = None
    follower_errors = {}

    if master:
        master_orders, master_error = safely(broker.list_orders, master, limit=COPIER_ROWS)
        master_orders = master_orders or []

        # One read per follower, indexed by stamp. A follower that cannot be
        # read gets a reason of its own and does not stop the others.
        indexed = {}
        for follower in followers:
            orders, error = safely(broker.list_orders, follower, limit=200)
            if error:
                follower_errors[follower.slot] = error
            indexed[follower.slot] = {
                str(o.get("client_order_id")): o for o in (orders or [])
            }

        # Reasons the copier recorded this pass, keyed by (master order,
        # follower) so a skip can be shown in the cell it belongs to.
        live_outcomes = {}
        for outcome in copier.STATE.snapshot()["outcomes"]:
            for row in outcome.get("orders", []):
                live_outcomes[(row["master_order_id"], row["slot"])] = row

        for order in master_orders:
            rows.append(
                {
                    "order": order,
                    "copies": [
                        {
                            "follower": follower,
                            "state": copy_state(
                                order, follower, indexed.get(follower.slot, {}), live_outcomes
                            ),
                        }
                        for follower in followers
                    ],
                }
            )

    return render_template(
        "copier.html",
        page="copier",
        master=master,
        followers=followers,
        problems=problems,
        rows=rows,
        master_error=master_error,
        follower_errors=follower_errors,
    )


# --- Trade: where the demonstration starts -------------------------------


@app.route("/trade", methods=["GET", "POST"])
def trade_page():
    master, followers, problems = accounts()
    form = {
        "symbol": "",
        "side": "buy",
        "qty": "1",
        "order_type": "market",
        "time_in_force": "day",
        "limit_price": "",
        "stop_price": "",
    }
    result = None

    if request.method == "POST" and master:
        for field in form:
            form[field] = (request.form.get(field) or "").strip()
        form["symbol"] = form["symbol"].upper()

        problem = validate_trade(form)
        if problem:
            result = {"ok": False, "headline": "Not sent", "detail": problem}
        else:
            result = place_trade(master, form)

    return render_template(
        "trade.html",
        page="trade",
        master=master,
        followers=followers,
        problems=problems,
        form=form,
        result=result,
        # Precomputed so the confirmation modal can name each follower and its
        # sizing without weaving template logic through the script.
        follower_summary=[f"{f.alias} at {f.sizing_description}" for f in followers],
        order_types=ORDER_TYPES,
        durations=DURATIONS,
    )


def validate_trade(form):
    """Checked here, on the server, not only in the browser. Returns a reason
    or None."""
    if not form["symbol"]:
        return "Enter a ticker symbol."
    if form["side"] not in {"buy", "sell"}:
        return "Choose buy or sell."

    try:
        qty = int(form["qty"])
    except (TypeError, ValueError):
        return "Quantity must be a whole number of shares."
    if qty < 1:
        return "Quantity must be at least 1 share."

    needs = dict((code, extra) for code, _label, extra in ORDER_TYPES)
    if form["order_type"] not in needs:
        return "Choose an order type."
    for field in needs[form["order_type"]]:
        value = form[field]
        if not value:
            return f"A {field.replace('_', ' ')} is required for a {form['order_type'].replace('_', '-')} order."
        try:
            if float(value) <= 0:
                return f"The {field.replace('_', ' ')} must be greater than zero."
        except ValueError:
            return f"The {field.replace('_', ' ')} must be a number."

    if form["time_in_force"] not in dict(DURATIONS):
        return "Choose a duration."
    return None


def place_trade(master, form):
    """Send one order to the broker, on the master, and report what the BROKER
    said.

    Never reports an order as placed until the broker has accepted it: a form
    that announces what it SENT will announce success for a rejected order.
    """
    needs = dict((code, extra) for code, _label, extra in ORDER_TYPES)[form["order_type"]]

    # Not the "copy-" prefix -- that stamp belongs to orders this app copies,
    # and the copier skips any master order carrying one. This is a
    # hand-placed order, so it is stamped as one.
    stamp = "manual-%s" % uuid.uuid4().hex[:16]

    try:
        placed = broker.submit_order(
            master,
            symbol=form["symbol"],
            qty=int(form["qty"]),
            side=form["side"],
            client_order_id=stamp,
            order_type=form["order_type"],
            time_in_force=form["time_in_force"],
            limit_price=form["limit_price"] if "limit_price" in needs else None,
            stop_price=form["stop_price"] if "stop_price" in needs else None,
        )
    except Exception as error:
        message = getattr(error, "message", None) or str(error)
        log.error("order refused on %s: %s", master.alias, message)
        return {
            "ok": False,
            "headline": "The broker refused this order",
            "detail": message,
        }

    log.info(
        "order accepted on %s: %s %s %s [%s]",
        master.alias,
        form["side"],
        form["qty"],
        form["symbol"],
        placed.get("status"),
    )
    return {"ok": True, "headline": "The broker accepted this order", "order": placed}


# --- Accounts, Orders, Positions -----------------------------------------


@app.route("/accounts")
def accounts_page():
    master, followers, problems = accounts()
    cards = []
    for account in ([master] if master else []) + followers:
        detail, error = safely(broker.get_account, account)
        cards.append(
            {
                "account": account,
                "is_master": account.is_master,
                "detail": detail,
                "error": error,
            }
        )
    return render_template(
        "accounts.html",
        page="accounts",
        master=master,
        followers=followers,
        problems=problems,
        cards=cards,
    )


@app.route("/orders")
def orders_page():
    master, followers, problems = accounts()
    groups = []
    for account in ([master] if master else []) + followers:
        orders, error = safely(broker.list_orders, account, limit=25)
        groups.append(
            {
                "account": account,
                "is_master": account.is_master,
                "orders": orders or [],
                "error": error,
            }
        )
    return render_template(
        "orders.html", page="orders", master=master, problems=problems, groups=groups
    )


@app.route("/positions")
def positions_page():
    master, followers, problems = accounts()
    groups = []
    for account in ([master] if master else []) + followers:
        positions, error = safely(broker.list_positions, account)
        groups.append(
            {
                "account": account,
                "is_master": account.is_master,
                "positions": positions or [],
                "error": error,
            }
        )
    return render_template(
        "positions.html", page="positions", master=master, problems=problems, groups=groups
    )


@app.errorhandler(404)
def not_found(_error):
    return redirect(url_for("copier_page"))


@app.errorhandler(500)
def server_error(error):
    """The last line of the always-loads rule. A page that failed anyway shows
    a sentence, never a stack trace."""
    log.exception("a page failed to render: %s", error)
    return render_template("error.html", page=None, detail=str(error)), 500


start_engine()


if __name__ == "__main__":
    # No reloader: it starts a second process, and a second copy loop with it.
    app.run(host="127.0.0.1", port=5000, debug=False, use_reloader=False)

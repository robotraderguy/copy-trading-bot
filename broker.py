"""The only place this app talks to the broker.

One broker, one file: list an account's orders, list its positions, place an
order, read one order back by its stamp, and read the account itself. The first
four are the copier's whole surface; the fifth exists because the dashboard has
to show cash, buying power and per-account credential state, and none of that
is derivable from orders or positions.

ALPACA, PAPER, AND NOTHING ELSE. The base URL below is a constant on purpose.
The live URL is one word different, it is never typed in this repo, it is never
read from the environment, and it is never a parameter. A build that cannot
reach a funded account is a build that cannot drain one.

WHICH PATH THIS TAKES. There are two ways to reach Alpaca and they hand back
different things: the `alpaca-py` SDK returns pydantic objects with real Python
types inside them, and the REST endpoints return JSON. This module calls REST
directly -- it keeps the dependency list to one HTTP library, and it means no
pydantic object, UUID or enum exists anywhere in the process to leak past this
boundary in the first place. Either path is a fine choice; the point is that
this module normalizes once so the rest of the app cannot tell which was picked.

WHAT CALLERS GET BACK. Plain Python: dicts, strings, numbers. Quantities and
prices arrive from Alpaca as strings even in the SDK, so they are converted to
numbers here. Statuses are passed through as their plain strings and never
collapsed into a boolean -- deciding which of them represent a trade worth
copying belongs to the copier, not here.
"""

import json
import logging

import requests

log = logging.getLogger("broker")


# Paper. Not configurable, not overridable, not read from the environment.
BASE_URL = "https://paper-api.alpaca.markets"

# A hung request in a polling loop looks exactly like a quiet market, so every
# request is bounded. Connect is short because a paper endpoint either answers
# or does not; read is longer because a submission can genuinely take a moment.
TIMEOUT = (5, 15)

# How many orders a history query returns at most. Alpaca's own cap is 500.
DEFAULT_ORDER_LIMIT = 100


class BrokerError(Exception):
    """A refusal or a failure, carrying the broker's OWN words.

    Never replaced with a message of our own and never reduced to None or
    False: the caller logs and displays what it is given, and nothing else in
    the app can reconstruct what Alpaca actually said.
    """

    def __init__(self, message, code=None, status=None):
        super().__init__(message)
        self.message = message
        self.code = code
        self.status = status


class RateLimited(BrokerError):
    """Alpaca allows 200 requests a minute per account, and a copier pass costs
    one read of the master plus one per follower -- so a short interval and a
    few accounts can reach it.

    This is TEMPORARY, and it is deliberately its own type so it can never be
    mistaken for a refusal of the order. Nothing was rejected; back off and let
    the next pass try again.
    """


def _headers(account):
    """Auth is a PAIR, and it is built per call from the account being acted on.

    There is deliberately no module-level client configured once at import: this
    app talks to several accounts, and a single shared client is exactly how a
    follower's order ends up placed in the master. That bug shows up as an order
    in the wrong place rather than as an error, so the structure has to prevent
    it rather than a test catching it.
    """
    return {
        "APCA-API-KEY-ID": account.key,
        "APCA-API-SECRET-KEY": account.secret,
        "Content-Type": "application/json",
    }


def _describe(response):
    """Pull Alpaca's own sentence out of a non-2xx response.

    Direct REST returns the refusal as the response BODY, so it has to be read
    off the response rather than assumed absent -- an integration that logs
    "400 Bad Request" has thrown away the only part that mattered. Alpaca sends
    something like {"code":40010001,"message":"qty must be > 0"}.
    """
    code = None
    message = None
    try:
        payload = response.json()
    except ValueError:
        payload = None
    if isinstance(payload, dict):
        code = payload.get("code")
        message = payload.get("message")
    if not message:
        # No JSON body at all -- fall back to whatever text there is, so the
        # caller still sees something the broker said.
        message = (response.text or "").strip() or f"HTTP {response.status_code}"
    return message, code


def _request(account, method, path, params=None, body=None):
    """One HTTP call to Alpaca, for one account. Raises BrokerError on failure."""
    url = f"{BASE_URL}{path}"
    try:
        response = requests.request(
            method,
            url,
            headers=_headers(account),
            params=params,
            data=json.dumps(body) if body is not None else None,
            timeout=TIMEOUT,
        )
    except requests.RequestException as error:
        # The network, not the broker. Say which, because "copy failed" with no
        # cause is the log line that turns five minutes into an afternoon.
        raise BrokerError(f"could not reach the broker: {error}") from error

    if response.status_code == 429:
        message, code = _describe(response)
        raise RateLimited(
            f"rate limited by the broker (200 requests a minute per account): {message}",
            code=code,
            status=429,
        )

    if not response.ok:
        message, code = _describe(response)
        raise BrokerError(message, code=code, status=response.status_code)

    if not response.content:
        return None
    try:
        return response.json()
    except ValueError as error:
        raise BrokerError(
            f"the broker returned something that is not JSON: {response.text[:200]!r}"
        ) from error


def _number(value, default=None):
    """Alpaca sends quantities and prices as strings. Comparing or adding them
    raw does the wrong thing silently, so they are converted here, once."""
    if value is None or value == "":
        return default
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _text(value):
    """Everything downstream expects plain strings it can compare and render."""
    if value is None:
        return None
    return str(value)


def _order(raw):
    """Normalize one order.

    The identifier is `id`, not `order_id`. Status is one of new, pending_new,
    accepted, partially_filled, filled, canceled, expired, rejected, replaced,
    and it is passed through untouched -- the copier decides which of those
    represent a trade worth copying.
    """
    return {
        "id": _text(raw.get("id")),
        "client_order_id": _text(raw.get("client_order_id")),
        "symbol": _text(raw.get("symbol")),
        "qty": _number(raw.get("qty"), 0.0),
        "filled_qty": _number(raw.get("filled_qty"), 0.0),
        "side": (_text(raw.get("side")) or "").lower() or None,
        "type": (_text(raw.get("type")) or "").lower() or None,
        "time_in_force": (_text(raw.get("time_in_force")) or "").lower() or None,
        "status": (_text(raw.get("status")) or "").lower() or None,
        "limit_price": _number(raw.get("limit_price")),
        "filled_avg_price": _number(raw.get("filled_avg_price")),
        "created_at": _text(raw.get("created_at")),
        "submitted_at": _text(raw.get("submitted_at")),
        "filled_at": _text(raw.get("filled_at")),
    }


def _position(raw):
    """Normalize one position.

    The quantity is UNSIGNED and the SIDE carries the sign, so anything that
    reads only the quantity cannot tell a short from a long -- and that
    distinction is exactly what the crossing-flat rule depends on. Both are
    returned, unchanged in meaning.
    """
    return {
        "symbol": _text(raw.get("symbol")),
        "qty": abs(_number(raw.get("qty"), 0.0)),
        "side": (_text(raw.get("side")) or "").lower() or None,
        "avg_entry_price": _number(raw.get("avg_entry_price")),
        "market_value": _number(raw.get("market_value")),
        "unrealized_pl": _number(raw.get("unrealized_pl")),
    }


# --- The four calls -------------------------------------------------------
#
# That is the whole surface. If a fifth is being added, the piece that wants it
# almost certainly should not.


def list_orders(account, limit=DEFAULT_ORDER_LIMIT):
    """Every recent order on this account, newest first.

    `status=all` is not optional. GET /v2/orders returns OPEN orders only by
    default, which is the trap in this endpoint: a filled order vanishes from
    the very query trying to find it, so a copier that looks correct all
    afternoon goes blind the moment something fills.
    """
    raw = _request(
        account,
        "GET",
        "/v2/orders",
        params={"status": "all", "limit": int(limit), "direction": "desc"},
    )
    # No orders is an ordinary state, not a failure.
    return [_order(item) for item in (raw or [])]


def list_positions(account):
    """Everything this account currently holds. An account with nothing open
    returns an empty list, not an error."""
    raw = _request(account, "GET", "/v2/positions")
    return [_position(item) for item in (raw or [])]


def submit_order(
    account,
    symbol,
    qty,
    side,
    client_order_id,
    order_type="market",
    time_in_force="day",
    limit_price=None,
    stop_price=None,
):
    """Place one order, stamped.

    Whole-share equities -- the scope of this build. Type and duration default
    to market/day, which is what the copier always sends: a copy chases the
    master's decision rather than making a new one about price. The Trade page
    passes the other types through, since that is a person deciding.

    The stamp is a required argument rather than an option: an order placed
    without one is a copy with no record that it happened.
    """
    body = {
        "symbol": symbol,
        "qty": str(int(qty)),
        "side": side,
        "type": order_type,
        "time_in_force": time_in_force,
        "client_order_id": client_order_id,
    }
    # Sent only when the order type actually uses them. A stale limit price on
    # a market order is an order nobody intended.
    if limit_price is not None:
        body["limit_price"] = str(limit_price)
    if stop_price is not None:
        body["stop_price"] = str(stop_price)

    raw = _request(account, "POST", "/v2/orders", body=body)
    return _order(raw or {})


def get_account(account):
    """This account's cash, buying power and trading state.

    THE FIFTH CALL, added deliberately. The rule of thumb is that whatever
    wants a fifth call probably should not have it -- the exception here is
    that `/skill-dashboard` requires the Accounts page to show cash and buying
    power per account, and requires per-account credential state, and neither
    is derivable from orders or positions. It doubles as the harmless startup
    question the copier asks to tell a wrong key from a right one.

    Note `admin_configurations`: an empty object is a healthy account, and a
    `restrict_to_liquidation_reasons` entry in it is why an account with plenty
    of cash refuses every buy.
    """
    raw = _request(account, "GET", "/v2/account") or {}
    return {
        "status": _text(raw.get("status")),
        "currency": _text(raw.get("currency")),
        "cash": _number(raw.get("cash")),
        "buying_power": _number(raw.get("buying_power")),
        "equity": _number(raw.get("equity")),
        "position_market_value": _number(raw.get("position_market_value")),
        "trading_blocked": bool(raw.get("trading_blocked")),
        "account_blocked": bool(raw.get("account_blocked")),
        "shorting_enabled": bool(raw.get("shorting_enabled")),
        # Deliberately NOT account_number or id: no account number is ever
        # shown anywhere in this app, so this layer does not hand one out.
        "restricted_to_liquidation": bool(
            (raw.get("admin_configurations") or {}).get("restrict_to_liquidation_reasons")
        ),
    }


def get_order_by_client_id(account, client_order_id):
    """Read one order back by its stamp, or None if this account has no such
    order.

    This is what lets a copy be checked for without pulling and scanning a
    whole history every pass -- and, because the stamp lives at the broker, it
    is what makes the duplicate guarantee survive this process dying.

    Not-found is a 404 here, and it is an ordinary answer meaning "not copied
    yet", not a failure.
    """
    try:
        raw = _request(
            account,
            "GET",
            "/v2/orders:by_client_order_id",
            params={"client_order_id": client_order_id},
        )
    except BrokerError as error:
        if error.status == 404:
            return None
        raise
    return _order(raw) if raw else None

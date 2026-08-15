"""The copy engine.

One account trades; every other account follows. A pass reads the master's
orders, works out which of them are new, and mirrors each one into every
follower at that follower's own size.

A copier multiplies mistakes: every other trading app places one wrong order
when it goes wrong, and this one places a wrong order in every follower at
once. Two guarantees hold the whole thing together, and there is no database to
build either of them out of --

1. NOTHING IS EVER COPIED TWICE. Every follower order is stamped with the
   master order it came from, using Alpaca's `client_order_id`. That stamp is
   the record, it lives at the broker, and it survives this process dying. The
   in-memory set below is a fast path and never the authority.

2. NOTHING THAT SHOULD BE COPIED IS MISSED. "New" means "not already stamped at
   the follower", never "arrived since I last looked at the clock" -- time-based
   detection loses orders whenever a pass is slow or the process restarts.

Copies go out on SUBMISSION, not on fill. See `_copyable_status` for why, and
for what that decision obliges.

--------------------------------------------------------------------------
The broker contract this module is written against (built by
`/skill-broker-api`, in `broker.py`). Everything it returns is plain Python --
dicts, strings, numbers -- and every call takes the account it is for, so no
credentials are ever shared between accounts:

    broker.list_orders(account, limit=N)   -> [ {...}, ... ]   (status=all)
    broker.list_positions(account)         -> [ {...}, ... ]
    broker.submit_order(account, symbol=, qty=, side=, client_order_id=) -> {...}
    broker.get_order_by_client_id(account, client_order_id) -> {...} or None
    broker.BrokerError                     -- carries the broker's own words

Order dicts carry at least: id, client_order_id, symbol, qty, filled_qty,
side, status, created_at. Position dicts carry: symbol, qty, side.
"""

import logging
import threading
import time
from collections import OrderedDict, deque
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone

import broker
import config

log = logging.getLogger("copier")


# Statuses that represent an actual instruction to follow. Anything outside
# this set was never a trade: the master cancelled it, it expired, the broker
# rejected it, or it was replaced (and copying a modification is out of scope).
LIVE_STATUSES = {"new", "pending_new", "accepted", "partially_filled", "filled"}
DEAD_STATUSES = {"canceled", "cancelled", "expired", "rejected", "replaced"}

# Every order this app places carries this prefix, so its own work is
# distinguishable on sight from an order placed by hand in Alpaca's web
# interface -- and the master's orders are placed by hand by definition.
STAMP_PREFIX = "copy"

# How many of the master's orders to read per pass. Comfortably more than a
# person places between two passes, and small enough to stay cheap.
ORDER_HISTORY_LIMIT = 100

# A submission is retried this many times inside the failing follower's own
# turn. Retrying a submit is safe precisely because of the stamp: the same
# pair always produces the same client_order_id, so a retry that duplicates a
# submission Alpaca actually accepted is refused as a duplicate rather than
# doubling the position.
SUBMIT_ATTEMPTS = 3
SUBMIT_BACKOFF_SECONDS = (1.0, 2.0)

# A follower's whole turn is bounded, so one hung account cannot stall a pass.
FOLLOWER_TURN_TIMEOUT = 60.0


def _now():
    return datetime.now(timezone.utc)


def _parse_time(value):
    """Read an order's timestamp. Returns None if it cannot be read.

    Unreadable is deliberately not "old": an order whose age is unknown is
    treated as fresh and copied, because the alternative silently drops real
    trades whenever a timestamp format shifts.
    """
    if value is None:
        return None
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    text = str(value).strip()
    if not text:
        return None
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        parsed = datetime.fromisoformat(text)
    except ValueError:
        log.warning("could not read order timestamp %r -- treating it as fresh", value)
        return None
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)


def _number(value, default=0.0):
    """Alpaca sends quantities and prices as strings even through the SDK."""
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def stamp_for(master_order_id, follower):
    """The client_order_id that identifies one copy.

    The PAIR is the identity: this master order, into this follower. The same
    master order into two followers is two copies and both must happen; the
    same pair twice is a duplicate and the second must not.
    """
    return f"{STAMP_PREFIX}-{master_order_id}-a{follower.slot}"


def _signed_position(positions, symbol):
    """The follower's holding in `symbol` as a signed number.

    A position's quantity is unsigned and its side carries the sign, so code
    that reads only the quantity cannot tell a short from a long -- and that
    distinction is the whole of the crossing-flat rule.
    """
    for position in positions:
        if str(position.get("symbol", "")).upper() != symbol.upper():
            continue
        qty = abs(_number(position.get("qty")))
        return -qty if str(position.get("side", "")).lower() == "short" else qty
    return 0.0


class Outcome:
    """What happened to one follower on one pass.

    EVERY follower produces one of these EVERY pass -- copied, skipped with a
    reason, or failed with the broker's own words. A follower that produces no
    outcome is a defect, because that is precisely the signature of a follower
    that was never reached.
    """

    def __init__(self, follower, state, detail, orders=None):
        self.slot = follower.slot
        self.alias = follower.alias
        self.state = state          # copied | idle | skipped | failed
        self.detail = detail
        self.orders = orders or []  # one row per master order handled this pass
        self.at = _now()

    def as_dict(self):
        return {
            "slot": self.slot,
            "alias": self.alias,
            "state": self.state,
            "detail": self.detail,
            "orders": self.orders,
            "at": self.at.isoformat(),
        }


class CopierState:
    """What the dashboard reads. Guarded by a lock, since a pass writes to it
    from several threads at once."""

    def __init__(self):
        self._lock = threading.Lock()
        self.started_at = None
        self.last_pass_at = None
        self.pass_count = 0
        self.copying_enabled = False
        self.loop_alive = False
        self.stopped_reason = None
        self.master = None
        self.followers = []
        self.problems = []          # slots that could not be used, and why
        self.master_error = None    # set when the master could not be read
        self.baseline_count = 0
        self.outcomes = OrderedDict()   # slot -> latest Outcome
        self.events = deque(maxlen=200)  # copies placed, newest last
        self.divergences = OrderedDict()  # master order id -> description

    def snapshot(self):
        with self._lock:
            return {
                "started_at": self.started_at.isoformat() if self.started_at else None,
                "last_pass_at": self.last_pass_at.isoformat() if self.last_pass_at else None,
                "pass_count": self.pass_count,
                "copying_enabled": self.copying_enabled,
                "loop_alive": self.loop_alive,
                "stopped_reason": self.stopped_reason,
                "master": (
                    {"slot": self.master.slot, "alias": self.master.alias}
                    if self.master
                    else None
                ),
                "followers": [
                    {
                        "slot": f.slot,
                        "alias": f.alias,
                        "sizing": f.sizing_description,
                    }
                    for f in self.followers
                ],
                "problems": [
                    {"slot": p.slot, "alias": p.alias, "reason": p.reason}
                    for p in self.problems
                ],
                "master_error": self.master_error,
                "baseline_count": self.baseline_count,
                "outcomes": [o.as_dict() for o in self.outcomes.values()],
                "events": list(self.events),
                "divergences": [
                    {"master_order_id": k, "detail": v}
                    for k, v in self.divergences.items()
                ],
            }

    def record_outcome(self, outcome):
        with self._lock:
            self.outcomes[outcome.slot] = outcome

    def record_event(self, event):
        with self._lock:
            self.events.append(event)

    def record_divergence(self, master_order_id, detail):
        with self._lock:
            if master_order_id in self.divergences:
                return False
            self.divergences[master_order_id] = detail
            return True

    def bump_pass(self):
        with self._lock:
            self.pass_count += 1

    def update(self, **fields):
        with self._lock:
            for name, value in fields.items():
                setattr(self, name, value)


STATE = CopierState()


class Copier:
    def __init__(self, master, followers, problems, state=STATE):
        self.master = master
        self.followers = followers
        self.problems = list(problems)
        self.state = state

        # Fast path only. The authority is always the stamp at the broker, and
        # this set is rebuilt from there whenever it is consulted and misses.
        self._copied = set()

        # Master orders that existed before this process started. Copying them
        # is exactly the loud, expensive, instant failure -- every restart
        # would re-copy the day, and so would the first pass after a follower
        # was added.
        self._baseline = set()

        # Master orders we have copied, kept so a later refusal at the master
        # can be spotted and reported as a divergence.
        self._copied_masters = OrderedDict()

        # Skips that are logged once rather than every pass. A skipped order
        # stays a candidate until it ages out, so without this a single
        # unfollowable order repeats its reason every few seconds and buries
        # the lines that matter.
        self._reported_skips = set()

        # None until the first pass, so the first pass always announces which
        # way the killswitch is set rather than only announcing changes.
        self._last_killswitch = None

        self._stop = threading.Event()

    def publish(self):
        """Push the account list and any dropped slots into the shared state.

        Called as soon as they are known, not when the loop starts: a dropped
        follower has to be visible from the first moment it is dropped, and a
        follower that silently does not exist looks exactly like one that is
        working and has had nothing to copy yet.
        """
        self.state.update(
            master=self.master, followers=self.followers, problems=self.problems
        )

    # --- startup ---------------------------------------------------------

    def verify_credentials(self):
        """Ask each account something harmless, once, before anything trades.

        A key that is well-formed but wrong is indistinguishable from a good
        one until it is used, and the first use should not be an order. A
        follower that fails here is dropped like any other bad slot; the master
        failing is fatal, because there is then nothing to copy from.
        """
        try:
            broker.list_positions(self.master)
        except Exception as error:
            raise config.ConfigError(
                f"The master account {self.master.alias!r} (ACCOUNT_"
                f"{self.master.slot}) was refused by the broker: {error}"
            ) from error

        usable = []
        for follower in self.followers:
            try:
                broker.list_positions(follower)
            except Exception as error:
                reason = f"refused by the broker at startup: {error}"
                log.error("follower %s dropped -- %s", follower.alias, reason)
                self.problems.append(
                    config.SlotProblem(follower.slot, follower.alias, reason)
                )
                continue
            usable.append(follower)
        self.followers = usable
        self.publish()

    def establish_baseline(self):
        """Read where the master's history currently ends, and copy nothing
        before it."""
        orders = broker.list_orders(self.master, limit=ORDER_HISTORY_LIMIT)
        self._baseline = {str(order.get("id")) for order in orders}
        log.info(
            "baseline established: %d existing master orders will not be copied",
            len(self._baseline),
        )
        self.state.update(baseline_count=len(self._baseline))

    # --- one pass --------------------------------------------------------

    def run_pass(self):
        """One complete pass. Never raises."""
        enabled = config.copying_enabled()
        self.state.update(copying_enabled=enabled, last_pass_at=_now())

        # Say which way the killswitch went -- on the first pass, and on every
        # change after it. Without this the log is silent while copying is off,
        # so "why did nothing copy?" can only be answered by opening .env, and
        # a question answered by guessing is a logging defect rather than a
        # configuration one. Logged on CHANGE, not every pass, so a five-second
        # loop does not bury everything else.
        if enabled != self._last_killswitch:
            if enabled:
                log.info(
                    "COPYING_ENABLED is on -- new master orders will be mirrored "
                    "into %d follower account(s)",
                    len(self.followers),
                )
            else:
                log.warning(
                    "COPYING_ENABLED is off -- nothing will be copied. This stops "
                    "NEW copies only; it does not cancel orders already placed or "
                    "close positions already opened."
                )
            self._last_killswitch = enabled

        # Checked before anything is read from the broker: when copying is off,
        # the app should not even be asking.
        if not enabled:
            for follower in self.followers:
                self.state.record_outcome(
                    Outcome(follower, "idle", "copying is switched off (COPYING_ENABLED)")
                )
            return

        try:
            master_orders = broker.list_orders(self.master, limit=ORDER_HISTORY_LIMIT)
        except Exception as error:
            # Reading the master is what produces the work, so if it fails
            # there is nothing to do this pass. It is not one more failed
            # account, and it does not touch the followers' outcomes.
            message = f"could not read the master account {self.master.alias!r}: {error}"
            log.error("%s", message)
            self.state.update(master_error=message)
            return
        self.state.update(master_error=None)

        try:
            master_positions = broker.list_positions(self.master)
        except Exception as error:
            # Without the master's positions the crossing-flat rule cannot be
            # decided, and guessing is the one thing it exists to prevent.
            message = (
                f"could not read the master account {self.master.alias!r} positions: "
                f"{error}"
            )
            log.error("%s", message)
            self.state.update(master_error=message)
            return

        self._report_master_divergences(master_orders)

        candidates = self._candidates(master_orders)

        # Each follower's whole turn runs on its own thread, so a follower that
        # is backing off between retries pauses only itself. The accounts after
        # it are neither delayed nor displaced.
        if not self.followers:
            return

        with ThreadPoolExecutor(max_workers=len(self.followers)) as pool:
            futures = {
                pool.submit(self._follower_turn, follower, candidates, master_positions): follower
                for follower in self.followers
            }
            results = []
            for future, follower in futures.items():
                try:
                    results.append(future.result(timeout=FOLLOWER_TURN_TIMEOUT))
                except Exception as error:
                    # _follower_turn already catches everything; reaching here
                    # means the turn itself never completed (a timeout), which
                    # still has to become a recorded outcome rather than a gap.
                    results.append(
                        Outcome(
                            follower,
                            "failed",
                            f"the account's turn did not complete: "
                            f"{type(error).__name__}: {error}",
                        )
                    )

        for outcome in results:
            self.state.record_outcome(outcome)

        # A pass that set out to visit four accounts and has four results is
        # complete; three results is a follower that was never reached, and
        # that is invisible from the outside -- it looks exactly like an
        # account with nothing to copy.
        if len(results) != len(self.followers):
            log.error(
                "PASS INCOMPLETE: %d of %d followers produced an outcome -- "
                "some account was never visited",
                len(results),
                len(self.followers),
            )

        self.state.bump_pass()

    def _candidates(self, master_orders):
        """The master orders worth copying this pass, oldest first."""
        stale_after = config.stale_order_seconds()
        now = _now()
        candidates = []

        for order in master_orders:
            order_id = str(order.get("id"))

            if order_id in self._baseline:
                continue

            client_id = str(order.get("client_order_id") or "")
            if client_id.startswith(f"{STAMP_PREFIX}-"):
                # This app's own work. Copying a copy would fan out forever,
                # and it means somebody has pointed the master at a follower.
                log.warning(
                    "master order %s carries this app's own stamp %r -- not copying it. "
                    "Is ACCOUNT_1 also configured as a follower?",
                    order_id,
                    client_id,
                )
                self._baseline.add(order_id)
                continue

            status = str(order.get("status", "")).lower()
            if status in DEAD_STATUSES:
                # Not an instruction to follow. Submission-copying means not
                # waiting for a PENDING order to resolve; it does not mean
                # ignoring one that already has.
                log.info(
                    "master order %s (%s %s %s) not copied: status is %s",
                    order_id,
                    order.get("side"),
                    order.get("qty"),
                    order.get("symbol"),
                    status,
                )
                self._baseline.add(order_id)
                continue
            if status not in LIVE_STATUSES:
                log.warning(
                    "master order %s not copied: unrecognised status %r", order_id, status
                )
                self._baseline.add(order_id)
                continue

            created = _parse_time(order.get("created_at"))
            if created is not None:
                age = (now - created).total_seconds()
                if age > stale_after:
                    log.info(
                        "master order %s (%s %s %s) not copied: %.0fs old, older than "
                        "STALE_ORDER_SECONDS=%.0f -- the price has moved on",
                        order_id,
                        order.get("side"),
                        order.get("qty"),
                        order.get("symbol"),
                        age,
                        stale_after,
                    )
                    self._baseline.add(order_id)
                    continue

            candidates.append(order)

        candidates.sort(key=lambda o: _parse_time(o.get("created_at")) or now)

        # Skipped orders age out, so this set is naturally bounded -- but it is
        # only a log-noise guard, and a long-running process should not grow it
        # without limit. Clearing it costs at most one repeated log line.
        if len(self._reported_skips) > 2000:
            self._reported_skips.clear()

        return candidates

    def _report_master_divergences(self, master_orders):
        """A master order can be refused AFTER its copies have gone out, and
        then the followers hold a position the master never got.

        This build does not unwind that. It records it and says so plainly --
        reconciling a divergence automatically is out of scope.
        """
        by_id = {str(order.get("id")): order for order in master_orders}
        for order_id, summary in list(self._copied_masters.items()):
            order = by_id.get(order_id)
            if order is None:
                continue
            status = str(order.get("status", "")).lower()

            if status in DEAD_STATUSES:
                detail = (
                    f"{summary} was copied to the followers, and the master's own "
                    f"order was then {status}. Those followers hold a position the "
                    f"master does not. Nothing is unwound automatically."
                )
                if self.state.record_divergence(order_id, detail):
                    log.warning("DIVERGENCE: %s", detail)
                self._copied_masters.pop(order_id, None)
                continue

            if status == "filled":
                ordered = _number(order.get("qty"))
                filled = _number(order.get("filled_qty"))
                if filled and ordered and filled < ordered:
                    detail = (
                        f"{summary} filled only {filled:g} of {ordered:g} shares at the "
                        f"master, but the copies were sized from the order quantity. "
                        f"The followers are larger than the master."
                    )
                    if self.state.record_divergence(order_id, detail):
                        log.warning("DIVERGENCE: %s", detail)
                self._copied_masters.pop(order_id, None)

        while len(self._copied_masters) > 200:
            self._copied_masters.popitem(last=False)

    # --- one follower's turn ---------------------------------------------

    def _follower_turn(self, follower, candidates, master_positions):
        """Everything one follower does this pass. THIS MUST NOT RAISE.

        A loop over the followers is the right shape, and what makes it a bug
        is a loop body that can throw: the exception unwinds the loop with it,
        and every follower after the failing one is never visited at all --
        not skipped with a reason, not logged, simply never reached. The
        accounts are always visited in the same order, so it is always the
        same followers that get starved, and the next pass does not repair it.

        So the catch here is deliberately broad. This one place wants whatever
        went wrong, not the two exception types that were anticipated -- an
        unanticipated one is exactly the case that would end the pass.
        """
        try:
            if not candidates:
                return Outcome(follower, "idle", "nothing new on the master to copy")

            try:
                positions = broker.list_positions(follower)
            except Exception as error:
                return Outcome(
                    follower,
                    "failed",
                    f"could not read this account's positions, so nothing was copied "
                    f"into it: {type(error).__name__}: {error}",
                )

            rows = []
            for order in candidates:
                rows.append(self._copy_one(follower, order, positions, master_positions))

            copied = [r for r in rows if r["state"] == "copied"]
            failed = [r for r in rows if r["state"] == "failed"]
            if failed:
                state = "failed"
                detail = failed[-1]["detail"]
            elif copied:
                state = "copied"
                detail = f"copied {len(copied)} order(s)"
            else:
                state = "skipped"
                detail = rows[-1]["detail"] if rows else "nothing to do"
            return Outcome(follower, state, detail, orders=rows)

        except Exception as error:
            log.exception("follower %s failed unexpectedly", follower.alias)
            return Outcome(
                follower,
                "failed",
                f"{type(error).__name__}: {error}",
            )

    def _report_once(self, order_id, follower):
        """True the first time this order is skipped for this follower.

        The skip itself is still returned as an outcome every pass -- only the
        log line is silenced, so the dashboard keeps saying why while the log
        does not repeat itself until the order ages out.
        """
        key = (order_id, follower.slot)
        if key in self._reported_skips:
            return False
        self._reported_skips.add(key)
        return True

    def _row(self, follower, order, state, detail, qty=None):
        return {
            "slot": follower.slot,
            "alias": follower.alias,
            "master_order_id": str(order.get("id")),
            "symbol": order.get("symbol"),
            "side": order.get("side"),
            "master_qty": _number(order.get("qty")),
            "qty": qty,
            "state": state,
            "detail": detail,
            "at": _now().isoformat(),
        }

    def _copy_one(self, follower, order, positions, master_positions):
        """Mirror one master order into one follower. Never raises."""
        order_id = str(order.get("id"))
        symbol = str(order.get("symbol") or "").upper()
        side = str(order.get("side") or "").lower()
        master_qty = _number(order.get("qty"))
        stamp = stamp_for(order_id, follower)

        summary = f"{side} {master_qty:g} {symbol}"

        # 1. Already copied? The fast path saves a broker call; the stamp at
        #    the broker is the authority whenever the fast path misses, which
        #    is what makes this survive a restart.
        if stamp in self._copied:
            return self._row(follower, order, "skipped", "already copied")
        try:
            existing = broker.get_order_by_client_id(follower, stamp)
        except Exception as error:
            return self._row(
                follower,
                order,
                "failed",
                f"could not check whether {summary} was already copied, so it was "
                f"not copied again: {type(error).__name__}: {error}",
            )
        if existing:
            self._copied.add(stamp)
            return self._row(
                follower,
                order,
                "skipped",
                "already copied (found at the broker, from before this process started)",
            )

        # 2. Size it. The direction is never touched by sizing.
        if not symbol or side not in {"buy", "sell"}:
            return self._row(
                follower, order, "skipped", f"master order is not a plain buy or sell ({side!r} {symbol!r})"
            )

        qty, reason = follower.size_for(master_qty)
        if qty < 1:
            if self._report_once(order_id, follower):
                log.info("follower %s: %s not copied -- %s", follower.alias, summary, reason)
            return self._row(follower, order, "skipped", reason)

        # 3. Crossing flat. An order does not mean one thing: what it does
        #    depends on what the account already holds, and the master's
        #    holding is not the follower's. The same instruction that reduces a
        #    position in one account opens the OPPOSITE one in another, and
        #    then the follower is not merely behind the master, it is
        #    positioned against it.
        held = _signed_position(positions, symbol)
        master_held = _signed_position(master_positions, symbol)
        delta = qty if side == "buy" else -qty
        master_delta = master_qty if side == "buy" else -master_qty

        master_is_reducing = master_held != 0 and (master_held > 0) != (master_delta > 0)

        if master_is_reducing and (held == 0 or (held > 0) != (master_held > 0)):
            # The master is closing something this follower never opened --
            # added late, or the opening copy was refused. Following it would
            # not reduce anything here; it would open the opposite position.
            detail = (
                f"skipped: the master is reducing a {'long' if master_held > 0 else 'short'} "
                f"position in {symbol} that this account does not hold, so copying it "
                f"would open the opposite position instead of closing one"
            )
            if self._report_once(order_id, follower):
                log.info("follower %s: %s -- %s", follower.alias, summary, detail)
            self.state.record_divergence(
                f"{order_id}:{follower.slot}",
                f"{follower.alias} did not copy {summary}: it holds no matching "
                f"position to reduce. This account is out of step with the master.",
            )
            return self._row(follower, order, "skipped", detail, qty=0)

        clamped_from = None
        if held != 0 and (held > 0) != (delta > 0):
            # Reducing. A copy may reduce a position and it may open one, but
            # never both in the same order: clamp it at flat.
            room = abs(held)
            if qty > room:
                clamped_from = qty
                qty = int(room)
                if qty < 1:
                    return self._row(
                        follower,
                        order,
                        "skipped",
                        f"there is less than one share of {symbol} to reduce here",
                        qty=0,
                    )

        # 4. Place it, stamped. Retries stay inside this follower's own turn.
        return self._submit(follower, order, symbol, side, qty, stamp, summary, clamped_from)

    def _submit(self, follower, order, symbol, side, qty, stamp, summary, clamped_from):
        order_id = str(order.get("id"))
        last_error = None

        for attempt in range(1, SUBMIT_ATTEMPTS + 1):
            try:
                placed = broker.submit_order(
                    follower,
                    symbol=symbol,
                    qty=qty,
                    side=side,
                    client_order_id=stamp,
                )
            except broker.RateLimited as error:
                # Nothing was refused and nothing was placed -- the broker just
                # asked us to slow down. Retrying inside this pass is the one
                # response guaranteed to make it worse, so the copy waits for
                # the next pass instead. The stamp means it cannot be lost.
                detail = f"not copied this pass -- {error.message}. Trying again next pass."
                log.warning("follower %s: %s %s", follower.alias, summary, detail)
                return self._row(follower, order, "skipped", detail, qty=qty)

            except Exception as error:
                message = str(error)
                if _is_duplicate_stamp(message):
                    # Alpaca refuses a duplicate client_order_id, which is the
                    # second line of defence doing its job. The copy already
                    # happened -- a normal outcome to record, not an error to
                    # retry.
                    self._copied.add(stamp)
                    log.info(
                        "follower %s: %s already copied (the broker refused the "
                        "duplicate stamp %s)",
                        follower.alias,
                        summary,
                        stamp,
                    )
                    return self._row(
                        follower, order, "skipped", "already copied (the broker refused a duplicate)"
                    )

                last_error = f"{type(error).__name__}: {message}"
                log.warning(
                    "follower %s: attempt %d of %d to copy %s failed -- %s",
                    follower.alias,
                    attempt,
                    SUBMIT_ATTEMPTS,
                    summary,
                    last_error,
                )
                if attempt < SUBMIT_ATTEMPTS:
                    time.sleep(SUBMIT_BACKOFF_SECONDS[min(attempt - 1, len(SUBMIT_BACKOFF_SECONDS) - 1)])
                continue

            self._copied.add(stamp)
            self._copied_masters[order_id] = summary

            detail = f"copied {side} {qty} {symbol}"
            if clamped_from:
                detail += (
                    f" (clamped from {clamped_from} so it stops at flat rather than "
                    f"opening the opposite position)"
                )
            log.info("follower %s: %s [stamp %s]", follower.alias, detail, stamp)

            row = self._row(follower, order, "copied", detail, qty=qty)
            row["stamp"] = stamp
            row["follower_order_id"] = str(placed.get("id")) if placed else None
            row["follower_status"] = str(placed.get("status")) if placed else None
            self.state.record_event(row)
            return row

        detail = f"{summary} was not copied after {SUBMIT_ATTEMPTS} attempts -- {last_error}"
        log.error("follower %s: %s", follower.alias, detail)
        return self._row(follower, order, "failed", detail, qty=qty)

    # --- the loop --------------------------------------------------------

    def run_forever(self):
        """The polling loop. It never dies quietly: if it is going to give up,
        it says why, loudly, and the dashboard shows it -- a copier that has
        silently stopped looks exactly like a market with no trades in it."""
        self.publish()
        self.state.update(started_at=_now(), loop_alive=True, stopped_reason=None)
        for problem in self.problems:
            log.error("ACCOUNT_%s (%s) dropped: %s", problem.slot, problem.alias, problem.reason)
        if not self.followers:
            log.warning(
                "no usable follower accounts -- the copier will idle until one is "
                "added to .env and the app is restarted"
            )

        try:
            while not self._stop.is_set():
                try:
                    self.run_pass()
                except Exception:
                    # run_pass is written not to raise. If it does anyway, the
                    # loop keeps going rather than taking the copier down with
                    # it -- but it is logged in full, because guessing at what
                    # happened is a second defect sitting next to the first.
                    log.exception("a copier pass raised unexpectedly -- continuing")
                self._stop.wait(config.poll_seconds())
        except BaseException as error:
            reason = f"the copy loop stopped: {type(error).__name__}: {error}"
            log.critical("%s", reason)
            self.state.update(loop_alive=False, stopped_reason=reason)
            raise
        self.state.update(loop_alive=False, stopped_reason="the copy loop was asked to stop")

    def stop(self):
        self._stop.set()


def _is_duplicate_stamp(message):
    """Alpaca's own words for a client_order_id it has already seen."""
    text = (message or "").lower()
    return "client_order_id" in text and (
        "already exists" in text or "duplicate" in text or "must be unique" in text
    )


def build():
    """Load the accounts, check them against the broker, and set the baseline."""
    master, followers, problems = config.load_accounts()
    copier = Copier(master, followers, problems)
    copier.verify_credentials()
    copier.establish_baseline()
    return copier


def start(daemon=True):
    """Start the copy loop on a background thread and return (copier, thread).

    This is what the web process calls: the dashboard and the copier live in
    the same always-on process.
    """
    copier = build()
    thread = threading.Thread(target=copier.run_forever, name="copier", daemon=daemon)
    thread.start()
    return copier, thread


if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)-8s %(name)s: %(message)s",
    )
    try:
        engine = build()
    except config.ConfigError as config_error:
        log.critical("cannot start: %s", config_error)
        raise SystemExit(1)
    try:
        engine.run_forever()
    except KeyboardInterrupt:
        engine.stop()
        log.info("stopped by hand")

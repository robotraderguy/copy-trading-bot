"""Configuration for the copier.

There is no database and no settings screen. The accounts, their sizing and
every switch live in `.env`, and this module is the only place that reads it.

ACCOUNT_1 is the master -- the account traded by hand. Every numbered slot
after it is a follower that mirrors it. A gap in the numbering ends the list.

Loading is a VALIDATION step, not a parse. The failure that actually happens
to somebody setting this up is not a missing slot: it is a slot copied out of
`.env.example` and left holding the example's own placeholder text. That slot
is present, complete and entirely fake, so anything that only checks for
absence sails straight past it and tries to trade an account whose key is
literally `your_paper_api_key_here`.
"""

import os

from dotenv import load_dotenv

load_dotenv()


# The exact strings `.env.example` ships. A slot still holding one of these was
# never filled in, however complete it looks. Compared case-insensitively.
PLACEHOLDERS = {
    "your_paper_api_key_here",
    "your_paper_api_secret_here",
    "pick_a_long_random_string",
}


class ConfigError(Exception):
    """The master account is unusable, so there is nothing to copy from."""


class Account:
    """One numbered slot from the environment, validated and ready to use.

    The alias is the only name shown on screen -- account numbers never appear
    in the app -- but the slot number is kept for log lines, where "ACCOUNT_3"
    is what the reader has to go and edit.
    """

    def __init__(self, slot, alias, key, secret, multiplier=None, fixed_shares=None):
        self.slot = slot
        self.alias = alias
        self.key = key
        self.secret = secret
        self.multiplier = multiplier
        self.fixed_shares = fixed_shares

    @property
    def is_master(self):
        return self.slot == 1

    @property
    def sizing_description(self):
        """How this follower sizes its copies, in words, for the dashboard."""
        if self.fixed_shares is not None:
            return f"{self.fixed_shares} shares, fixed"
        return f"{_trim(self.multiplier)}x the master"

    def size_for(self, master_qty):
        """Shares this follower copies for a master order of `master_qty`.

        Returns (qty, reason). A qty of 0 means the copy does not happen and
        `reason` says why -- never a silent nothing.
        """
        if self.fixed_shares is not None:
            return self.fixed_shares, None

        raw = master_qty * self.multiplier
        qty = int(round(raw))
        if qty < 1:
            return 0, (
                f"{_trim(self.multiplier)}x {master_qty} shares rounds to zero shares"
            )
        return qty, None

    def __repr__(self):
        return f"<Account {self.slot} {self.alias!r}>"


class SlotProblem:
    """A slot that was read but cannot be used, and the reason in plain words.

    These persist for as long as they are true. A follower that silently does
    not exist looks exactly like a follower that is working and has had nothing
    to copy yet, and that is the one a reader will believe.
    """

    def __init__(self, slot, alias, reason):
        self.slot = slot
        self.alias = alias or f"ACCOUNT_{slot}"
        self.reason = reason

    def __repr__(self):
        return f"<SlotProblem ACCOUNT_{self.slot}: {self.reason}>"


def _trim(value):
    """Format a float the way a person would write it: 2.0 -> '2', 0.5 -> '0.5'."""
    text = f"{value:g}"
    return text


def _clean(raw):
    """Strip a value, and treat a placeholder from `.env.example` as blank."""
    if raw is None:
        return ""
    value = raw.strip()
    if value.lower() in PLACEHOLDERS:
        return ""
    return value


def _slot_present(slot):
    """True if the environment mentions this slot at all.

    Presence is deliberately generous -- any of the three keys existing counts
    -- because a half-filled slot must reach validation and be reported, not be
    mistaken for the end of the list.
    """
    for suffix in ("ALIAS", "KEY", "SECRET"):
        if os.getenv(f"ACCOUNT_{slot}_{suffix}") is not None:
            return True
    return False


def _read_sizing(slot):
    """Validate this follower's sizing rule.

    Returns (multiplier, fixed_shares, error). Text that is neither a valid
    multiplier nor a valid share count disables the follower rather than
    defaulting to something: falling back to 1x means copying a size nobody
    asked for, which is worse than not copying at all.
    """
    fixed_raw = (os.getenv(f"ACCOUNT_{slot}_FIXED_SHARES") or "").strip()
    mult_raw = (os.getenv(f"ACCOUNT_{slot}_MULTIPLIER") or "").strip()

    if fixed_raw:
        try:
            fixed = int(fixed_raw)
        except ValueError:
            return None, None, (
                f"ACCOUNT_{slot}_FIXED_SHARES is {fixed_raw!r}, which is not a "
                f"whole number of shares"
            )
        if fixed < 1:
            return None, None, (
                f"ACCOUNT_{slot}_FIXED_SHARES is {fixed_raw!r}, which is not a "
                f"positive number of shares"
            )
        return None, fixed, None

    if mult_raw:
        try:
            multiplier = float(mult_raw)
        except ValueError:
            return None, None, (
                f"ACCOUNT_{slot}_MULTIPLIER is {mult_raw!r}, which is not a number"
            )
        if multiplier <= 0:
            return None, None, (
                f"ACCOUNT_{slot}_MULTIPLIER is {mult_raw!r}, which is not a "
                f"positive number"
            )
        return multiplier, None, None

    # No sizing given at all: a multiplier is the default, and 1x means "trade
    # exactly what the master traded".
    return 1.0, None, None


def load_accounts():
    """Read every numbered slot, validated.

    Returns (master, followers, problems). A bad follower is dropped and
    reported; the rest run normally. A bad MASTER raises ConfigError, because
    there is then nothing to copy from and an app that starts anyway is running
    an empty loop that looks healthy.
    """
    master = None
    followers = []
    problems = []

    slot = 1
    while _slot_present(slot):
        alias = _clean(os.getenv(f"ACCOUNT_{slot}_ALIAS"))
        key = _clean(os.getenv(f"ACCOUNT_{slot}_KEY"))
        secret = _clean(os.getenv(f"ACCOUNT_{slot}_SECRET"))

        missing = [
            name
            for name, value in (("alias", alias), ("key", key), ("secret", secret))
            if not value
        ]

        if missing:
            # Naming every missing piece matters: a key with no secret is
            # somebody halfway through, and calling that "not configured"
            # hides a typo they would otherwise hunt for.
            fields = ", ".join(f"ACCOUNT_{slot}_{m.upper()}" for m in missing)
            if not key and not secret:
                # The whole slot is untouched -- almost always a spare slot
                # copied straight out of `.env.example` and never filled in.
                reason = (
                    f"not filled in ({fields} are blank or still the example values)"
                )
            else:
                # Somebody is halfway through. Calling that "not configured"
                # hides a typo they would otherwise hunt for.
                reason = f"only half filled in -- {fields} blank or still the example value"
            problem = SlotProblem(slot, alias, reason)
            if slot == 1:
                raise ConfigError(f"The master account (ACCOUNT_1) is {reason}.")
            problems.append(problem)
            slot += 1
            continue

        if slot == 1:
            # The master is never sized -- it is the thing being sized against.
            master = Account(slot, alias, key, secret)
            slot += 1
            continue

        multiplier, fixed_shares, sizing_error = _read_sizing(slot)
        if sizing_error:
            problems.append(SlotProblem(slot, alias, sizing_error))
            slot += 1
            continue

        followers.append(
            Account(slot, alias, key, secret, multiplier=multiplier, fixed_shares=fixed_shares)
        )
        slot += 1

    if master is None:
        raise ConfigError(
            "No master account. ACCOUNT_1_ALIAS, ACCOUNT_1_KEY and "
            "ACCOUNT_1_SECRET must be set in .env -- ACCOUNT_1 is the account "
            "you trade by hand, and every slot after it follows it."
        )

    return master, followers, problems


# --- Settings -------------------------------------------------------------
#
# The killswitch is read fresh on every pass rather than captured at import,
# so nothing in the process can be holding a stale copy of the one setting
# whose whole job is to stop trading.


def copying_enabled():
    """The killswitch. Off unless the environment says otherwise, on purpose:
    the first thing a freshly deployed copier does must never be to place
    orders. It stops NEW copies only -- it does not cancel orders already
    placed, and does not close positions already opened."""
    return (os.getenv("COPYING_ENABLED") or "false").strip().lower() in {
        "1",
        "true",
        "yes",
        "on",
    }


def _positive_number(name, default, cast):
    raw = (os.getenv(name) or "").strip()
    if not raw:
        return default
    try:
        value = cast(raw)
    except ValueError:
        return default
    return value if value > 0 else default


def poll_seconds():
    """Seconds between passes. Every pass costs one read of the master plus one
    per follower, and Alpaca rate-limits, so faster is not better."""
    return _positive_number("POLL_SECONDS", 5.0, float)


def stale_order_seconds():
    """Master orders older than this are not copied. Stops a copier that has
    been down from waking up and firing a backlog at prices that have moved."""
    return _positive_number("STALE_ORDER_SECONDS", 300.0, float)


def flask_secret_key():
    return _clean(os.getenv("FLASK_SECRET_KEY")) or None

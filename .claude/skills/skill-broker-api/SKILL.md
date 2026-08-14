---
name: skill-broker-api
description: Build this project's broker layer — the one module every other part of the app goes through to reach Alpaca's paper API, covering the four calls this build needs, the stamp that makes copying idempotent, and what Alpaca actually returns. Use when the broker layer needs building, fixing, or extending.
---

# Broker API

> **Personal skill** — written for this project. Its requirements are part of
> the build, and folding lessons back into it is encouraged.

Everything this app knows comes from the broker, so this module is the only place
that talks to it. One broker, one file, four calls.

## Local adaptations (this project)

### Bare invocation

**With no arguments, `/skill-broker-api` builds or updates this project's broker
module to the spec below.**

- **If it does not exist yet** — build it from scratch.
- **If it already exists** — update it in place so it satisfies every rule as
  this skill currently reads. Edit what is there; never add a second client, and
  never leave two functions that do the same job. Report what changed and what
  was already correct.

Treat this section as the complete specification — the user will type only the
slash command and pass no requirements.

### One broker, and it is paper

**Alpaca, paper environment, and nothing else.** The base URL is
`https://paper-api.alpaca.markets`. The live URL is one word different, which is
exactly why it is worth saying out loud: never type it, never make it
configurable, and never accept a base URL from the environment. A build that
cannot reach a funded account is a build that cannot drain one.

Auth is a **pair** on every request — `APCA-API-KEY-ID` and
`APCA-API-SECRET-KEY` as headers. Each account in `.env` has its own pair, so
every call has to carry the credentials of the account it is for. **Do not build
a module-level client** configured once at import: this app talks to several
accounts, and a single shared client is how a follower's order gets placed in the
master. Take the account as an argument and build the request from it.

### The four calls

That is the whole surface. If a fifth is being added, the piece that wants it
almost certainly should not.

1. **List an account's orders.** `GET /v2/orders`. It returns **open orders
   only** unless asked otherwise, which is the trap: pass `status=all` and a
   `limit`, or a filled order vanishes from the very query trying to find it.
2. **List an account's positions.** `GET /v2/positions`. An account with nothing
   open returns an empty list, not an error.
3. **Place an order.** `POST /v2/orders` with symbol, quantity, side, type and
   time in force — and the stamp below.
4. **Read one order back by its stamp.** So a copy can be checked for without
   pulling and scanning a whole history each pass.

### The stamp — `client_order_id`

The duplicate guarantee in `/skill-copy-trading` rests entirely on this field, so
it is a requirement here rather than an implementation detail.

- Alpaca accepts a **`client_order_id`** on submission, stores it, and returns it
  on every read of that order. That is what makes it a record which survives this
  process dying.
- It must be **unique within the account** — Alpaca refuses a duplicate, which is
  a second line of defence and should be treated as one: if the submission is
  refused for a duplicate id, the copy already happened, and that is a normal
  outcome to record, not an error to retry.
- Build it from the pair that defines a copy — **this master order, into this
  follower** — so the same pair always produces the same stamp and a different
  pair never collides. Keep it under Alpaca's 128-character limit and use plain
  characters.
- The app also has to be able to tell its own orders from ones placed by hand in
  the broker's own web interface. A stamp the app can recognise on sight is what
  makes that possible, and the master's orders are placed by hand by definition.

### What Alpaca actually returns — and why this module converts it

**There are two ways to reach Alpaca and they hand back different things.** The
official `alpaca-py` SDK returns **pydantic objects** — an `Order`, a `Position`,
a `TradeAccount` — with real Python types inside them. Calling the REST endpoints
directly returns **JSON**, so the same fields arrive as plain strings. Either is a
fine choice for this build; what is not fine is letting the difference leak past
this module.

**So this module's real job is to convert.** Whichever path is used, it returns
plain Python — dicts, strings, numbers, booleans — and nothing downstream ever
touches a pydantic object, a UUID, or an enum. That is why the layer exists at
all: pick one path, normalize once, and the rest of the app cannot tell which was
picked.

What that conversion has to handle, each of which has caused a real bug:

- **The SDK's fields are typed objects, not text.** `id` is a `UUID`,
  `created_at` and `filled_at` are `datetime`s, and `status`, `side` and `type`
  are **enums** — `OrderStatus.NEW`, not the string `"new"`. Comparing one to a
  string is always false, and it fails quietly rather than raising. Take the
  enum's `.value`, and turn UUIDs into strings, at the boundary.
- **None of it serializes on its own.** A pydantic object cannot be written to a
  file, put in a session, or rendered by a template as-is, and the error surfaces
  far from here — at the point something tries to store or display it. Converting
  at the boundary is what prevents chasing that back.
- **Quantities and prices are strings even in the SDK.** `qty` is `"10"`, not
  `10`; so are `filled_qty`, `avg_entry_price` and every price field. Comparing or
  adding them raw does the wrong thing silently. This is the one place where the
  two paths agree, and both need converting.
- **The order's identifier is `id`, not `order_id`.**
- **Order status is one of** `new`, `pending_new`, `accepted`, `partially_filled`,
  `filled`, `canceled`, `expired`, `rejected`, `replaced`. Convert it to that
  plain string and pass it through untouched — `/skill-copy-trading` decides which
  of them represent a trade worth copying, so never collapse them into a boolean
  here.
- **A position's `side` is `long` or `short`**, and its `qty` is unsigned. The
  side is the sign, so a module that reads only the quantity cannot tell a short
  from a long — and that distinction is what the crossing-flat rule depends on.
- **An empty result is an empty list.** No positions and no orders are ordinary
  states, not failures, and must never be reported as one.

### Failures are returned, never swallowed

A refusal carries a `code` and a **`message`** — for instance
`{"code":40010001,"message":"qty must be > 0"}`, or an asset-not-found message
naming the symbol. That message is written for a person and is almost always the
entire answer to "why did that not copy".

**How it reaches you depends on the path again.** Direct REST returns it as the
response body, so it has to be read off a non-2xx response rather than assumed
absent. The SDK **raises** `APIError` instead, carrying that same JSON as its
text — so it is an exception to catch, not a value to inspect, and an
unhandled one kills the polling pass for every remaining account. Catch it per
account, pull the message out, and keep going.

- **Return the broker's own words** to whatever called this module. Never replace
  them with a message of your own, and never reduce a failure to `None` or
  `False` — the caller logs and displays what it is given, and nothing else can
  reconstruct what the broker said.
- **Every request gets an explicit timeout.** A hung request in a polling loop
  looks exactly like a quiet market.
- **Alpaca rate-limits at 200 requests a minute per account.** Each copier pass
  costs one read of the master plus one per follower, so the limit is reachable
  with a short interval and a few accounts. Treat a rate-limit response as
  temporary — back off and try the next pass — not as a refusal of the order.

### Out of scope

Market data, historical bars, quotes, options, crypto, streaming/websockets,
order modification, and every broker that is not Alpaca. Each is named so that
its absence reads as a decision. The build needs orders and positions; anything
else is a different app.

---

## Getting it right

- **Prove the stamp survives the round trip before building anything on it.**
  Place one order with a `client_order_id`, read it back, and confirm the value
  is there and unchanged. The entire duplicate guarantee rests on that, and if it
  fails the failure is invisible until the day the process restarts.
- **Check the orders query with a filled order.** The default returns open orders
  only, so a copier that looks right all afternoon can go blind the moment
  something fills. Fill one and confirm it is still visible.
- **Test an account with nothing in it.** A fresh paper account returns `[]` for
  both positions and orders, and code written against populated accounts often
  treats that as an error.
- **Point two accounts at the same code path.** The bug this module exists to
  prevent — credentials leaking between accounts — only appears with more than
  one, and it appears as an order in the wrong place rather than as an error.
- **Read the error body, not just the status code.** Alpaca returns a useful
  sentence; an integration that logs "400 Bad Request" has thrown away the part
  that mattered.
- **Try to store or display something this module returned.** Write it to a file,
  or hand it to a template. If anything raises a serialization error, or renders
  as `OrderStatus.NEW` instead of `new`, a pydantic object got past the boundary —
  and that is far easier to find here than at the point it eventually breaks.

# END

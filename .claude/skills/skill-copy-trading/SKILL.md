---
name: skill-copy-trading
description: Build this project's copy engine — the loop that watches one master account and mirrors its new orders into every follower account, with per-follower sizing, a killswitch, and the guarantees that stop a trade being copied twice or missed entirely, all without a database. Use when the copier needs building, fixing, or extending.
---

# Copy Trading

> **Personal skill** — written for this project. Its requirements are part of
> the build, and folding lessons back into it is encouraged.

This is the heart of the build. One account trades; every other account follows.
The whole skill is about the two ways that goes wrong — **a trade copied twice**
and **a trade not copied at all** — and what stops each of them **with no
database to remember anything in**.

> **Terminology: "master" and "follower" are ACCOUNTS.** The account whose trades
> get copied is the **master**; the accounts that receive the copies are
> **followers**. Neither word ever refers to a git branch, and these are the words
> to use in code, in logs and on screen.

**A copier multiplies mistakes — that is the risk this build carries.** Every
other trading app places one wrong order when it goes wrong; this one places a
wrong order in every follower at once. Two consequences bind everything below:
**nothing is ever copied twice**, and **a follower is never left holding a
position the master doesn't have**. When a rule here looks overcautious for the
amount of code it guards, that is why.

## Local adaptations (this project)

### Bare invocation

**With no arguments, `/skill-copy-trading` builds or updates this project's copy
engine to the spec below — it does not audit, and does not stop at a proposal.**

- **If the engine does not exist yet** — build it from scratch, exactly as
  specified below, inside the background loop the scaffold created.
- **If it already exists** — update it in place so it satisfies every rule as
  this skill currently reads, including any rule added since it was written.
  Edit what's there; never build a parallel second engine, never duplicate a
  loop or a forwarding function that already exists. Leave working behavior
  alone and change only what the current rules require. Report what changed and
  what was already correct.

Typed arguments change that: `audit` reports on the existing engine instead of
changing it, `remove` takes it out. Empty is never an audit here.

Treat this section as the complete specification — the user will type only the
slash command and pass no requirements.

### The accounts come from the environment

The master is the first numbered slot in `.env`; the followers are the ones
after it, each with its own key, secret, alias and sizing rule. There is no
database and no screen to add an account on — adding a follower means adding
three lines to the environment and restarting. Say that plainly on the dashboard
rather than implying there is somewhere to click.

**The number of followers is the viewer's choice, and one is a normal answer.**
`.env.example` ships three slots because a master and two followers demonstrates
the idea well. It is a starting point, not a requirement: **one master and one
follower must work exactly as well as one master and two**, and so must any
larger number the viewer adds.

### Every slot is validated, and a bad follower is dropped, not fatal

This is the failure that will actually happen to a viewer, and it happens at the
worst moment — the first run.

**The trap is that an unused slot is rarely an absent one.** A viewer who wants
a single follower does not usually delete the third slot; they copy
`.env.example`, fill in the two accounts they have, and leave the third holding
the example's own placeholder text. So a rule that stops at the first *missing*
number never fires, and the app tries to trade an account whose key is literally
`your_paper_api_key_here`. Reading the slot is not the same as the slot being
filled in.

So loading the accounts is a validation step, not a parse:

- **A slot counts only if it is complete and real** — a key, a secret and an
  alias, none of them blank and **none of them still holding a placeholder value
  from `.env.example`**. Compare against those example values explicitly; they
  are known strings and this is the single most likely bad input.
- **A partially filled slot is an error, never a silent skip.** A key with no
  secret is somebody halfway through, and treating it as absent hides a typo they
  will otherwise hunt for. Name the slot, say which piece is missing, and carry
  on without it.
- **Sizing values are validated too.** A multiplier must read as a positive
  number and a fixed share count as a positive whole number; text that is neither
  disables that follower rather than defaulting to something. Silently falling
  back to 1× means copying a size nobody asked for, which is worse than not
  copying.
- **Credentials are checked once at startup, per account, by asking the broker
  something harmless.** A key that is well-formed but wrong is indistinguishable
  from a good one until it is used, and the first use should not be an order.

**What happens to a bad follower: it is dropped, and everything else runs.**

- The other followers copy normally. **One misconfigured account is never an
  outage for the rest** — the same isolation the failure rules describe, applied
  at startup instead of mid-pass.
- **The drop is loud and it persists.** Log it with the reason in plain words,
  and show it on the dashboard for as long as it is true. A follower that
  silently does not exist looks exactly like a follower that is working and has
  nothing to copy yet — and the viewer will believe the second one.
- **Never substitute a default for a bad value.** Dropping an account is
  recoverable and obvious; trading it on a guessed size is neither.

**The master is the exception: a bad master is fatal.** There is nothing to copy
from, so the app must refuse to start and say exactly why, rather than running an
empty loop that looks healthy.

**Zero valid followers is a legitimate state, not a crash.** The app starts, the
dashboard says there are no followers and why, and the copier idles. A viewer
setting up their first account will be in this state, and meeting an error page
there teaches them the build is broken when it is merely empty.

### There is no database. This is the constraint that shapes everything.

Nothing this loop learns survives a restart, and the host restarts processes
without asking. So the engine may never rely on its own memory for anything that
matters. **Both guarantees below are built out of things that already persist:
the environment, and the broker's own record of what it was asked to do.**

### The two guarantees

**1. Nothing is ever copied twice.**

**Stamp every follower order with the master order it came from**, using the
broker's own client-side order reference — the field the broker stores and hands
back on request. That stamp IS the record, it lives at the broker, and it
survives anything that happens to this process.

- Before copying, ask the follower's own recent orders whether one already
  carries this master order's stamp. If it does, the copy already happened —
  even if it happened in a previous life of this process.
- The pair is the identity: *this master order, into this follower account.* The
  same master order into two followers is two copies and both must happen; the
  same pair twice is a duplicate and the second must not.
- An in-memory set is fine as a **fast path** to avoid re-asking the broker on
  every pass. It is never the authority, and it is always rebuilt from the
  broker on start.

**2. Nothing that should be copied is missed.**

- "New" means **not already stamped at the follower**, never "arrived since I
  last looked at the clock". Time-based detection loses orders whenever a pass
  is slow or the process restarts.
- **On start, establish a baseline and copy nothing before it.** Read the
  master's current orders once, note where the history ends, and begin from
  there. Without this, every restart re-copies the day — and so does the first
  run after a follower is added. This is the failure that is loud, expensive and
  instant, so decide it deliberately and say what you decided.
- **Old orders are not copied.** An order the master placed long enough ago that
  the price has moved is not worth chasing at market. Skip anything older than a
  configurable age and record that it was skipped and why — silence here looks
  identical to a copier that is broken.
- **Only orders that actually represent a trade get copied.** An order the
  master cancelled, that expired, or that the broker rejected is not an
  instruction to follow. Read the status and decide; do not copy on sight.

### Copy on SUBMISSION, not on fill

**A master order is copied as soon as it is seen at the broker, whether or not it
has filled.** This is a decision, not a default — build this one and do not build
a switch for the other.

The alternative is to wait for the master's fill and copy then, and it is the
safer of the two: an order the master's broker ends up refusing never reaches a
follower at all. What it costs is the reason it is not the pick here. Waiting
means the followers are late by however long the master's order sits unfilled —
which is not a fraction of a second but however long the market takes, and a
resting or queued order can sit for hours. A copier whose followers enter at a
different price, sometimes on a different day, is hard to reason about and harder
to demonstrate. Submission is the behaviour a viewer can watch happen.

What that decision obliges:

- **Copy on the first pass that sees the order, and do not wait for a status to
  settle.** Waiting "just one pass to be sure" is copy-on-fill wearing a
  disguise, and it reintroduces the lag without the safety.
- **A status already known to be dead is still skipped.** The bullet above still
  holds: if the pass that finds the order finds it already cancelled, expired or
  rejected, it was never an instruction. Submission-copying means not waiting for
  a *pending* order to resolve — it does not mean ignoring a resolved one.
- **The master's order can still be refused after the copy has gone out, and
  then the follower holds a position the master never got.** This build does not
  unwind that. It **records the divergence and says so plainly** — the same
  reporting the crossing-flat rule uses, since it is the same condition arrived
  at from a different direction. Detect and report; do not self-heal.
- **Size from the order's own quantity**, since there is no fill quantity to size
  from yet. A partial fill on the master therefore leaves the followers larger
  than it, which is the same divergence again and is recorded the same way.

### Sizing

Each follower carries **its own** sizing rule, set in the environment:

- **A multiplier** on the master's quantity — the default, and 1× means "trade
  exactly what the master traded".
- **A fixed number of shares**, ignoring the master's size entirely.

Rules that bind both:

- **A copy is never zero shares.** A fractional result rounds, and if it rounds
  to nothing, the copy does not happen and the reason is recorded.
- **Whole shares only.** Fractional quantities are out of scope.
- **The direction is copied exactly.** Buy stays buy, sell stays sell, and
  nothing in the sizing rule may change one into the other.
- **A follower that is out of money is not an error in the engine.** The broker
  refuses, that refusal is recorded against that follower, and the pass carries
  on — see the independence rule below.

**Percent-of-equity sizing is deliberately out of scope for this build.** It is
the sizing rule most people actually want, and it needs each account's equity
read and reconciled. Don't build it unasked.

### Crossing flat, and the thing that makes copiers dangerous

**An order does not mean one thing. What it does depends on what the account
already holds**, and the master's holding is not the follower's. The same
instruction that reduces a position in one account opens the opposite one in
another — and once that happens the follower is not merely behind the master, it
is positioned **against** it, so every move that helps one hurts the other.

It runs in both directions, and neither is the special case:

- The master **sells** 100 it owns and goes flat. A follower that never got the
  original buy — added late, or the buy was refused — sells the same 100 and is
  now **short**.
- The master **buys** 100 to cover a short and goes flat. A follower that never
  got the short buys the same 100 and is now **long**.

Nothing in the order itself distinguishes these from an ordinary opening trade;
only the follower's own position does. So:

- **Before copying anything, ask the follower what it actually holds in that
  symbol.** Decide from the answer, not from the order's side.
- **A copy may reduce a position and it may open one, but it may never do both
  in the same order.** If it would carry the follower through flat and out the
  other side, clamp it at flat and record the clamp; if there is nothing there to
  reduce and the master's order was reducing, skip it and say so.
- A follower is allowed to end up **out of step** with the master. Pretending
  otherwise is worse: record the divergence plainly and let the owner see it.

**Reconciling a divergence automatically is out of scope for this build.**
Detect and report; do not self-heal.

### Every follower is executed independently

**A pass visits several accounts, and each visit stands alone.** Nothing that
happens in one follower may change what happens in another — not the order they
are tried in, not an error, not a refusal, not a timeout.

**A loop over the followers is the right shape. What makes it a bug is a loop
body that can raise.** Iterating the accounts and doing each one's work in turn
is exactly correct, and it stays correct for as long as nothing throws. The
moment something does — and a network call to a broker is the most likely thing
in the build to throw — the exception leaves the loop body, unwinds the loop
with it, and **every follower after the failing one is never visited at all**:
not skipped with a reason, not logged, simply never reached. The pass ends early
and returns looking like it finished.

So the fix is not a different control structure. It is that **the body of the
loop must be unable to raise** — whatever happens to one account is caught
inside that account's own turn and turned into a recorded outcome, so the loop
always runs to the end.

What makes it genuinely dangerous rather than merely annoying:

- **The accounts are always visited in the same order**, so it is always the same
  followers that get starved. A bad first account means the last one has never
  copied anything, ever.
- **It is invisible from the outside.** A follower that was never reached looks
  exactly like a follower with nothing to copy. There is no error against its
  name, because the code that would have written one never ran.
- **It compounds silently.** The master goes on trading, the working followers
  keep pace, and the starved one drifts further out of step with every pass.
- **The next pass does not repair it.** If the first account fails consistently —
  bad credentials, a rate limit, a broker outage — the later accounts are cut off
  for as long as it lasts.

So:

- **Each follower's work is wrapped so that its failure cannot escape into the
  pass.** Catch around the single account, record the outcome against that
  account, and continue to the next one. This is not error handling for
  tidiness; it is what makes the accounts independent at all.
- **Catch broadly here, and narrowly everywhere else.** This one place wants
  whatever went wrong, not the two exception types that were anticipated — an
  unanticipated one is exactly the case that ends the pass, and it is the case a
  precise `except` clause lets through. Record its type and message rather than
  discarding it; a caught error that is not written down is the same silence
  from the operator's side.
- **Every follower produces an outcome every pass** — copied, skipped with a
  reason, or failed with the broker's own words. **A follower that produces no
  outcome is a defect**, because that is precisely the signature of never having
  been reached.
- **Count them.** A pass that set out to visit four accounts and has four results
  is complete; three results is the bug above. This is cheap to assert and it is
  the only thing that distinguishes the two cases after the fact.
- **The master is not part of this loop.** Reading the master is what produces
  the work, so if that fails there is nothing to do this pass — say so and wait
  for the next one, rather than treating it as one more failed account.

### When something fails

- **Try again, but not immediately, and not forever.** A refusal that is really
  a refusal will be refused again; a failure that was the network deserves
  another go. Back off between attempts, cap them, and stop.
- **"Cap them" means across passes, not just within one.** A cap that resets
  every pass is not a cap: the order stays a candidate until it ages out, so a
  refusal that will never succeed gets re-sent on every pass for as long as the
  stale window lasts — dozens of identical submissions for one order, each one
  a broker call spent on a decision already made. **Remember that a particular
  copy was refused, and stop trying it**, rather than rediscovering the same
  refusal every few seconds.
- **Separate the two kinds of failure, because they want opposite treatment.**
  A broker's *refusal* — no buying power, asset not tradable, quantity invalid —
  is a decision about this order and will be identical next time; record it once
  and leave it alone. A *transport* failure — a timeout, a reset, a rate limit —
  says nothing about the order at all and deserves another go. Treating a
  refusal as retryable is what produces the flood above; treating a timeout as
  final silently drops a copy that would have worked.
- **Every attempt is recorded, with the broker's own words.** "Copy failed" is
  useless. "Follower *Roth*: rejected — insufficient buying power" is the whole
  value of the log.
- **Retrying is per follower, and the retries stay inside that follower's own
  turn.** Backing off is a pause for one account, never for the pass — an account
  that is being retried must not delay or displace the accounts after it.
- **The loop never dies quietly.** If it is going to give up, it says why,
  loudly, and the dashboard shows it. A copier that has silently stopped looks
  exactly like a market with no trades in it.

### The killswitch

One setting in the environment that stops all copying. It must be:

- **Read every pass**, and checked before anything is read from the broker.
- **Off by default.** The very first thing this app does when it starts must
  never be to copy something.
- **Honest about what it does and does not do.** It stops *new copies*. It does
  not cancel orders already placed and does not close positions already opened.
  Say that on screen next to it, because the moment somebody reaches for it is
  the moment they most need to know it.

Because it lives in the environment, flipping it means changing it on the host
and letting the app restart. That is slower than a button and it is the honest
cost of having no database. Say so rather than building one.

### Scope limit

Single broker. One master. Whole-share equities. New orders only. Everything
else — copying a later cancellation or modification, multi-leg and options
copying, several masters, several users, per-follower risk caps, streaming
instead of polling, and **anything that needs a database** — is out of scope for
this build. Each is named here rather than left unsaid, so it is clear it was
left out on purpose rather than forgotten.

---

## Getting it right

- **The demo that proves this works is two accounts and one trade.** Place one
  order on the master and watch it appear on the follower. Everything else in
  this skill exists to stop that same trade appearing twice, or appearing in a
  follower that could not afford it, or appearing again after a restart.
- **Restart the process mid-test. This is the single most important check in
  the build.** With no database, everything the engine knows is either at the
  broker or gone. Stop it while an order is fresh on the master, start it again,
  and confirm nothing copies a second time. If it does, the stamp is not being
  read back — and that bug is invisible until the day the host restarts you.
- **Run it with two accounts and the third slot left untouched.** This is the
  configuration a viewer following along most often ends up with, and the whole
  app has to work in it: the copier runs, the two real accounts copy, and the
  third is reported as unfilled rather than attempted. Then break the third slot
  deliberately — a key with no secret, a multiplier of `abc` — and confirm each
  produces a named reason and no effect on the others.
- **Run it with a master and no followers at all.** Nothing should crash, and no
  page should be empty without explaining itself.
- **Break the FIRST follower and confirm the last one still copies.** Give
  account 2 credentials that will be refused, then place a trade on the master
  and check that account 3 received its copy. This is the one test that catches
  a pass abandoned partway, and testing it on the last account instead proves
  nothing — the bug is invisible unless the failure comes before something else
  in the order.
- **Add a follower to an account that has already traded today.** If the new
  follower fills with a day of history, the baseline rule was never
  implemented.
- **Test with the market shut as well as open.** A closed market is not a quiet
  version of an open one: orders queue instead of filling, and the statuses the
  copier reads back are different ones. Since copying happens on submission, the
  copies still go out — so what needs checking is that they go out correctly and
  that the dashboard shows them as queued rather than as nothing happening.
  Assume the app will be run at whatever hour it is finished, because it will be.
- **Check what the broker does with the stamp field.** Some brokers truncate it,
  some reject characters, some only return it on certain queries. The whole
  duplicate guarantee rests on that field surviving the round trip, so confirm
  it against a real order rather than assuming.
- **Watch the interval.** Every pass costs one read of the master plus a read
  per follower, and brokers rate-limit. Polling every second is not five times
  better than every five seconds; it is five times more likely to get throttled
  at the exact moment a trade lands.

# END

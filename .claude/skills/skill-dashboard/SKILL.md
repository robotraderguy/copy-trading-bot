---
name: skill-dashboard
description: Build this project's dashboard — the copier view that shows one master trade fanning out to its followers, the supporting pages, the always-loads resilience rule, and the look. Holds the app's UI brief so it can be invoked bare, and composes with a visual-design skill the user names alongside it for the aesthetic direction. Use when building or updating the app's pages.
---

# Dashboard

> **Personal skill** — written for this project. Its requirements are part of
> the build, and folding lessons back into it is encouraged.

Builds the project's server-rendered dashboard. Its centrepiece is one screen
that answers the only question this app exists to answer: **did my trade land in
every account?**

**This skill composes with a design skill.** It owns WHAT the dashboard contains
(pages, fields, behavior, resilience); a visual-design skill owns HOW it looks
(typography, layout, the signature element). The user names both in the same
instruction — e.g. `/skill-dashboard` alongside a design skill — and when they
do, this brief supplies the content while the design skill supplies the
aesthetic judgment. If only this one was named, build to this brief and say the
design skill exists; don't reach for it yourself. This skill never edits the
design skill; that skill stays exactly as downloaded.

## Local adaptations (this project)

### Bare invocation

**With no arguments, `/skill-dashboard` builds or updates this project's
dashboard to the spec below — it does not ask for a brief, and does not stop at
a proposal.**

- **If the pages do not exist yet** — build them from scratch, exactly as
  specified below.
- **If they already exist** — update them in place so they satisfy every rule as
  this skill currently reads. Edit what's there; never duplicate a page. Leave
  working behavior alone and change only what the current rules require. Report
  what changed and what was already correct.

Treat this section as the complete specification — the user will type only the
slash command and pass no requirements.

### Stack

Plain **Flask + Jinja**, server-rendered, single user. No React, no build step,
no login, **no database**. Data comes from three places only:

- The **broker**, for orders and positions per account — including the stamps on
  follower orders saying which master order they came from.
- The **environment**, for the accounts, their aliases and sizing rules, and
  every other setting.
- The engine's **recent-activity list**, held in memory by this same process.

The copy loop runs in this process, so the pages read what it recorded directly.
Nothing is persisted: **a restart empties the activity list**, and the pages must
say so rather than showing an empty panel that reads as calm.

### Pages

Five: **Copier, Trade, Accounts, Orders, Positions.** The front door lands on
**Copier**. The menu lists them and highlights the current page.

**CONFIGURATION is view-only; ACTIONS are not.** Accounts and settings live in
the environment file, so the dashboard reports them and says where to change
them — do not build an accounts CRUD screen or a settings form, because an app
with no database has nowhere to put what such a form would collect, and a screen
that edits accounts would be writing to the one thing that does not persist.

**Trade is the exception, and it is not really an exception.** Its form does not
store anything: it hands an order to the broker, which is where that order lives.
The rule was never "no forms", it was "nothing that pretends to save state this
app cannot keep". A form whose result leaves the process entirely is fine.

It also earns its place. Without it, the only way to start the demonstration this
whole app exists to show is to leave the app, place a trade in the broker's own
site, and come back — so the dashboard would be a spectator to its own subject.

### The Copier page — the one that matters

This is the screen the whole video is about, and its shape is the point: **the
master on top, the followers underneath it, and one trade visibly becoming
several.**

- The **master account** at the top: its alias, and its most recent orders.
- Each **follower** below: its alias, its sizing rule, and — for each master
  order — what happened to that order in that account. Filled, working,
  refused-and-why, skipped-and-why, or not yet attempted.
- **A row reads across.** The unit of the display is the master's order, and its
  copies line up beside it. A page that lists each account's orders separately is
  a different, less useful page: the reader's actual question is "did *this*
  trade land everywhere?", and answering it must not require them to compare two
  lists by eye.
- **Aliases only. Never an account number**, anywhere on this page or any other.
- Say when the copier last ran. A page that looks calm because the worker died
  twenty minutes ago is the worst screen this app could show.

### The Trade page — where the demonstration starts

**It places one order, on the MASTER account only.** Nothing else on this page
chooses an account: the followers are not a destination the user picks, they are
the consequence the rest of the app shows. A form that let you send an order
straight to a follower would be teaching the opposite of the lesson.

**Equities only, single orders, whole shares.** That is the entire scope of this
form; quantity is a share count, so nothing here takes a dollar amount.

The fields, and nothing beyond them:

| Field | Notes |
|---|---|
| **Symbol** | Uppercased on entry; rejected before sending if empty. |
| **Side** | Buy or Sell. |
| **Quantity** | Whole shares, minimum 1. No fractions, no dollar amounts. |
| **Order type** | Market, Limit, Stop, Stop-Limit. |
| **Duration** | Day, GTC, IOC, FOK, plus the broker's open/close codes. |
| **Limit price** | Only for Limit and Stop-Limit. |
| **Stop price** | Only for Stop and Stop-Limit. |

**Dependent fields are INDENTED under the choice that summons them**, with a
left brand border, so they read as belonging to the order type rather than as
two more fields that appeared from nowhere. Hide them when they do not apply,
and clear them — a stale limit price left in a hidden field is an order the user
did not intend.

**A preview modal before anything is sent.** The submit button opens a modal
that states the order back in one plain sentence — *"Buy 100 NVDA at market,
day"* — naming the master's alias, and it says what will follow: that each
follower will copy it at its own sizing. Nothing reaches the broker until the
user confirms in that modal. This is a real order on a real (paper) account, and
a mis-typed quantity is worth one extra click to catch.

**Then an alert saying what actually happened**, on the page, in plain words:
accepted, with the order as the broker recorded it — or refused, with the
broker's own reason. A form that clears itself and says nothing is the single
worst outcome here, because it looks exactly like success.

- **Never report an order as placed until the broker has accepted it.** A form
  that reports what it SENT rather than what the broker answered will announce
  success for a rejected order.
- The alert is not the whole story and should not pretend to be: it covers the
  master's order only. Point the user at **Copier** for what the followers did.
- **This page places the master's order and stops.** The copier notices it on its
  next pass, exactly as it notices an order placed anywhere else. Calling the
  copy engine from the form would copy the trade twice — once because the form
  asked, once because the loop saw it — and would also mean orders placed outside
  the app behave differently from orders placed inside it.
- Say on the page that it is a **paper** account, so nobody discovers this from
  a filled order.

### What each other page shows

- **Accounts:** each configured account — alias, which is the master, its sizing
  rule, whether the credentials still work, cash and buying power. Read-only, and
  it names the environment variables that define them, since that is the only
  place they can be changed.

  **A slot that failed validation is shown here too, not omitted.** An account
  the copier dropped — incomplete, still holding the example placeholder text, or
  a sizing value it could not read — appears in this list marked as not in use,
  with the reason in plain words and the name of the setting to fix. Leaving it
  out is what makes a misconfigured follower look identical to one that is
  working quietly, and this page is where somebody goes to find out which.

  **Having no followers at all is a state this page states,** not an empty table.
  Say that the copier has a master and nothing to copy into, and where to add one.
- **Orders:** recent orders per account, newest first — time, alias, ticker,
  side, quantity, status, fill price.
- **Positions:** current holdings per account — alias, ticker, shares, side.
  This is the page that shows a follower drifting out of step with the master.

**A failure that belongs to no particular order still has to appear somewhere.**
The broker unreachable, credentials rejected, the loop not having run at all:
**Copier** carries these on its last-ran line, and **Accounts** carries the
per-account credential state. Every failure this app can have is reported on one
of those two pages.

Settings are not a page of their own: the killswitch, poll interval, stale age
and sizing rules are shown on **Accounts**, read-only, as the values currently in
force. **Never render a secret's value** — show only whether it is set.

### Static by design — no JavaScript framework, no auto-refresh

- Each page renders its data fresh on load; the viewer reloads for new data.
- **Do NOT add** polling, websockets, or SSE. Live updating is out of scope for
  this build, and the honest limits section of the video says so out loud.
- **Say it on the page**, though — a dashboard that looks live and isn't is worse
  than one that admits it. Stamp the time the page was rendered, so a stale tab
  is obviously a stale tab.

### Never let a page break

- If the broker can't be reached, the page says so plainly, per account. One
  account's credentials expiring must not blank the page for the others.
- If the copier has recorded nothing because the process restarted, **Copier**
  says that, rather than showing nothing and looking like a quiet market.
- **Every page always loads** — no unhandled exception, no blank screen, no stack
  trace, whatever the broker or the database does.

### Look (hand these constraints to the design skill)

- **Dark theme** — something a trader leaves open on a second monitor, not a
  bare-bones default table.
- **The broker's signature accent colour**, named rather than pinned to a hex
  value, on a near-black background with off-white text; brighten it until it's
  readable on the dark background (check contrast, don't eyeball).
- **Trading conventions are absolute here, because this page is scanned rather
  than read: green means a fill, red means a rejection or a loss.** Never
  decorative, and never the accent's job.
- **The master and the followers must be distinguishable at a glance**, without
  reading a label — the hierarchy is the information.
- Theme colours as CSS custom properties in one `:root` block, so re-theming
  later is a one-place edit.

### Compliance — this app gets screenshotted

The owner films this. Two rules follow, and they are not styling preferences:

- **No account numbers**, ever, on any page.
- **No profit and loss, and no dollar figures presented as gains.** Cash and
  buying power are operational facts and are fine; a green "+$412" is a
  performance claim, and this build makes none.

---

## Getting it right

- **The always-loads rule is invisible until it fails.** Every page renders fine
  with a reachable broker and a busy copier; that proves nothing. Check the
  failure states deliberately — wrong credentials on one account, the broker
  unreachable, and a copier that has never run — and confirm
  each page still draws with a plain message rather than a stack trace.
- **An empty table is a state, not a bug.** Before any trade has been copied,
  most of these pages have nothing to show. "No copies yet" reads as working; a
  blank panel or a crash reads as broken.
- **Build the Copier page against a follower that FAILED.** It is easy to design
  four green rows and discover at record time that a refusal has nowhere to
  display its reason. The interesting row is the one that went wrong.
- **A log is a source, not a layout.** Dumping lines onto the page because that's
  the shape the data arrives in is the default outcome. One row per thing that
  happened is what a person can actually scan.
- **Check the contrast, don't trust your eye.** A brand colour that looks fine on
  a bright monitor can be unreadable on a dim one — and this broker's accent is a
  yellow, which is the hardest family to keep legible on near-black. Measure it.
- **Nothing here is worth a client runtime.** If a requirement seems to call for
  live updates, re-read the spec — a reload is the refresh mechanism, and adding
  polling is the easiest way to drift out of scope without noticing.

# END

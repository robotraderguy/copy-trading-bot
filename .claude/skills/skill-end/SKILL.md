---
name: skill-end
description: Close a session cleanly — the bookend to /skill-init. Folds anything learned back into the skills, checks no secret is exposed, checks nothing was left copying unattended, clears away scratch files, reports what is uncommitted, and prints a short wrap-up. Use when the user says they're done for now, when a lesson needs teaching back to a skill, or when they invoke /skill-end.
---

# End a Session

> **Personal skill** — written for this project. Its requirements are part of
> the build, and folding lessons back into it is encouraged.

Closes a session so nothing learned is lost and nothing unsafe is left behind.
`/skill-init` loads the context at the start; this puts it away at the end.

## Local adaptations (this project)

### Bare invocation

**With no arguments, `/skill-end` runs the steps below in order and prints the
wrap-up.** Stopping a session with the build half-finished is completely normal
and is not a problem to warn about.

### This skill CLOSES work — it must not open more

The point of a wrap-up is to end the session, not to hand the user a list of
chores or start a project of its own. So:

- **Never start building something here.** Not a test suite, not a README, not a
  missing feature, not a refactor. If this skill notices a gap, it *names* it in
  one line and stops.
- **Fix only what is genuinely trivial** and belongs to work already done — a
  scratch file to delete, a lesson to write down. Anything larger is reported,
  not undertaken.
- **Don't manufacture follow-ups.** A build that ended where the user stopped is
  finished for today. Only mention what actually matters: something unsafe,
  something half-connected, or something they explicitly asked to be reminded of.

**One exception, and it is the reason this skill gets invoked mid-build.** When
the user runs this immediately after something went wrong — a copy that fired
twice, a sizing rule that rounded to nothing, a worker that scaled to zero on
redeploy — they are not ending the day. They are asking for **step 1 and nothing
else**: teach the lesson to the skill that owns it, so the rebuild comes out
right. Do that, say which skill you edited and what rule you added, and stop.
**Do not rebuild, and do not re-run the skill you just edited** — invoking a
skill is the user's job, and they will do it next.

### Step 1: Fold this session's lessons back into the skills

This is the step that makes the next build better, and it's the reason the skills
are editable at all. Look back over the session for anything that taught a
reusable lesson — a spec that turned out to be ambiguous, a gotcha that cost
time, a correction the user had to make twice.

For each one:

1. Find the skill that owns that ground (`.claude/skills/`) and add the lesson
   there — as a **requirement** if it's binding, or under **"Getting it right"**
   if it's advice.
2. Write it as a standing rule, not a story. Present tense, no dates, no
   "this session we found…". The skill is instructions; the incident is not.
3. **Only personal skills** — the ones marked `> **Personal skill**`. Vendor
   skills stay byte-identical, as always.

If a lesson has no natural home, say so rather than inventing a new skill for a
one-liner.

**Put the lesson where the mistake was made, not where it was noticed.** A
duplicate copy that surfaced on the dashboard is a copy-engine rule, not a
dashboard rule; a worker that came back from a redeploy at zero processes is a
deploy rule, not a worker rule. Filing a lesson under the skill that displayed
the symptom means the skill that causes it will cause it again.

### Step 2: Check nothing secret is exposed

Cheap, and the one thing that genuinely can't wait:

- The real `.env` is untracked and ignored.
- No key, secret, account id, or database connection string was written into a
  tracked file this session.
- Nothing secret is sitting in a file that's about to be pushed.

**This build holds credentials for several brokerage accounts at once**, and they
live in the database rather than the environment — so also confirm nothing this
session dumped a record, a query result, or a debug print containing them into a
file, a log, or the terminal history.

If something is exposed, say so plainly — it needs removing and rotating.

### Step 3: Check nothing was left running unattended

Specific to this build, and worth thirty seconds: **is anything still copying?**

- A worker left running locally, still pointed at the paper accounts.
- A deployed worker with copying switched on.

Neither is wrong — the user may well want it running. But ending a session
without knowing which is the one way this app surprises somebody. Say what state
it is in, and if copying is on, say that plainly rather than in passing.

### Step 4: Clear away scratch files

Anything created as scaffolding this session — one-off scripts, debug dumps,
`tmp_*` / `*.bak` files — should not outlive it. Delete what is unambiguously
scratch and this session's. When unsure whether a file is scratch or real work,
**leave it and mention it** rather than deleting it.

### Step 5: Check tests — only if this project has any

**Check first whether a test suite exists at all.** This build does not ship with
one — it is verified by placing a real trade on the master and watching it copy —
so the normal answer is that there's nothing to run:

- **No suite** — say so in one line and move on. **Do not create one.** Writing a
  test suite is a build task the user would ask for directly, not something a
  wrap-up decides to start.
- **A suite exists** (the user added one) — **only run it if it hasn't already
  run since the last code change.** A redundant run costs minutes and tells you
  nothing new. If it already ran after the last edit, report that result and its
  verdict; run it now only when code changed afterwards, or when nothing in this
  session ran it at all. Either way, if it fails, report the failure — don't
  start fixing it unless the user asks.

Either way this step ends in a sentence, not a project.

### Step 6: Report what's uncommitted — never commit

Find out what has changed in the working tree since the last commit, and
summarize it grouped by theme. Then **stop there**: do not commit, push, stash,
or branch, not even "to be safe". That's the user's call, exactly as it is during
the build. The deliverable is the summary, not the commit.

### Step 7: Write the handoff for the next session

Write `.claude/HANDOFF.md`, replacing whatever is there. `/skill-init` reads it
first thing, so this is how one sitting reaches the next — a build like this
spans several, and without it the next session re-derives ground that was
already settled, or re-opens a decision the user has already made.

Keep it to what the next session cannot work out for itself by looking:

- **Where the build is** — which skills have been run and what exists now.
- **What is in flight** — anything half-finished, and what "finished" would
  look like.
- **Decisions the user made**, with the reason. This is the most valuable part
  and the part most easily lost: the working tree shows WHAT was built, never
  why a different option was rejected.
- **Blockers** — anything waiting on the user (a credential, a sign-in, a
  purchase), stated as the exact action.
- **What was verified and what was not**, in those words. "Written but
  unverified" must survive into the next session, or it silently becomes
  "working".

Two things it must not become. It is **not a plan** — never write the next
steps as instructions to execute, because the user reveals the order by
invoking skills, and a handoff that reads like a to-do list invites the next
session to run ahead. And it is **not a changelog** — no file-by-file diff;
git already has that, in more detail and more accurately.

Date it, keep it short, and write it as a report of what is true now rather
than a story of the session.

It is **git-ignored on purpose** — it is your session state, not part of the
product, and this repo is public. Don't add it to a commit, and don't report
it as uncommitted work in the wrap-up.

### Step 8: Print the wrap-up

Short, and only what's true:

- what got built this session,
- lessons folded into which skills,
- secrets check: clean, or exactly what's exposed,
- copier state: stopped, or running and where,
- scratch files deleted, or flagged as uncertain,
- tests: no suite in this project, or the last result and whether it was already
  current (say when it was from, rather than implying you just ran it),
- uncommitted work, grouped,
- handoff written,
- anything only the user can do (a credential, a browser sign-in), each with the
  exact action.

If the user wants this kept for next time, offer to save it as a file — don't
write one unasked, since nothing in this project reads it automatically.

---

## Getting it right

- **A half-finished build is a normal place to stop.** Ending mid-way is not a
  failure state and doesn't need a warning attached. Note where things stopped so
  it's easy to pick up, and leave it there.
- **Don't report a result you didn't see.** If something was still running when
  the session ended, say it was still running — not what you expect it would have
  said.
- **A lesson written as a story stops working.** "We discovered the follower got
  the trade twice after a restart" helps nobody on the next build; "the record of
  a copy is what prevents the second one, so write it before sending, not after"
  is a rule that fires when it's needed.
- **The best lessons are the ones that were nearly invisible.** A copier fails
  quietly by design — a missed copy looks like a quiet market and a doubled one
  looks like a busy account. If something took a long time to notice, that is
  precisely the lesson worth writing down, because it will take just as long to
  notice next time.
- **The session's context shouldn't carry into the next one.** Once the wrap-up
  is printed, the useful parts live in the skills and in the repo. Tell the user
  they're done and can start fresh — a new session begins at `/skill-init`.

# END

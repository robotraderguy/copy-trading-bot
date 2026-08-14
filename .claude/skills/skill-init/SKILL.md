---
name: skill-init
description: Load the context for this project at the start of a session — what is being built, how it gets built (short plain-English direction plus the skills in this repo), which branch you are on, and the rules that apply. Use at the start of a new conversation, after cloning the repo, or whenever the session needs re-grounding.
---

# Start a Session

> **Personal skill** — written for this project. Its requirements are part of
> the build, and folding lessons back into it is encouraged.

Run this once at the start of a session, before building anything.

> **Terminology: `main` always means the git branch.** Throughout this skill and
> every other skill in this repo, `main` and `start` in backticks are the two git
> branches and nothing else — never a `main.py` file, never a `main()` function,
> never "the main module". Where a file or function is meant, it is named
> explicitly, and anything long-running is named for what it does rather than
> for where it starts.

> Where a build gives an ordinary word a second meaning of its own, the skill
> that builds that piece says so; this one only reserves the branch names.

## How it gets built

**Who "you" is — this holds for every skill in this repo, not just this one.**
Throughout the skill library, **"you" means the AI reading it** and **"the user"
means the person driving the build**. This skill runs first and is where that
convention is declared; the other skills rely on it and do not restate it.

- **The user gives short, plain-English direction** — usually just a slash
  command naming a skill in this repo, sometimes one sentence that names one.
- The **skills in `.claude/skills/` carry the specification**. Every page,
  field, sizing rule, and failure behavior for this project already lives in
  each personal skill's **"Local adaptations (this project)"** section.
- **You do the work.** The user does not paste requirement walls and does not
  run terminal commands — you clone, install, build, run, and deploy on their
  behalf, and report back what happened.

If the user is writing long requirements prompts, something has gone wrong —
that requirement belongs in a skill, and it is probably already there.

**How every skill in this repo is laid out.** They share one shape, so you always
know where to look:

- A **`> **Personal skill**`** marker under the title, if it is one.
- A **`### Bare invocation`** block saying what the bare slash command does —
  every skill here is designed to be invoked with no arguments.
- **`## Local adaptations (this project)`** — the **requirements**. This section
  is the specification and is binding.
- **`---` then `## Getting it right`** — **advisory**: the gotchas, the things
  that bite in the real world, and how to verify. Read it, apply your judgment;
  it explains and warns rather than specifies.
- **`# END`** as the last line, so a truncated file is obvious.

Requirements live above the rule, advice below it. When the two ever seem to
disagree, the requirement wins. A skill with no gotchas worth stating omits
"Getting it right" rather than padding it.

The **build** skills state their requirements as a spec to satisfy. The three
**session** skills — this one, `/skill-install`, and `/skill-end` — state theirs
as ordered steps to run instead, since their job is a procedure rather than an
artifact. Same sections, same order.

## Local adaptations (this project)

### Bare invocation

**With no arguments, `/skill-init` runs the steps below in order and stops.** It
loads context and switches branch if needed; it builds nothing and plans nothing.

### Steps

1. **Read `README.md`.** The two branches carry very different ones, and which
   one you are looking at changes what it is good for.

   **On the `start` branch the README is orientation** — the channel, a
   high-level description of what this build does, how the build is directed,
   and **the stack**: the language, the web framework, the broker, the host, and
   whether there is a database. Those belong there. They are what a person needs
   to decide whether this build is for them, and a viewer should not have to
   open a skill to find out what they are about to install.

   What it deliberately does NOT carry is the **specification**: no settings
   keys, no field names, no sizing formulas, no page lists, no failure
   behaviours. That is not an oversight to fix and not a gap to fill in — a
   README documenting those would hand over the answer, and you would end up
   building to the documentation instead of to the spec. **The skills are the
   specification. There is no second source.**

   So the split is: the README tells you WHAT the pieces are, the skills tell
   you what each one must DO. Read it for context, then build from the skills.

   On the **`main`** branch (the finished build — see step 2) the README is a
   different document: it documents the finished app in full — architecture,
   collections, configuration, deployment — and there it is the correct
   reference, because the app is done and describing it is no longer a spoiler.

   **Writing that full README is beyond the scope of this build.** No skill here
   produces one, and its absence at the end is not a loose end: don't write one
   unprompted, and don't treat the `start` README as a draft to be expanded into
   it. If the user asks for one, that's a normal request — write it then.

2. **Get onto the right branch. This is the one thing this skill acts on** —
   everything else it does is read-and-report. Find out which branch is checked
   out.

   - **`start`** — the launchpad: skills, `install/`, `.env.example`, and **no
     app code**. This is where the app gets built, one skill at a time. Already
     correct; nothing to do.
   - **`main`** — the finished build. **Cloning the repo without asking for a
     branch lands here**, so this is the ordinary starting state, not a mistake
     by the user. Unless they've said they want to run, deploy, or modify the
     finished app, a session that starts here is a *build* session sitting on
     the wrong branch: **switch to `start`** (fetching it first if it isn't on
     this machine yet), then confirm it took and tell them you moved and why.

   **Why act here when the rest of this skill only reports:** building while
   `main` is checked out puts the finished code in the working tree, which is
   exactly the situation the "build from the spec" rule below exists to prevent.
   Leaving the user on `main` doesn't keep them safe — it drops them into the
   one setup where copying the answer is the path of least resistance. A branch
   switch is instant and reversible; the trap isn't.

   If the switch can't be made cleanly — uncommitted changes in the working
   tree, or no `start` on the remote — **stop and report.** Never force it,
   never stash or discard someone's work, never re-clone to get around it.

   If you can't determine a branch at all — no git repository, or a detached
   checkout — say so and stop there. Report what you found and let the user
   decide.

3. **Read the handoff, if there is one.** If `.claude/HANDOFF.md` exists,
   read it first — `/skill-end` writes it at the
   close of the previous session, and it names what was built, what was left
   in flight, and what was decided. A build like this spans several sittings,
   and without it every new session re-derives ground that was already settled
   or, worse, re-opens a decision the user has already made.

   It is a report of the LAST session, not an instruction for this one: it
   never authorises building anything. If it disagrees with what you find in
   the working tree, the working tree is what is true — say so and move on.
   If there is no handoff, that is normal on a first session; note it and
   continue.

4. **Inventory the skills.** List `.claude/skills/` and read each `SKILL.md`
   frontmatter description so you know what is available and can reach for the
   right one. These are the build mechanism, not background reading.

   **Sort them into personal and vendor by reading, not by guessing.** A
   **personal** skill says so on its own second line — a `> **Personal skill**`
   note directly under the heading. Anything without that note is **vendor**:
   leave it byte-identical (they usually ship a `LICENSE` file, which is a
   second confirmation).

   Do not infer this from anything else. In particular, **"it has a Local
   adaptations section" is not the test** — some personal skills don't have one,
   and that exact inference has already caused personal skills to be mistaken
   for vendor and wrongly treated as untouchable. If a skill carries no marker
   and no LICENSE, say so rather than assuming; treating a personal skill as
   vendor costs a lesson, and editing a vendor skill breaks its upstream
   updates, so when genuinely unsure, treat it as vendor and flag it.

5. **Don't build a plan from scratch — a plan already exists.** Apart from the
   branch switch in step 2, this skill only loads context. It builds nothing.

   There is a definite order to this build. It just isn't yours to work out, and
   it isn't written down here: **the user is holding it**, and reveals it one
   step at a time by invoking the skill for the piece they want next. Each piece
   is built by its own skill. So you are never planning in a vacuum, and you are
   never missing a plan — you're working inside one that's already set.

   What that means in practice: when this skill finishes, **stop**. Don't draft a
   build sequence, don't ask what the remaining steps are, and don't start one.

   Two failure modes this prevents, both of which look helpful:
   - **Running ahead.** Given a plan, an eager assistant executes it. Building
     three steps because the user asked for one destroys the thing the user came
     for — watching each piece get built and understanding it before the next.
   - **Building toward a step that hasn't been asked for yet.** Don't create a
     file "because we'll need it later", and don't design the current piece
     around a later one you're guessing at. Build exactly what the invoked skill
     specifies, then stop. If a later piece needs something different, its own
     skill will say so when its turn comes.

   When a skill's work is done, report what you built and wait.

6. **Report back, briefly:** which branch you ended up on (and say so plainly if
   you switched), what the project builds, and which skills are available. Then
   **stop and wait.** Don't recommend a first step or ask which one to run — the
   user is driving.

   **Don't audit the machine here.** Whether the tools are installed, which
   Python is present, whether `.env` has been filled in — none of that is this
   skill's business, and checking it early produces noise about things that
   aren't supposed to exist yet. Each of those belongs to the skill that
   actually deals with it, at the point where it matters.

### What the `main` branch is, and what it is not

The `main` branch was produced in one session, by one model, at one reasoning
effort. **Which ones is stamped in that branch's own README, alongside its build
date, and that is the only place it is recorded** — models are replaced every few
months, so a version pinned in here would be quietly wrong long before anyone
noticed. Matching what that README names gets you a build that looks more like
it; using a newer or different model gets you one that looks less like it, and
neither is a problem. That is all the stamp means.

**The `main` branch is one build that works. It is not the gold standard, not the
reference answer, and not a grading key.** It's what came out of one session, on
one day, from one model. A build that differs from it is not wrong — if yours
satisfies the requirements and runs, yours is exactly as valid, and it may well
be better. The requirements are the standard; that branch is one thing that met
them.

So when a comparison happens, treat a difference as **interesting, not
incorrect**: worth a look to see whether it reveals a requirement one of the two
missed, and otherwise just two legitimate ways to build the same thing. Never
"correct" a working build to look more like `main`, and never tell the user their
output is wrong because it diverged.

### Rules for this session

**Build from the spec, never from the finished answer.** The `main` branch holds
a completed version of this app. When the job is to **build** — to produce the
app by running the skills — that finished code is **off-limits as a source**.
Do not open it, copy it, paraphrase it, or check your work against it mid-build.
Write every file from the skill's "Local adaptations (this project)" section and
nothing else.

This is not a formality; it is the entire point of the exercise:

- **A spec that can only produce the app while the answer is visible is a broken
  spec, and copying hides the break.** If you catch yourself wanting to look at
  the finished file because the requirements feel thin, you have found a real
  gap. **Say so, name the missing decision, and fill the gap in the skill** —
  that repair is worth more than the file you were about to copy.
- **Nobody learns to direct an AI by watching it transcribe.** The reason to
  build is to see the requirements turn into working code.

How to tell which job you are on:

- **Building / reproducing** — the finished code is off-limits, as above. Work on
  `start`, or in an empty folder. If a finished copy happens to be sitting in the
  working directory, do not read it; ask to move or ignore it first.
- **Maintaining** — running, deploying, debugging, or changing the app that is
  already here (the normal job on `main`). Reading the existing code is not only
  fine, it is required. This is not the cheat; the cheat is *reproducing* a build
  with the answer open beside you.

Comparing against the `main` branch is legitimate **after** your build works,
never during it — finish, run it, then diff to see where the two landed
differently.

**Never edit a vendor skill.** Two kinds of skill live in `.claude/skills/`:

- **Personal skills** carry this project's specification in their "Local
  adaptations (this project)" section. Improve them freely — folding a lesson
  back into the responsible skill is how the next build gets better, and it is
  exactly what `/skill-end` does.
- **Vendor skills** were downloaded from someone else and must stay
  byte-identical to what shipped — no project details, no reformatting, no
  lessons. That way an upstream update drops straight in. When a step needs a
  vendor skill *and* this project's details, the details go in a personal
  companion skill, and the user invokes the two together.

Before editing any skill, ask which kind it is. If it shipped from elsewhere,
the lesson goes in the nearest personal skill instead.

**Never invoke a skill yourself — the user types the slash commands.** Running
`/skill-…` is the user's job, always. It is how they drive the build one piece at
a time, and it is the entire reason this works the way it does: they decide what
gets built next and when. So never run one on your own initiative, never chain
from the skill you're in into another one, and never treat "the next skill
obviously comes next" as permission. When a skill's work is done, report and
wait.

**Finish the skill you are in — don't stop halfway to check.** "Report and
wait" means at the END of the invoked skill, not partway through it. Once the
user has invoked one, build every part of what it specifies, then stop. Do not
pause after each file to confirm, do not summarise-and-wait, and do not ask
"shall I continue?" — the user already said what they wanted when they typed the
command, and a half-built piece is worse than either finishing or not starting.
The only reasons to stop early are a genuine blocker, something that needs the
user's say-so (sending anything to the broker), or a contradiction in the spec.

**Prefer a skill over hand-writing.** If a skill covers the work, don't
reconstruct it on the fly — its spec is more complete than anything you'd write
from memory. Treat "I'll just write this directly" as a signal to check the skill
list again, then **tell the user which skill covers it and let them invoke it.**

**Build it fully — no placeholders.** No `TODO`, no `FIXME`, no stub function
whose body is a comment describing what it should do, no note explaining what is
still missing. If something needs doing, do it and wire it end to end. The only
acceptable stopping point is a genuine external blocker, like a credential only
the user has — and even then, build everything up to that blocker.

**Paper trading, on purpose.** This build targets the broker's paper environment
and nothing else. Never point it at a live-money account, never substitute live
credentials or a live endpoint for the paper ones, and never present any of it as
trading advice. If the user supplies live-account credentials, stop and say why
rather than wiring them in.

**Staying simple is a requirement, not a budget.** This app places orders on its
own, and the only way anyone can be confident it places the right ones is to read
it and see that it does — so every "while we're here" addition costs more than
the time it takes to write, because it is one more thing standing between a
reader and that confidence. When a choice is between a mechanism and a plain file of Python, take
the plain file. What this build includes — how many of each thing, and what is
deliberately absent — is named by the skill that builds each piece, not here;
when one of them puts something out of scope, that is a decision, not an
oversight to fix.

**When two readings are both defensible, take the simpler one and say so —
do NOT add a setting.** A spec cannot pin everything, so you will hit choices
it does not decide. The instinct is to support both behaviours behind a
configuration switch and let the user pick later. Here that instinct is wrong:
a switch is two code paths, two things to test and one more line in
`.env.example`, which is exactly the bell the simplicity rule above exists to
prevent. Pick the reading that produces less machinery, state which one you
picked and why in a sentence, and move on. If it turns out to be the wrong
reading, changing it is a small edit — much smaller than the switch would have
been.

**Build it as though the orders were real.** They are not — this build is paper
only, and stays that way. But the whole point of a paper account is to behave
exactly like a funded one, so an app that is careless here is careless in the
only place it would have mattered, and the person watching learns the careless
version. Every guard is written as if an account were on the line. When a rule
elsewhere in these skills looks overcautious for the amount of code it is
guarding, that is why — the build skill that owns each piece names the specific
way that piece goes wrong.

**Never fail silently.** When the broker refuses an order or an external call
fails, log the full reason and return it. A swallowed error here is worse than a
crash: the app keeps running and looks healthy while an account is quietly in a
state nobody chose, and the longer that goes unseen the harder it is to work out
what it should have been.

**If you have to GUESS what happened, the logging isn't good enough — fix that
too.** When something goes wrong and you catch yourself saying "it must have
been X" or "presumably Y happened" instead of reading the answer off the log,
that is a second defect sitting next to the first one. Add the lines that would
have made it obvious, in the same piece of work. Log the WHY, not just the
what: the broker's actual response when a call fails, the fact that a fallback
or default branch ran AND the value it used, and which way a decision went. This
is the difference between a five-minute answer and an afternoon: the symptom
reaching the user is nearly always the same shape — an order somewhere
unexpected — and without a trace behind it, every possible cause looks equally
likely.

**A running process owns what it reads — don't change things underneath it.** If
this build has a long-running loop, it does not re-read the world the way a fresh
run does. Editing a file, rewriting the environment, or clearing something away
while it runs produces behaviour that matches neither the old state nor the new
one, and the confusion looks like a bug in the logic. Stop it, make the change,
start it again — and when you stop it, say so, because a process that was running
and now isn't is a change to the user's world, not just to yours.

**Every command gets a timeout.** Anything you run — an install, a request, a
worker, a test — gets an explicit time limit sized to what it should actually
take, not padded "just in case". A command with no bound doesn't fail, it
hangs, and a hung command in a build session looks identical to one that is
merely slow. If you can't predict roughly how long something should take, that
is the signal to say what you're about to run and why before running it, rather
than guessing at a ceiling.

**Never commit secrets.** The real `.env`, API keys, and account ids stay out of
git and off the screen. `.env.example` is the only one that ships.

**Add any new setting to `.env.example` in the same step that introduces it.**
If a piece of work starts reading a new environment variable, that file has to
learn about it immediately — otherwise it drifts out of date, and the first
sign is the deployed app behaving differently from the local one for no visible
reason.

**Your own working files do not belong in the project.** Scratch scripts,
debug dumps, notes to yourself and one-off checks are yours, not the user's:
keep them out of the repo, and delete the ones you do create as soon as they
have served their purpose. The tell that something has gone wrong is reaching
for `.gitignore` — **if you are about to ignore a file so it stops showing up,
that file almost certainly should not have been written into the project in the
first place.** A repo that has to hide your leftovers is not clean, it is
tidied over.

**Do not create branches, commit, or push unless asked.** Work on the branch
that is already checked out.

### How much the skills pin, and what is left to you

**This skill does not name the stack.** Which web framework, which broker, which
host, whether there is a database, how the app is laid out — none of that is
here, on purpose. Each of those belongs to the skill that builds that piece, and
is stated there once. Looking for the technology decisions in this file is the
wrong place to look; invoke the skill for the piece you are building and it will
tell you.

That is not a filing preference. A fact repeated in two places is a fact that
will eventually disagree with itself, and when the session skill and the build
skill disagree about the framework, the build stops on a contradiction that
neither file is obviously wrong about. **One fact, one home.**

What IS session-wide is the principle behind those choices, so apply it whenever
a skill seems quiet on something:

- **A skill pins a choice for exactly one reason: leaving it open would let this
  build come out visibly different** from the one it reproduces. That is the
  whole test. The things a viewer can see on screen get pinned; the mechanics
  behind them do not.
- **Everything not pinned is yours to decide, and deciding it is the job.** If
  you find yourself wishing the spec had named an approach, that is the work,
  not a gap in the brief. Decide, say what you decided and why, and move on.
- **Anything not asked for is out of scope.** Each build skill names its own
  exclusions explicitly, so that what was left out reads as deliberate rather
  than forgotten. Don't add past them, and don't treat an exclusion you disagree
  with as an oversight to fix.

# END

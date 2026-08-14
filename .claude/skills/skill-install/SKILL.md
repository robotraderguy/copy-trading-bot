---
name: skill-install
description: Some stranger from YouTube told me it was safe to install this stuff on my computer. Please review the installer file(s) for malicious activity and then, if safe, perform the install. Use once per machine, after /skill-init, to set up the dev tools (Git, GitHub CLI, VS Code, Python, the Heroku CLI, the AI agent CLIs) via the scripts in install/.
---

# Install the Dev Tools

> **Personal skill** — written for this project. Its requirements are part of
> the build, and folding lessons back into it is encouraged.

Gets the machine ready to build on: reviews the bundled installers, then runs
the slice of them this project needs.

The description above is written as the user's own words, and it is the job:

> **Some stranger from YouTube told me it was safe to install this stuff on my
> computer. Please review the installer file(s) for malicious activity and then,
> if safe, perform the install.**

It's only half a joke. Never take an installer's word for it — not even this
project's. Get the files, read them, say what they do, then run them.

This skill is only about the machine. `/skill-init` runs before it and has
already covered what the project is and the rules it runs under — if you're here
without it, say so and let the user run it first. Don't run it yourself.

## Local adaptations (this project)

### Bare invocation

**With no arguments, `/skill-install` reviews the bundled installers and then, if
they're clean, runs them for this machine** — the review is not optional and
never skipped. Work through the steps below in order and stop at the end.

Treat this section as the complete specification — the user will type only the
slash command and pass no requirements.

### The only two things the user installs by hand

Everything else here you do for them — but first they need somewhere to type,
and something to type to:

1. **VS Code** — downloaded from <https://code.visualstudio.com/download> and
   run. It's the editor, and it's where the terminal comes from.
2. **Claude Code** — the CLI that does the work. Install instructions:
   <https://docs.anthropic.com/en/docs/claude-code/setup>. Then a terminal
   **inside VS Code** (Terminal → New Terminal), running `claude`.

That's the manual part, start to finish. From here you install the rest — Git,
the GitHub CLI, Python, the deploy CLI — so don't send the user
off to hunt for download pages.

### Install ONLY what this build needs

The full manifest is comprehensive on purpose — it covers every tool any build
on the channel might want, and it runs to several gigabytes. **This project
needs a small slice of it, so don't run the whole thing.** Installing
everything wastes a lot of time on tools this build never touches.

Run the installer with exactly this set:

```
--only=git,gh,python,heroku,extensions,deps
```

| Installed | Why this build needs it |
|---|---|
| `git` | the project is a git repo, and deploying means pushing one |
| `gh` | creating the repo the host deploys from, without the website |
| `python` | the language this build runs on |
| `heroku` | the CLI for the host this project deploys to |
| `extensions` | the editor add-ons that make the code readable |
| `deps` | this project's own Python packages |

**Deliberately skipped:** every database tool, because **this build has no
database** — settings and accounts live in the environment file, and the copier
remembers what it copied by stamping the orders it places at the broker. Also
skipped: the deploy CLIs for hosts this project doesn't use, the other AI agent CLIs, and the editor itself — that
one is hand-installed before any of this runs, so the manifest would only
presence-check it.

If the user asks for something outside that list later, install just that tag —
don't re-run the whole manifest to get one tool.

### Step 1: Review the installer(s) for malicious activity — ALWAYS

Read the full text of every file in [`install/`](../../../install/)
(`bootstrap.bat` for Windows, `bootstrap.ps1` for PowerShell,
`bootstrap.sh` for macOS, `bootstrap-linux.sh` for Debian/Ubuntu) before
running anything. Check specifically for:

- Downloads from unofficial domains — everything should come from winget,
  Homebrew, apt, an official vendor repo, npm, or pip; name anything else
- Piping remote content straight into a shell (`curl … | bash`) from a
  domain that isn't the tool vendor's own documented installer
- Anything that reads or sends files off the machine (credentials, SSH
  keys, browser data), adds persistence (startup entries, scheduled
  tasks, shell-profile edits beyond PATH), or hides behind obfuscated or
  encoded commands
- Privilege escalation beyond what a package install legitimately needs

Then tell the user, in plain English: what the script installs (every item has
a why-comment above it), where each piece comes from, and whether anything
looked suspicious. **If anything is off, STOP and show them — do not run it.**

### Step 2: If it's clean, run the right installer for this computer

- **Windows** — `install\bootstrap.bat --only=git,gh,python,heroku,extensions,deps`
  from the terminal. Don't double-click it — that runs the FULL manifest.
  (winget, so no PowerShell execution-policy friction.)
- **macOS** — `bash install/bootstrap.sh --only=git,gh,python,heroku,extensions,deps` (Homebrew)
- **Debian/Ubuntu** — `bash install/bootstrap-linux.sh --only=git,gh,python,heroku,extensions,deps`
  (apt + official vendor repos; npm globals need sudo on Linux)

**Tell the user about the permission prompts BEFORE you start.** These
installers can't run silently end to end, and the prompt is theirs to answer,
not yours:

- **Windows** — a "Do you want to allow this app to make changes to your
  device?" box for several of the tools. It can appear **behind** the terminal.
- **macOS / Linux** — a request for their login password, typed **into the
  terminal itself**, with nothing echoed as they type.

So say up front that they're coming and should be approved — they're the
official installers you just read through in the previous step, which is exactly
why that review happens first.

If the user declines one, that tool simply doesn't install — carry on with the
rest and report which one was skipped.

### Step 3: Check the Python you ended up with

The installer handles this for a machine with no Python. The case it can't
decide is the one where the user **already had one**, so confirm it before
moving on:

- **The version has a floor: Python 3.13 or newer.** That isn't a preference —
  the host this gets deployed to refuses anything older, so an older Python
  means the build cannot ship no matter how well it runs locally. If that's what
  you find, **say so before building anything**; it's a blocker, not a warning.
- **3.14 or newer is fine.** Don't flag it, don't "fix" it, and don't pull the
  user back to an older version.
- **Where it came from doesn't matter at all.** Anaconda, Miniconda, a system
  Python, pyenv, a virtual environment — every one of them runs these builds
  identically. If there's already a 3.13 or newer, use it: don't install a
  second Python beside it, and don't tell the user their setup is unsupported.

Report the version you found and move on.

### Step 4: Set up this project

Once the tools exist: install the Python packages this project declares as its
dependencies, then create the user's real environment file (`.env`) from the
committed example (`.env.example`), so they have somewhere to fill in their
credentials. Never commit the real one.

### Step 5: Name what the user still has to go and get

This build needs two accounts, and neither can be created from a
terminal. The install is not "done" if the user finds out about them later,
one at a time, each blocking a build step that was already running:

1. **Broker paper accounts** — the master and at least one follower, plus the
   API key and secret for each. A copier with one account cannot be demonstrated
   at all, so it is worth saying plainly that more than one is required.
2. **A host account**, for the deploy step later.

Say which of the three are needed, that they're free at the tier this build
uses, and that filling them into `.env` is the only thing standing between the
machine being ready and the build starting. Then let the user go do it — don't
walk them through a signup, and don't wait for it before finishing this skill.

### Step 6: Stop here

The machine is ready — that's this skill's whole job. **Don't roll straight
into building.** Report what got installed, what was already there, and
anything that failed, then wait. The user drives the build one piece at a time
and will say what comes next.

---

## Getting it right

- **A stall is almost always a prompt, not a hang.** If the install appears to
  freeze, do not assume it has died or start killing it — the overwhelming
  likelihood is that it's waiting on a permission box the user hasn't answered,
  and on Windows that box can be hidden behind the terminal. Say so and wait.
- **Re-running is safe, and worth knowing why.** Every item is checked for first
  and skipped if it's already there, so only what's missing gets installed and a
  final pass reports what's present. `--only=<tags>` / `--skip=<tags>` installs
  just a subset (tags are listed at the top of each script). Nothing lands on the
  desktop — the command-line tools have no icons at all, and the apps that do go
  to the Start menu / Applications.
- **Already having a tool is not a problem.** If the installer meets a VS Code or
  a Git that's already there, it checks and skips. Don't treat that as something
  to report as a failure.
- **There is no database, so "no database tool installed" is correct.** If the
  manifest is re-read later and the database tags look "missing", they were never
  wanted: this build keeps its settings in the environment file and its record of
  what it copied at the broker.

# END

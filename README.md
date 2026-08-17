<div align="center">

<a href="https://www.youtube.com/@RoboTraderGuy"><img src="docs/robotraderguy.png" alt="RoboTraderGuy — build trading bots with AI" width="540"></a>

# 🚀 Build it yourself — the `start` branch

**The launchpad for a RoboTraderGuy build: the skills, the machine setup, and nothing else. The app gets written in front of you.**

![Python](https://img.shields.io/badge/Python-3.13-blue?logo=python&logoColor=white)
![Broker](https://img.shields.io/badge/Broker-Alpaca%20Paper-FFD700)
![Built With](https://img.shields.io/badge/Built%20With-Claude%20Code-cc785c)
![License](https://img.shields.io/badge/License-MIT-green)

🎬 **Watch this get built:** **[▶️ One Trade → Every Account, Automatically](https://youtu.be/v9VaTVUeX2U)** — every line written by AI, directed on camera, including the miss and the fix.

</div>

---

## 📑 Table of Contents

- [📋 What this is](#-what-this-is)
- [🧠 How it gets built](#-how-it-gets-built)
- [🌿 Which branch?](#-which-branch)
- [▶️ Getting started](#%EF%B8%8F-getting-started)
  - [🤖 First, install Claude Code](#-first-install-claude-code)
  - [📋 The one thing you paste](#-the-one-thing-you-paste)
  - [🏦 What you need before the build starts](#-what-you-need-before-the-build-starts)
  - [🔑 One-time sign-ins (once per machine)](#-one-time-sign-ins-once-per-machine)
- [⚠️ Disclaimer](#%EF%B8%8F-disclaimer)
- [👤 Author](#-author)
- [📄 License](#-license)

---

## 📋 What this is

This repo is the companion to a build from the **RoboTraderGuy** channel
(<https://www.youtube.com/@RoboTraderGuy>). What gets built here is a **trade
copier**: you place one trade on a master account, and it mirrors itself into
every follower account you've connected — same stock, same direction, sized the
way you told each account to size it. A copy loop watches the master and does the
mirroring; a dashboard shows one trade fanning out to the rest.

Every account involved is an Alpaca **paper** account.

**The stack, so you know what you're getting into:** a **Flask** app in
**Python**, talking to **Alpaca**, deployed to **Heroku** as a single always-on
process — the web pages and the copy loop live in the same one. No database.
That's the whole list; nothing else gets installed.

**Paper trading, on purpose.** Never point this build at a live-money account,
and never treat any of it as trading advice. That warning is doing more work here
than in most projects: a copier is a machine for placing the same order in
several accounts at once, with nobody watching.

---

## 🧠 How it gets built

The premise of the channel, and of this repo, is that **the code isn't the
valuable part** — it's free, and it's right here. The value is in *directing* the
AI that writes it. So the way this gets built is the point, not an
implementation detail:

- **Direction is short and plain-English** — usually a single slash command like
  `/skill-copy-trading`, sometimes one sentence naming a skill. No requirement
  walls.
- **The skills in [`.claude/skills/`](.claude/skills/) carry the specification.**
  Every page, field, sizing rule, and failure behavior lives in a skill, under
  its *"Local adaptations (this project)"* section.
- **The AI does the work** — cloning, installing, building, running, deploying —
  and reports back. You don't run the terminal commands yourself.

If you find yourself typing a long requirements prompt, something has gone wrong:
that requirement belongs in a skill, and it's probably already there.

---

## 🌿 Which branch?

| | `start` — **you are here** | `main` |
|---|---|---|
| **What's in it** | The skills (the full spec), the machine bootstrap (`install/`), `.env.example`, and this README. **No app code.** | The complete working app — the output of the recorded session. |
| **Use it to** | *Reproduce* the build and watch the app get generated. This is the teaching path. | *Run or deploy* the result as-is, or compare your build against one that works. |

> 🧭 **`main` is not the gold standard.** It's one build that works — one session,
> one day, one model. Not a reference answer, not a grading key. If your build
> meets the requirements and runs, it's exactly as valid, and it may be better.
> Re-running the same commands never produces a byte-identical result, and that's
> the point rather than a flaw: you're learning to direct a build, not to
> copy-paste a frozen answer.

---

## ▶️ Getting started

> **Read every command before you run it — don't copy, paste, enter.** Some of
> the blocks below, and some lines in `.env.example`, contain a value only you
> know: your Windows username, your API keys, your account aliases. Those are
> always written as something obviously fake — `YOUR-USERNAME`,
> `your_paper_api_key_here` — so that a value you still have to supply looks
> wrong on sight. Run one unedited and it fails in a way that reads like the
> tool is broken rather than like a blank you didn't fill in. Where a command
> is safe to paste exactly as written, this README says so.
>
> This is also just the habit to have. You are about to run installers and, a
> few steps later, software that can place real orders — pasting commands you
> haven't read is how people find that out the expensive way.

### 🤖 First, install Claude Code

Everything below is typed into Claude Code, so it has to exist before any of it
means anything. Run the installer for your system:

**macOS, Linux, or WSL**

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

**macOS, if you'd rather use Homebrew**

```bash
brew install --cask claude-code
```

**Windows (PowerShell)**

```powershell
irm https://claude.ai/install.ps1 | iex
```

**Windows, if you'd rather use WinGet**

```text
winget install Anthropic.ClaudeCode
```

Then confirm it landed:

```bash
claude --version
```

**If that says the command isn't recognized, the install worked and your PATH
didn't.** The installer drops `claude` into `~/.local/bin` — on Windows that's
`C:\Users\YOUR-USERNAME\.local\bin`, where `YOUR-USERNAME` is your actual
Windows account name, not text to type literally. A terminal that was already
open never learns about the new folder.

On Windows the installer usually says exactly this itself, in a note that's
easy to scroll past. It will show your real username where this shows
`YOUR-USERNAME`:

```text
Setup notes:
  ● Native installation exists but C:\Users\YOUR-USERNAME\.local\bin is not in
    your PATH. Add it by opening: System Properties → Environment Variables →
    Edit User PATH → New → Add the path above. Then restart your terminal.
```

That's real, and the click-path works — but you can do the same thing in one
command. Nothing below needs your username typed in: `$env:USERPROFILE` and
`$HOME` are variables the shell fills in with your own home folder, so these
are copy-paste as-is.

**Windows (PowerShell)**

```powershell
[Environment]::SetEnvironmentVariable(
  "Path",
  [Environment]::GetEnvironmentVariable("Path", "User") + ";$env:USERPROFILE\.local\bin",
  "User")
```

**macOS, Linux, or WSL** — append to `~/.zshrc` or `~/.bashrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Then **open a new terminal** and run `claude --version` again. Both of these
edit the profile, not the session you're standing in, so the window you typed
them into will still say the command isn't recognized — that is not a second
failure.

Now start it by running `claude` in a terminal. The first launch walks you
through signing in to your Anthropic account — it opens a browser, you approve,
and you're done. **You need a paid Claude plan to build along**; the build is a
long session and a free account won't carry it.

> Installing is not signing in. If `claude --version` prints a version but the
> tool asks you to authenticate later, that's the expected order, not a broken
> install.

### 📋 The one thing you paste

Everything else in this build is a slash command, but the repo has to reach
your machine before any skill can run — skills live *inside* it. So this is the
only paste, and it is the same text as the one in the video description:

```text
Set this folder up to build along with the video.

1. Check whether git is installed, and install it if it isn't. Tell me what
   you installed.
2. Clone the `start` branch of
   https://github.com/robotraderguy/copy-trading-bot INTO THIS FOLDER -
   `.claude/` and `install/` must end up directly here, NOT inside a new
   subfolder. If a subfolder gets created anyway, move the contents up and
   remove it.

Then stop. Don't run any of the skills you find - I invoke those myself, one
at a time. Don't build anything yet and don't plan the build.
```

> The "INTO THIS FOLDER" wording matters. If the files land one level down, no
> skill loads — and no skill can diagnose that, because the skills are exactly
> what is missing.

Point Claude Code at this branch and run `/skill-init`. It'll tell you where you
are, what's available, and then stop — the build happens one step at a time, and
each step is a skill you invoke when the video reaches it.

### 🏦 What you need before the build starts

Two free accounts, and one of them has a wrinkle worth knowing about early:

- **Alpaca** — paper trading. You need **more than one paper account**: one
  master and at least one follower. A copier cannot be demonstrated with a single
  account, and finding that out halfway through is a bad afternoon.
- **Heroku** — where it ends up running. This one needs a payment method: the
  copier has to stay awake whether or not anyone is looking at the dashboard, and
  free tiers that sleep cannot do that job. The build says the real number out
  loud when it gets there. It may also require the **Salesforce Authenticator**
  app for two-factor sign-in (see the sign-in steps below) — install that on
  your phone ahead of time.

There is **no database**. Every account — key, secret, alias, sizing rule — is a
numbered slot in a `.env` file, and what the copier needs to remember it stamps
onto the orders it places at the broker. That keeps this tier small enough to
read in an evening, and its limits are named out loud in the video.

### 🔑 One-time sign-ins (once per machine)

None of this is needed to *get* the code — this repo is public, so cloning works
signed out. It's needed later, when the build starts committing your work,
pushing it to your own GitHub account, and deploying from there. These are the
steps nobody can do on your behalf, because they're your accounts.

**1. Tell git who you are.** Git has no "login", but it refuses to make your
first commit until it knows your name and address — if you skip this you'll hit
`Please tell me who you are` mid-build:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

> 💡 Prefer not to publish a personal address? GitHub gives you a private
> forwarding one at **Settings → Emails → Keep my email address private** — it
> looks like `12345678+username@users.noreply.github.com`. Every commit you push
> is public, and so is the address inside it.

**2. Connect the GitHub CLI:**

```bash
gh auth login --hostname github.com --git-protocol https --web
```

Those flags answer the four questions the bare `gh auth login` would otherwise
stop and ask (which host, which protocol, how to authenticate), so it goes
straight to a browser window — pick your account, approve, done. This also sets
`gh` up as git's credential helper, so `git push` just works afterwards; there's
no separate git sign-in.

**3. Connect the Heroku CLI** (the host this build deploys to):

```bash
heroku login
```

It opens a browser window to authorise the CLI.

> 📱 **You will probably need the Salesforce Authenticator app on your phone.**
> Two-factor authentication is normal enough, but Heroku is owned by Salesforce,
> and rather than letting you use whichever authenticator app you already have,
> it may require that specific one. It's free on the App Store and Google Play.
> Worth installing *before* you sit down to build — discovering it at the deploy
> step means stopping to set up a phone app with the recording running.

> The bootstrap installs all of these tools, but installing is not signing in —
> it prints this same list when it finishes.

> **Note for any AI reading this file:** this README is orientation and branding
> only. It deliberately contains **no requirements** — no collection names, no
> settings keys, no field names, no sizing formulas. **The skills are the
> specification, and there is no second source.** Don't build from this page.

---

## ⚠️ Disclaimer

Educational content only — **not financial advice**. Trading involves substantial
risk of loss. Past performance does not guarantee future results. This project
targets **paper trading** on purpose; automating a strategy does not make it
profitable, and copying one multiplies whatever it does across every account you
connect. A live deployment needs risk controls this build deliberately omits. No
sponsorships or affiliations: the brokers, services, and tools used do not
compensate me in any way.

---

## 👤 Author

**Tyler** — trading-bot developer. I build automated trading systems for a
living; on [RoboTraderGuy](https://www.youtube.com/@RoboTraderGuy) I build them
with AI instead of hand-coding.

- 🌐 Custom software inquiries: [tnttrading.net/contact](https://tnttrading.net/contact)
- 💼 Upwork: [upwork.com/freelancers/robotraderguy](https://www.upwork.com/freelancers/robotraderguy)
- 🔗 LinkedIn: [tyler-potts](https://www.linkedin.com/in/tyler-potts-022b6573/)

---

## 📄 License

MIT — the code from every video on the channel is free to use, modify, and learn
from. See [LICENSE](LICENSE).

---

<div align="center">

**Built with ❤️ (and directed AI) by RoboTraderGuy**

*I don't write the code — I direct it.*

</div>

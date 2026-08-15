<div align="center">

<a href="https://www.youtube.com/@RoboTraderGuy"><img src="docs/robotraderguy.png" alt="RoboTraderGuy — build trading bots with AI" width="540"></a>

# 🔁 One Trade → Every Account

**Copy-trading for Alpaca paper accounts — one order on the master, mirrored to every follower and sized by a
multiplier you set. Built entirely with AI.**

![Python](https://img.shields.io/badge/Python-3.13-blue?logo=python&logoColor=white)
![Flask](https://img.shields.io/badge/Flask-3.1-000000?logo=flask&logoColor=white)
![Broker](https://img.shields.io/badge/Broker-Alpaca%20Paper-FFD700)
![Heroku](https://img.shields.io/badge/Deploy-Heroku-430098?logo=heroku&logoColor=white)
![Built With](https://img.shields.io/badge/Built%20With-Claude%20Code-cc785c)
![License](https://img.shields.io/badge/License-MIT-green)

<!-- PLACEHOLDER: swap the channel URL below for the direct video URL once the video is published. -->
🎬 **Watch this get built:** **[▶️ YouTube — video coming soon](https://www.youtube.com/@RoboTraderGuy)** — every line written by AI, directed on camera, including the misses and the fixes.

</div>

---

This is the **`main`** branch: the finished application. To build it yourself instead, start from
[`start`](../../tree/start).

---

## 📑 Table of Contents

- [📋 Overview](#-overview)
- [🌿 Which branch? (`start` vs `main`)](#-which-branch-start-vs-main)
- [🏗️ Architecture](#️-architecture)
- [🚀 Quick Start](#-quick-start)
- [⚙️ Configuration](#️-configuration)
- [📊 Dashboard Pages](#-dashboard-pages)
- [🧩 The Skills](#-the-skills)
- [🧱 What It Does / Doesn't Do](#-what-it-does--doesnt-do)
- [☁️ Deployment](#️-deployment)
- [👤 Author & Contact](#-author--contact)
- [⚠️ Disclaimer](#️-disclaimer)
- [📄 License](#-license)

---

## 📋 Overview

If you run more than one account, every trade is the same trade typed several times — and the later ones fill at a
worse price than the first.

This project closes that gap. A Flask app watches your **master** Alpaca paper account for new orders and replays
each one onto every **follower** account, scaled by that follower's multiplier. A five-page dashboard shows what
copied, what didn't, and why.

Every line was written by Claude Code, directed by short plain-English prompts that invoke the reusable **skills**
in [`.claude/skills/`](.claude/skills/). The human contribution is the direction: what to copy, what must never be
copied twice, and where the scope ends.

> **Re-running these commands produces a slightly different build — and that's the point, not a flaw.** AI is
> non-deterministic, so no two runs are byte-identical. That is exactly why the skill matters more than any single
> output: you're learning to *direct* a build, not copy one frozen answer. The requirements are pinned in the
> skills, so every run lands on the same working app — just assembled its own way.

---

## 🌿 Which branch? (`start` vs `main`)

This repo has two branches, for two different goals. Ask Claude Code to clone whichever fits — you don't run git
yourself.

| | `start` — **build it yourself** | `main` — **one finished build** |
|---|---|---|
| **What's in it** | The skills (the full spec), the machine bootstrap (`install/`), `.env.example`, and a README. **No app code.** | The complete working app: `copier.py`, `broker.py`, `config.py`, `webapp.py`, templates, the deploy blueprint. |
| **Use it to** | *Reproduce* the build — run the skills in order and watch the app get generated in front of you. This is the teaching path. | *Run or deploy* the app as-is. Also a build to compare your own against — one that works, not the right answer. |
| **Who it's for** | Anyone following along, learning to direct the AI. | Anyone who wants the result, or a working baseline to modify. |

> 🧭 **This branch is not the gold standard.** It's one build that works — what came out of one session, on one
> day, from one model. Not a reference answer, and not a grading key. If your build satisfies the requirements and
> runs, it is exactly as valid, and it may well be better. The **requirements** are the standard.

**The skills on this branch carry the lessons from the recorded session.** After the build, `/skill-end` folded
back what went wrong — the copy switch that defaults off, the config var the cloud inherits, the difference
between an error the broker returns and one your own account caused. So `main`'s skills are a little smarter than
`start`'s, which are the ones the video begins with.

---

## 🏗️ Architecture

Four modules. No database — the accounts are numbered slots in `.env`, and what the copier must remember is
stamped onto the orders themselves at the broker.

```
copytrade-alpaca/
├── config.py          Reads .env into account slots; the only place settings are parsed
├── broker.py          The only place this app talks to Alpaca (orders, positions, account)
├── copier.py          The copy engine — polls the master, replays to followers, dedupes
├── webapp.py          Flask app: five pages + the trade form
├── templates/         base · copier · trade · accounts · orders · positions · error
├── static/            One stylesheet (Alpaca-yellow accent, dark)
├── install/           One-command machine bootstrap
├── docs/              Screenshots used by this README
├── .claude/skills/    The nine skills that generated all of the above
├── Procfile           web: gunicorn webapp:app --workers 1 --threads 4
└── requirements.txt   Flask · gunicorn · python-dotenv · requests
```

**How a copy actually happens.** The copier polls the master account's orders every `POLL_SECONDS`. A new order
is replayed to each follower with its quantity multiplied. To guarantee it never copies the same order twice
without a database, it **stamps the master's order id onto the follower order's `client_order_id`** and reads it
back — the broker itself becomes the record of what has been copied.

Two consequences worth knowing before you run it:

- **It copies on SUBMISSION, not on fill.** A follower order goes out as soon as the master's order exists,
  rather than waiting for it to fill — which on a paper account can be hours.
- **A copy appears up to one poll interval late.** With the default `POLL_SECONDS` the follower shows up a few
  seconds after the master. That is the loop working, not a failure.

---

## 🚀 Quick Start

**You don't run build commands yourself — you install one tool, then direct the AI.** That is the whole point: the
code here was written by Claude Code, and you reproduce it the same way.

1. **Install the two tools by hand** — [VS Code](https://code.visualstudio.com/download) and
   [Claude Code](https://docs.anthropic.com/en/docs/claude-code/setup). Everything after that installs itself.
2. **Get your accounts** (browser, one-time): two or more **Alpaca paper** accounts, and a **Heroku** account with
   the CLI signed in.
3. **Open Claude Code in an empty folder and direct it.** Paste the text below, then run the skills in order —
   Claude installs the dependencies, builds each piece, and deploys for you.
4. **Place one order on the master** from the Trade page and watch the followers fill.

### 📋 The one thing you paste

Everything else in this build is a slash command, but the repo has to reach your machine before any skill can run —
skills live *inside* it. So this is the only paste, and it is the same text as the one in the video description:

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

> The "INTO THIS FOLDER" wording matters. If the files land one level down, no skill loads — and no skill can
> diagnose that, because the skills are exactly what is missing.

<details>
<summary><b>Running THIS branch instead of building it</b></summary>

`main` is the finished app, so there is nothing to build. Ask Claude Code to clone this branch, install the
dependencies and start it — it reads a local `.env` if there is one and falls back to working defaults for
everything except the account credentials.

You still have to supply your own Alpaca keys; see [Configuration](#️-configuration).

</details>

<details>
<summary><b>🏦 Getting your Alpaca paper accounts</b></summary>

You need at least two — one master, one follower. In the Alpaca dashboard:

- **Home** shows the API key for the account you are viewing, with a **Regenerate** button. The secret is shown
  **once**, at creation or regeneration — if you did not copy it, regenerate and take the new pair.
- **Account → Paper accounts** opens another. You can run up to three, which is why the `.env` has three slots.

</details>

---

## ⚙️ Configuration

Everything lives in `.env`. There is no settings page and no database.

| Variable | What it does |
|---|---|
| `ACCOUNT_1_ALIAS` / `_KEY` / `_SECRET` | **Slot 1 is the MASTER** — the account you trade by hand |
| `ACCOUNT_2_ALIAS` / `_KEY` / `_SECRET` | A follower |
| `ACCOUNT_2_MULTIPLIER` | Size relative to the master (`2` → 100 on the master becomes 200) |
| `ACCOUNT_2_FIXED_SHARES` | Optional: a flat share count that ignores the master's quantity |
| `ACCOUNT_3_*` | A second follower, same shape. Unfilled slots are reported and skipped |
| `COPYING_ENABLED` | The kill switch. **Must be `true` for anything to copy** |
| `POLL_SECONDS` | How often the master is checked for new orders |
| `STALE_ORDER_SECONDS` | Orders older than this are never copied — so starting the app doesn't replay history |
| `FLASK_SECRET_KEY` | Session signing. **Set a real random value**, never the placeholder |

> ⚠️ **`COPYING_ENABLED` defaults to `false`, and it is the first thing to check when nothing copies.** Setting it
> locally is not enough — the cloud has its own copy of every variable, and it will happily inherit the same
> `false`. Check both.

---

## 📊 Dashboard Pages

| Page | Route | Shows |
|---|---|---|
| **Copier** | `/` | Master and followers, the kill-switch state, what was copied and when |
| **Trade** | `/trade` | Place an order on the master — symbol, side, quantity, order type, duration. Previews before sending |
| **Accounts** | `/accounts` | Who trades, who follows, and each account's buying power |
| **Orders** | `/orders` | Recent orders across every account, newest first |
| **Positions** | `/positions` | Open positions per account |

The Trade page places the order and stops there; the copier picks it up on its next pass. Sending from the form
*and* calling the engine directly would copy the same trade twice.

---

## 🧩 The Skills

Nine skills in [`.claude/skills/`](.claude/skills/) generated this app. They are the actual spec — the app is
their output.

| Skill | Its job |
|---|---|
| `skill-init` | Loads the project, reads the README, inventories the skills, and stops |
| `skill-install` | Reads the bootstrap scripts for anything malicious, explains them, then installs |
| `skill-copy-trading` | The copy engine: dedupe, sizing, per-follower isolation, the kill switch |
| `skill-broker-api` | Alpaca specifics — key + secret auth, paper base URL, the four endpoints used |
| `skill-dashboard` | The five pages and the trade form |
| `minimalist-ui` | Third-party design skill from the [taste-skill](https://github.com/lxlnx/taste-skill) repo |
| `skill-deploy-cloud` | Procfile, gunicorn, the private repo, and the Heroku deploy |
| `skill-creator` | Vendor skill, shipped unmodified |
| `skill-end` | Harvests the session's lessons back into the skills above |

---

## 🧱 What It Does / Doesn't Do

**It does:**

- Copy whole-share equity orders from one master account to every configured follower, sized by that follower's
  multiplier or a fixed share count.
- Guarantee an order is copied exactly once, by stamping the master's order id onto the follower order and reading
  it back from the broker.
- Ignore anything older than `STALE_ORDER_SECONDS`, so starting the app never replays the day's history.
- Keep followers independent — one account with bad credentials or no buying power does not stop the others.
- Retry a failed submission with exponential backoff, and distinguish a rate limit from a refusal.
- Show the copier, a trade form, accounts, orders and positions on five pages.

**It doesn't:**

- Touch real money. Alpaca **paper** is deliberate and permanent.
- Copy anything but equities in whole shares — no options, no crypto, no fractional.
- Wait for the master to fill. A copy goes out on submission, and lands within one poll interval.
- Support more than one broker, or more than one user.

Those absences are scope, not oversights. Each one is a decision recorded in the skills.

---

## ☁️ Deployment

The app deploys to **Heroku** from a private GitHub repo, described by [`Procfile`](Procfile).

| Setting | Value | Why |
|---|---|---|
| Runtime | Python | `.python-version` pins the version |
| Start command | `gunicorn webapp:app` | A production web server, not Flask's development one |
| Workers | **1** | One copier. A second worker would poll the same master and copy every order twice |
| Threads | 4 | The pages stay responsive while the copy loop is mid-poll |
| Plan | **Basic**, not Eco | See below |

> ⚠️ **Why not the cheap plan.** Heroku has no free tier at all, and the **$5 Eco** dyno sleeps after about 30
> minutes without traffic. A sleeping copier does not miss a cosmetic refresh — it misses the trade it exists to
> mirror. **$7 Basic** stays awake, and that is what this build assumes.

Secrets are set as Heroku **config vars**, never committed. The real `.env` stays out of git entirely.

**The only thing you do by hand is sign in.** `/skill-deploy-cloud` creates the repo, pushes it, creates the app,
copies your settings up as config vars and deploys — but it cannot authenticate as you:

```bash
# Opens a browser to authorise the Heroku CLI. Everything after this is the AI's job.
heroku login
```

Two things to check once it is live, both learned the hard way on camera:

- **`COPYING_ENABLED` in the cloud config vars.** Setting it locally does not set it in Heroku — the cloud gets
  its own copy of every variable, including the `false` it shipped with.
- **Stop any local copy of the app still running.** Two copiers watching the same master double every trade.

---

## 👤 Author & Contact

**Tyler** — trading-bot developer (Upwork Top Rated Plus, 100% Job Success). I build automated trading systems for
a living; on [RoboTraderGuy](https://www.youtube.com/@RoboTraderGuy) I build them with AI instead of hand-coding.

- 🌐 Custom software inquiries: [tnttrading.net/contact](https://tnttrading.net/contact)
- 💼 Upwork: [upwork.com/freelancers/robotraderguy](https://www.upwork.com/freelancers/robotraderguy)
- 🔗 LinkedIn: [tyler-potts](https://www.linkedin.com/in/tyler-potts-022b6573/)

---

## ⚠️ Disclaimer

Educational content only — **not financial advice**. Trading involves substantial risk of loss, and past
performance does not guarantee future results.

This project targets **paper trading** on purpose. Copy-trading multiplies both sides of a mistake: a bad order
becomes several bad orders, instantly, across every account. A live deployment needs the risk controls this build
deliberately omits.

No sponsorships or affiliations: the brokers, services, and tools used do not compensate me in any way.

---

## 📄 License

MIT — the code from every video on the channel is free to use, modify, and learn from. See [LICENSE](LICENSE).

---

<div align="center">

**Built with ❤️ (and directed AI) by RoboTraderGuy**

*I don't write the code — I direct it.*

</div>

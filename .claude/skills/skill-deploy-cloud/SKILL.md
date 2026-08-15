---
name: skill-deploy-cloud
description: Get this project onto a cloud host and actually run it there — one always-on process serving the dashboard and running the copy loop — then hand back the address. Use when the build needs to run without the user's laptop being on.
---

# Cloud Deploy

> **Personal skill** — written for this project. Its requirements are part of
> the build, and folding lessons back into it is encouraged.

Puts the finished app on a public host, always on. That last part is the whole
point: a copier that only runs while a laptop is open is not a copier.

## Local adaptations (this project)

### Bare invocation

**With no arguments, `/skill-deploy-cloud` produces the host files AND actually
puts the app live, then hands back the public address.** A run that stops at generated files has not finished the job.

Typed arguments change that: `audit` reports on what exists, `remove` takes the
host files out.

Treat this section as the complete specification — the user will type only the
slash command and pass no requirements.

### Before it can go live — the user's job, not yours

Three one-time things need a browser, and they belong to the user: **creating the
host account, signing both CLIs in** (the host's and GitHub's), and **adding a
payment method to the host account**. That last one is not optional here — see
the plan rule below — and it is better said now than discovered halfway through a
deploy. Tell them plainly if any of them isn't done, and wait.

**After that, do the rest yourself.** Once those CLIs are signed in, creating the
app, setting the config, deploying, scaling the processes, and reading back the
URL and the logs are all things the host's CLI can do — so don't send the user to
its web dashboard for any of it, and don't assume it can't. Check its own help
before concluding something needs the website; if a step really does, name which
one and why.

If the app somehow already exists (the user made it by hand, or a previous run
created it), don't create a second one — confirm the existing one from the
terminal, then update it and deploy.

### What has to be true when you're done

- **One process, and it is always on.** The copy loop runs inside the web app,
  so there is a single thing to deploy and a single thing to keep awake. **That
  "always on" decides which plan this can run on.** A plan that puts the app to
  sleep when nobody has visited the website is fine for a demo and useless here:
  the copier's whole job happens when nobody is looking at it. **Check the host's
  current plan terms rather than trusting anything written here** — they change —
  and if the honest answer is that the free plan won't do, say so plainly and
  name what the cheapest plan that will costs.
- **It can reach out as well as be reached.** Both processes call the broker over
  the open internet, and the worker needs the database too.
- **The public address is printed at the end.** That string is the deliverable.
- **It runs under a production web server**, not the framework's development
  server. (Gunicorn is the usual pick.) **Check how that server starts worker
  processes.** More than one worker means more than one copy loop, which means
  every trade copied more than once — pin it to a single worker, and say why in
  the config.
  - **And check how it starts them, not just how many.** A server that
    *preloads* the app imports it once and forks the workers from that image,
    and **threads do not survive a fork** — so a copy loop started at import
    lives in the parent and dies with it. The result is the worst-shaped
    failure this build has: every page serves perfectly, the dyno reports
    healthy, and nothing is ever copied. Whichever way the server is
    configured, confirm the loop is running *inside the process that serves
    the pages*.
- **The default plan is the sleeping one.** Creating an app does not put it on
  a plan that stays awake — hosts default to their cheapest tier, which is the
  one that sleeps. **Set the plan explicitly as part of the deploy and read it
  back**, rather than assuming the app landed somewhere always-on. It reports
  itself as up either way.
- **The deployed Python matches the local one.** Check what's actually
  installed rather than assuming, and pin it.
- **Heroku is the host.** Just Heroku — don't generate config for other
  platforms, and don't offer them as alternatives.
- **The code lives in a PRIVATE GitHub repo.** Create it private and keep it
  private — this is the user's trading app, holding the credentials to real
  brokerage accounts. (The repo the skills were cloned from is a separate,
  public thing; don't confuse the two.)
- **Create that repo with the GitHub CLI, from the terminal.** It's installed
  already, so there's no reason to send the user to the website — a browser
  detour mid-run is exactly what the manual step above exists to avoid. Signing
  that CLI in is a one-time thing the user does themselves; if it isn't signed in
  yet, say so and wait rather than working around it. Tell them the repo name
  you're using.
  - **Check WHICH account it will be created under, and say so before creating
    it.** The CLI can hold several signed-in accounts and quietly uses whichever
    is active, which is not necessarily the one this project belongs to. Name
    the owner as well as the repo, and confirm it against where the project's
    other repos live rather than accepting the default.
  - **A private repo is invisible to a browser signed in as anyone else**, so
    "I only see two repos" is the expected result rather than a failed create.
    Confirm existence and visibility from the terminal, and say which account
    the user has to be signed in as to see it.
- **Work out what the app actually reads — don't trust a list, including this
  one.** Search the finished code for every environment variable it looks up. The
  build may well have introduced settings beyond the ones `.env.example` started
  with, and one that exists locally but was never set on the host is a failure
  that only shows up at runtime, usually as behaviour nobody can explain.
  Reconcile three things: what the code reads, what the local environment file
  defines, and what the host has.
  - **The accounts are environment variables too**, numbered slot by numbered
    slot, and they are the entire account setup. A follower whose slot never made
    it onto the host silently never trades, and nothing on the dashboard looks
    wrong.
  - **Report any mismatch before deploying** — a variable the code reads that
    nothing supplies, or one supplied that nothing reads.
  - **A local value that is still the example placeholder is UNSET, and
    copying it to the host is worse than leaving it out.** Anything that
    filters placeholders on the way through will drop such a variable silently,
    and the host then falls back to whatever default the code has — which for a
    session-signing key means a known, published one. Decide per variable:
    generate a real value for the host, or stop and say it must be filled in.
    Never let it pass unmentioned in either direction.
  - **Bring `.env.example` back in line** if the build added settings, so it
    still describes what this app needs. It's the only guide anyone else gets.
- **Set them from the terminal.** Use the host's CLI rather than making the user
  paste anything into a web form — fewer steps, and it keeps values out of a
  browser window.
  - The broker credentials already exist in the user's local environment file.
    Read them from there; don't ask them to type them again.
  - Settings that aren't secret still have to be set — just treat them normally
    rather than protecting them.
  - **Don't put secret values on screen** — not in output, not in a log, and not
    typed as literals into a command. Pass them by referencing the variables
    they're already stored in, so the command shows a name and the shell supplies
    the value. Confirm by naming which variables are set, never by showing what's
    in them.
- **Nothing persists on the host.** There is no database, and the filesystem is
  thrown away on every restart — so a redeploy resets the copier to a cold start
  and it forgets every copy it has already made. That is by design and the engine
  is built for it, but say it out loud: "I redeployed and the Copier page is
  empty" is otherwise alarming.
- **Secrets never get committed.** Config files may name these variables; they
  must never contain the values.
- **Explain each file you generated, in plain English**, at the end.

### Two hard stops before anything is pushed or deployed

This puts a **running trading process** on the internet, unattended, which is
hard to walk back. Both conditions must hold. If either fails, **STOP and tell
the user** — don't fix it and carry on.

1. **No secret in anything about to be tracked.** Confirm the ignore rules cover
   the environment file, and check the staged content for a real key, secret, or
   account value — not just the names. If one is there, stop; it has to be
   removed and rotated first. The repo being private is not a reason to relax
   here: git history is forever, the host can read the repo, and a repo that is
   private today can be made public by one click later.
2. **Every account this will trade is a paper account.** This deploy starts a
   process whose entire purpose is placing orders in several accounts at once,
   with nobody watching. If any connected account is a live-money account, stop.
   Repointing this build at live money is not a deploy-time decision and does not
   happen with this command.

**And the killswitch stays off through the deploy.** The worker's first act on a
newly deployed machine must not be to copy something. Deploy with copying
disabled, confirm both processes are up and the dashboard is reachable, and let
the user turn it on when they are ready to watch.

These gates are what make an unattended deploy safe to run. They are not
optional, and not removable later "to reduce friction".

### Verify the deployed thing actually works

A live URL is not a working product, and on this build a live URL proves even
less than usual — the dashboard can look perfect while the process that does the
work is not running at all. When it's up:

1. **Read the process list.** Exactly one web process, up.
2. **Read the logs.** The loop should be saying, every pass, that it ran — even
   if there was nothing to do. Silence is the failure symptom here.
3. Then **offer** to place one test trade on the master — ask first, exactly as
   the broker step does, and use a stock not used in an earlier test — and
   confirm it appears in every follower, on the deployed dashboard, from a
   browser rather than from a terminal.

---

## Getting it right

These are the things that bite a deploy, and none of them are visible from a
green build log.

- **A URL that answers is not a deploy that works.** The build succeeding, the
  app showing "up", and the dashboard loading all prove the *web* process is
  serving something. On this build that is the half that doesn't matter.
- **A dashboard that loads proves only that the pages work.** The loop lives in
  the same process, but it can still have failed to start while every page serves
  perfectly. Read the logs for a pass before believing it.
- **More than one web worker means more than one copier.** It is the one
  production-server default that silently doubles every trade, and it looks like
  a copy-engine bug for as long as it takes to find.
- **A variable that exists locally and not on the host fails at runtime, not at
  deploy.** It usually surfaces as behaviour nobody can explain rather than as an
  error, which is why the reconciliation above is worth doing properly.
- **The cheapest plan that keeps a process awake is the real price of this
  build.** Say the number out loud rather than letting the user discover it. A
  copier is one of the few small apps where the free tier genuinely cannot do the
  job, and being straight about that is worth more than the saving.
- **Deploying does not stop the copy loop the user already has running
  locally.** After a deploy there are two copiers watching one master, and if
  both have copying switched on they race for the same orders. The stamp keeps
  that from becoming duplicate trades, but relying on it to cover for a second
  process nobody meant to leave running is not a plan. Say which copiers are
  live and where, as part of handing back the URL.
- **`git push` to the host can fail on the network rather than on the code.**
  A "connection reset" that repeats identically, and reproduces with `curl`, is
  not a credential problem and not something a retry fixes — antivirus and
  corporate proxies commonly break HTTP/2 to specific hosts. Forcing HTTP/1.1
  for that remote is the fix; diagnose it before assuming the deploy itself is
  broken, and record the setting so the next push doesn't rediscover it.

# END

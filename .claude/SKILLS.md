# Skills Reference

9 slash-command skills ship with this project. Each one's full text is in its
own `SKILL.md` — the tables below are a one-line summary for navigation.

**The skills are the specification.** This project is built by giving short,
plain-English direction — usually just the slash command — and letting the skill
supply the requirements. There is no separate requirements document, and you are
not expected to paste one.

| Category | Skills |
|----------|--------|
| Session & machine setup | 3 |
| Building the app | 4 |
| Vendor tooling | 2 |

> **Order is not implied by this file.** These are grouped by what they do, not
> by when to run them. The build happens one piece at a time, and the person
> driving it says what comes next.

---

## Personal vs vendor — read this before editing any of them

| Kind | How to tell | Rule |
|------|-------------|------|
| **Personal** | a `> **Personal skill**` note directly under the heading | carries this project's spec; improving it is encouraged |
| **Vendor** | no such note (and usually a `LICENSE` file) | leave **byte-identical** — never add project details |

Vendor skills stay pristine so an upstream update drops in cleanly. When a step
needs a vendor skill *and* this project's details, the details live in a personal
companion skill and the two are invoked together — that's exactly how the
dashboard is built.

Don't infer the kind from anything else. In particular, **"it has a Local
adaptations section" is not the test** — that inference has already caused
personal skills to be mistaken for vendor. If a skill has no marker and no
LICENSE, say so rather than guessing.

---

## Session & machine setup

| Skill | Command | Kind | Description |
|-------|---------|------|-------------|
| **init** | `/skill-init` | personal | Load the context for this project at the start of a session — what's being built, how it gets built, which branch you're on, and the rules that apply. Switches to the build branch when needed. |
| **install** | `/skill-install` | personal | *"Some stranger from YouTube told me it was safe to install this stuff on my computer."* Reviews the `install/` bootstrap scripts for anything malicious, explains them in plain English, and only then runs them. Once per machine. |
| **end** | `/skill-end` | personal | Close a session cleanly — fold what was learned back into the responsible skill so the next build starts smarter. Also the skill to reach for the moment something goes wrong mid-build: teach the lesson, then rebuild. |

## Building the app

| Skill | Command | Kind | Description |
|-------|---------|------|-------------|
| **broker-api** | `/skill-broker-api` | personal | The broker module — places orders on Alpaca **paper** accounts and reads accounts, orders and positions back. Written for several accounts at once, which is the part that is easy to get wrong. |
| **copy-trading** | `/skill-copy-trading` | personal | The heart of it: the loop that watches one master account and mirrors its new trades into every follower, with per-follower sizing, a killswitch, and the two guarantees — nothing copied twice, nothing missed — held without a database. |
| **dashboard** | `/skill-dashboard` | personal | The read-only screens: above all the copier view, where one master trade is visibly landing in every follower. Invoke **together with** the design skill below. |
| **deploy-cloud** | `/skill-deploy-cloud` | personal | Getting it onto Heroku as one always-on process, and proving the copy loop is really running — not just that the pages load. |

## Vendor tooling

| Skill | Command | Kind | Description |
|-------|---------|------|-------------|
| **minimalist-ui** | `/minimalist-ui` | **vendor** | Visual direction, from the **taste-skill** suite: clean editorial interfaces — warm monochrome, typographic contrast, flat bento grids, no gradients or heavy shadows. Supplies the look while `skill-dashboard` supplies the brief. A different design skill from video 1's, on purpose: the build is the content, the look is the variety. |
| **creator** | `/skill-creator` | **vendor** | The tooling used to write and maintain the personal skills above. Not part of building this app. |

---

## Related

- `.env.example` — **the entire configuration.** This build has no database and
  no settings screen: the accounts, their aliases and sizing, and every switch
  are numbered slots in that file.
- `install/` — the bootstrap scripts `skill-install` reads before running. They
  install a comprehensive tool set, but every project asks for **only the tags it
  needs**; see that skill's "Local adaptations" section.
- Paper trading only. Nothing here should be pointed at a live-money account,
  and none of it is financial advice. That matters more here than in most
  builds: a copier is a machine for placing the same order in several accounts
  at once, unattended.

# END

#!/usr/bin/env bash
# ============================================================
#   > robotraderguy_        dev environment bootstrap (mac ONLY)
# ------------------------------------------------------------
#   Watch AI build real trading tools, end to end.
#   YouTube:  https://youtube.com/@robotraderguy
#   Platform: https://tnttrading.net
#   Hire me:  Upwork - link in any video description
# ============================================================
# WHAT THIS DOES: installs the tools used in the build videos
# (Git, GitHub CLI, VS Code, Python (Miniconda), Node.js, the
# deploy CLIs - Heroku, Fly.io, Google Cloud SDK, Railway
# - MongoDB Community + mongosh + Compass, three AI agent CLIs,
# and the clasp/Firebase/Linode platform CLIs) via Homebrew
# (installed first if missing) + npm + pip, from official
# taps/casks. Nothing else. Start the local DB with:
# brew services start mongodb-community
# Each item below has a one-line note on WHY it's installed.
#
# LINUX USERS: use bootstrap-linux.sh instead. (Verified on a
# blank Linux box: Homebrew's installer needs Git preinstalled
# and casks are mac-only - the two worlds don't merge cleanly.)
#
# DISCLAIMER: provided as-is, no warranty. Review before running
# (it's short and readable on purpose). Installs may prompt for
# your password. Educational use; you are responsible for
# software installed on your machine.
#
# Run this file directly, OR install an AI coding agent first
# (Claude Code / Codex / Gemini) and let IT run the file - the
# installer sets up all three, so you're covered whichever agent you
# use. The videos are built with Claude Code.
#
# Lean install (only some tools, or all-but-some):
#   ./bootstrap.sh --only=git,gh,python      # ONLY these tags
#   ./bootstrap.sh --skip=mongo,compass      # everything EXCEPT these
# Tags: git gh vscode python node heroku fly gcloud railway
#   mongo compass aws az doctl claude codex gemini clasp firebase
#   linode extensions deps  (see the manifest below).

echo "        o"
echo "        |"
echo "  .----------."
echo "  | [/\/\->] |"
echo "  |   . : I  |"
echo "  '----------'"
echo "  > robotraderguy_  dev environment bootstrap"
echo "  youtube.com/@robotraderguy | tnttrading.net"
echo ""

# Wrong-OS guard: this is the macOS installer. Abort (with directions) if it's
# run anywhere else, so nothing half-installs on the wrong platform.
if [ "$(uname)" != "Darwin" ]; then
    echo "[ABORT] This is the macOS installer, but this isn't macOS."
    echo "        On Linux run  bootstrap-linux.sh   |  On Windows run  bootstrap.bat"
    exit 1
fi

echo "  Heads up: the FULL manifest is roughly 5 GB of disk (the Google Cloud SDK,"
echo "  Azure CLI, MongoDB and VS Code are the biggest). You almost certainly do NOT"
echo "  want all of it - a project only needs a few of these, so pass --only=... with"
echo "  the tags for the build you're doing."
echo ""
echo "  Rough timings on a normal broadband connection:"
echo "    - everything, from nothing installed .... 25-45 min"
echo "    - everything, already installed ......... 2-5 min (just version checks)"
echo "    - a typical --only set for one project .. 3-8 min"
echo ""
echo "  Safe to re-run: anything already present is detected, and upgraded if it's"
echo "  an old version rather than skipped."
echo ""
echo "  [!] EXPECT A PASSWORD PROMPT. Homebrew and some installers ask for your"
echo "      Mac login password, RIGHT HERE in this window - it is not a popup and"
echo "      nothing is typed as you type it. That is normal; these are the official"
echo "      installers you just reviewed."
echo ""
echo "      Installing STOPS until you type it and press Enter. If this looks"
echo "      frozen, it is almost certainly waiting on that prompt."
echo ""

# --only / --skip tag gating. Lets a viewer (or Claude) install a lean subset for
# one build instead of the whole ~5 GB set. --only wins if both are given.
# Accepts --only=a,b,c  OR  --only a,b,c  (same for --skip).
ONLY=""
SKIP=""
while [ $# -gt 0 ]; do
    case "$1" in
        --only=*) ONLY="${1#--only=}" ;;
        --skip=*) SKIP="${1#--skip=}" ;;
        --only)   shift; ONLY="$1" ;;
        --skip)   shift; SKIP="$1" ;;
    esac
    shift
done
ONLY="$(echo "$ONLY" | tr ' ' ',')"
SKIP="$(echo "$SKIP" | tr ' ' ',')"
[ -n "$ONLY" ] && { echo "  [only] installing: $ONLY"; echo ""; }
[ -z "$ONLY" ] && [ -n "$SKIP" ] && { echo "  [skip] leaving out: $SKIP"; echo ""; }

want() {
    tag="$1"
    if [ -n "$ONLY" ]; then
        case ",$ONLY," in *",$tag,"*) return 0 ;; *) return 1 ;; esac
    fi
    if [ -n "$SKIP" ]; then
        case ",$SKIP," in *",$tag,"*) return 1 ;; *) return 0 ;; esac
    fi
    return 0
}

# Free-disk-space check - WARN (never abort). The full set is ~5 GB; under ~7 GB
# free is tight once installers unpack, so point at --only for a lean install.
FREE_GB="$(df -g / 2>/dev/null | awk 'NR==2 {print $4}')"
if [ -n "$FREE_GB" ] && [ "$FREE_GB" -lt 7 ] 2>/dev/null; then
    echo "  [WARN] Only ~${FREE_GB} GB free on / - the full manifest is ~5 GB and needs headroom to unpack."
    echo "         Free up space, or install just what one build needs, e.g.  ./bootstrap.sh --only=git,gh,python,node"
    echo ""
fi

FAILED=""

#  Each install is INDEPENDENT: the WHY prints as it starts, and a failure is
#  recorded + skipped so the rest keep going (one broken item never aborts) - and
#  a failed item prints the URL to download it by hand. --only/--skip gate by tag.
#  Args: tag, label, why, url, cmd...
#  brew_get - install if missing, UPGRADE if already present.
#  `brew install X` on something you already have just says "already installed"
#  and leaves an old version in place, which fails later in confusing ways.
brew_get() {
    if brew install "$@"; then
        brew upgrade "$@" 2>/dev/null || true
        return 0
    fi
    brew upgrade "$@" 2>/dev/null || return 1
}

#  brew_tap_get - tap (and trust) a third-party tap, then brew_get from it.
#  Runs in THIS shell: a child `bash -c` would not have brew_get defined.
brew_tap_get() {
    tap="$1"; shift
    brew tap "$tap" || return 1
    brew trust "$tap" 2>/dev/null || true
    brew_get "$@"
}

try_install() {
    tag="$1"; label="$2"; why="$3"; url="$4"
    shift 4
    want "$tag" || return 0
    echo ""
    echo "==> $label"
    [ -n "$why" ] && echo "    ($why)"
    if ! "$@"; then
        echo "  [ERROR] $label failed - skipping; the rest will still install."
        [ -n "$url" ] && echo "          install it by hand: $url"
        FAILED="$FAILED $label"
    fi
}

if ! command -v brew >/dev/null 2>&1; then
    echo "==> Installing Homebrew"
    if ! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        echo "  [ERROR] Homebrew install failed - everything below needs it. Fix and rerun."
        exit 1
    fi
fi

try_install "git" "Git" "version control - every project is a git repo, and 'gh' needs it" "https://git-scm.com/downloads" \
    brew_get git
try_install "gh" "GitHub CLI" "create and clone your repos from the terminal, no website" "https://cli.github.com" \
    brew_get gh
try_install "node" "Node.js" "a few tools run on it - including the Railway CLI below" "https://nodejs.org/en/download" \
    brew_get node
try_install "vscode" "VS Code" "the editor you read the AI-written code in (Claude installs it)" "https://code.visualstudio.com/download" \
    brew_get --cask visual-studio-code
try_install "python" "Python (Miniconda)" "the language the bots run on - a small Python whose pip installs cleanly on macOS" "https://docs.conda.io/en/latest/miniconda.html" \
    brew_get --cask miniconda
#  NOTE: newer Homebrew refuses third-party taps unless trusted ("Refusing to load
#  formula ... from untrusted tap") - so `brew trust <tap>` after tapping heroku/brew
#  and mongodb/brew below. `|| true` keeps it working on OLDER brew that has no
#  `brew trust` command and doesn't require trust. (Caught by the CI mac runner.)
try_install "heroku" "Heroku CLI" "deploy a bot to the cloud so it runs 24/7 without your Mac on" "https://devcenter.heroku.com/articles/heroku-cli" \
    brew_tap_get heroku/brew heroku
try_install "fly" "Fly.io CLI" "an alternative cloud host used in some builds" "https://fly.io/docs/flyctl/install/" \
    brew_get flyctl
try_install "gcloud" "Google Cloud SDK" "the gcloud CLI - deploy and manage Google Cloud (large SDK)" "https://cloud.google.com/sdk/docs/install" \
    brew_get --cask google-cloud-sdk
#  Other cloud CLIs (aws / az / doctl). Tag-gated like everything else, so they
#  only install when asked for - the lean --only set never pulls them in:
try_install "aws" "AWS CLI" "the aws CLI - deploy and manage AWS" "https://aws.amazon.com/cli/" \
    brew_get awscli
try_install "az" "Azure CLI" "the az CLI - deploy and manage Azure" "https://learn.microsoft.com/cli/azure/install-azure-cli" \
    brew_get azure-cli
try_install "doctl" "DigitalOcean CLI" "the doctl CLI - deploy and manage DigitalOcean" "https://docs.digitalocean.com/reference/doctl/how-to/install/" \
    brew_get doctl
try_install "railway" "Railway CLI" "another cloud host - installs via npm (Node above)" "https://docs.railway.com/guides/cli" \
    npm install -g @railway/cli
try_install "mongo" "MongoDB (local)" "the database the bots use - fast offline dev (Atlas in the cloud when deployed)" "https://www.mongodb.com/try/download/community" \
    brew_tap_get mongodb/brew mongodb-community mongosh
#  MongoDB Compass - OPT-IN (not default): VS Code's MongoDB extension (installed
#  below) already browses the DB, so Compass is redundant for most viewers.
#  Uncomment to include it (installs into /Applications; use --only=compass for just it):
# try_install "compass" "MongoDB Compass" "a point-and-click MongoDB browser, if you'd rather not type" "https://www.mongodb.com/try/download/compass" \
#     brew install --cask mongodb-compass

echo ""
echo "== AI coding agents (the videos use Claude Code; the others let you follow along in your own agent) =="
#  All three are npm-global (Node above). Claude Code is what the videos + skills
#  are tuned to; Codex/Gemini are here so non-Claude viewers aren't gatekept.
try_install "claude" "Claude Code CLI" "the AI agent the videos are built with (skills are tuned to it)" "https://docs.claude.com/en/docs/claude-code/overview" \
    npm install -g @anthropic-ai/claude-code
try_install "codex" "OpenAI Codex CLI" "OpenAI's coding agent - if you prefer Codex" "https://github.com/openai/codex" \
    npm install -g @openai/codex
try_install "gemini" "Gemini CLI" "Google's coding agent - if you prefer Gemini" "https://github.com/google-gemini/gemini-cli" \
    npm install -g @google/gemini-cli
#  Grok - xAI ships no official first-party agent CLI yet; nothing to install.

echo ""
echo "== Platform CLIs (Apps Script, Firebase, Linode) =="
#  clasp + Firebase are npm-global (Node above); Linode is a pip tool (Python above).
try_install "clasp" "clasp (Apps Script)" "develop Google Apps Script locally and push it" "https://github.com/google/clasp" \
    npm install -g @google/clasp
try_install "firebase" "Firebase CLI" "manage and deploy Firebase projects" "https://firebase.google.com/docs/cli" \
    npm install -g firebase-tools
try_install "linode" "Linode CLI" "manage Linode/Akamai cloud infrastructure" "https://techdocs.akamai.com/cloud-computing/docs/cli" \
    pip install linode-cli

if want extensions; then
    echo ""
    echo "== VS Code extensions =="
    if command -v code >/dev/null 2>&1; then
        code --install-extension ms-python.python || echo "  [WARN] failed: ms-python.python"
        code --install-extension anthropic.claude-code || echo "  [WARN] failed: anthropic.claude-code"
        code --install-extension mechatroner.rainbow-csv || echo "  [WARN] failed: mechatroner.rainbow-csv"
        code --install-extension cweijan.vscode-office || echo "  [WARN] failed: cweijan.vscode-office"
        code --install-extension qwtel.sqlite-viewer || echo "  [WARN] failed: qwtel.sqlite-viewer"
        code --install-extension mongodb.mongodb-vscode || echo "  [WARN] failed: mongodb.mongodb-vscode"
    else
        echo "  [NOTE] open a new terminal and rerun to add extensions automatically"
    fi
fi

if want deps; then
    echo ""
    echo "== Project dependencies =="
    #  Repo-agnostic by design (runs before any repo exists) — but when run
    #  FROM a cloned project, install its Python deps too.
    if [ -f requirements.txt ]; then
        echo "  requirements.txt found - installing project dependencies"
        pip install -r requirements.txt || echo "  [WARN] pip install failed - open a new terminal and run: pip install -r requirements.txt"
    else
        echo "  no requirements.txt here - skip (per-project deps install when you clone a build repo)"
    fi
fi

echo ""
echo "== Verify (open a new terminal if a tool is not found) =="
for cmd in "git --version" "gh --version" "code --version" "conda --version" "node --version" "heroku --version" "flyctl version" "gcloud --version" "railway --version" "mongosh --version"; do
    echo ">> $cmd"
    $cmd 2>/dev/null || echo "   [not on PATH yet]"
done

echo ""
if [ -n "$FAILED" ]; then
    echo "[SUMMARY] FAILED installs:$FAILED - rerun or install manually."
else
    echo "[SUMMARY] All installs succeeded."
fi
echo ""
echo "== Manual auth steps (one time) =="
echo "  git config --global user.name \"Your Name\"        # names your commits"
echo "  git config --global user.email \"you@example.com\"  # git wont commit without these"
echo "  gh auth login --hostname github.com --git-protocol https --web   # GitHub (also lets git push)"

echo "  heroku login        # Heroku"
echo "                      # 2FA may require the SALESFORCE AUTHENTICATOR app"
echo "                      # on your phone (Salesforce owns Heroku) - install it first"

echo ""
echo "== About your new apps =="
echo "  Almost everything here is COMMAND-LINE - it lives in your Terminal, not on"
echo "  your desktop. The only app with a window is VS Code (your code editor); it's"
echo "  in your Applications folder / Launchpad. Nothing gets put on your desktop."

[ -z "$FAILED" ] || exit 1

# END

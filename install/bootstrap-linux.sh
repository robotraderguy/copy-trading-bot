#!/usr/bin/env bash
# ============================================================
#   > robotraderguy_        dev environment bootstrap (linux)
# ------------------------------------------------------------
#   Watch AI build real trading tools, end to end.
#   YouTube:  https://youtube.com/@robotraderguy
#   Platform: https://tnttrading.net
#   Hire me:  Upwork - link in any video description
# ============================================================
# WHAT THIS DOES: installs the tools used in the build videos
# (Git, GitHub CLI, VS Code, Python (Miniconda), Node.js, the
# deploy CLIs - Heroku, Fly.io, Google Cloud SDK, Railway -
# MongoDB Community + mongosh, three AI agent CLIs, and the
# clasp/Firebase/Linode platform CLIs) on Debian/Ubuntu via apt
# + the tools' OFFICIAL vendor repos/installers + npm + pip.
# Nothing else. (mac users: bootstrap.sh, which uses Homebrew -
# the two package worlds don't merge.)
# Each item below has a one-line note on WHY it's installed.
#
# DISCLAIMER: provided as-is, no warranty. Review before running
# (it's short and readable on purpose). Uses sudo - it will
# prompt for your password. Educational use; you are responsible
# for software installed on your machine.
#
# Run this file directly, OR install an AI coding agent first
# (Claude Code / Codex / Gemini) and let IT run the file - the
# installer sets up all three, so you're covered whichever agent you
# use. The videos are built with Claude Code.
#
# Lean install (only some tools, or all-but-some):
#   ./bootstrap-linux.sh --only=git,gh,python   # ONLY these tags
#   ./bootstrap-linux.sh --skip=mongo           # everything EXCEPT these
# Tags: git gh vscode python node heroku mongo fly gcloud railway
#   aws az doctl claude codex gemini clasp firebase linode extensions deps
#   (the apt refresh + curl/gpg base always run). See the manifest below.

echo "        o"
echo "        |"
echo "  .----------."
echo "  | [/\/\->] |"
echo "  |   . : I  |"
echo "  '----------'"
echo "  > robotraderguy_  dev environment bootstrap (linux)"
echo "  youtube.com/@robotraderguy | tnttrading.net"
echo ""

# Wrong-OS guard: this is the Linux (Debian/Ubuntu) installer. Abort with
# directions if run elsewhere, so nothing half-installs on the wrong platform.
if [ "$(uname)" != "Linux" ]; then
    echo "[ABORT] This is the Linux installer, but this isn't Linux."
    echo "        On macOS run  bootstrap.sh   |  On Windows run  bootstrap.bat"
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
echo "  [!] EXPECT A PASSWORD PROMPT. apt and the vendor installers need sudo, so"
echo "      you will be asked for your login password RIGHT HERE in this window -"
echo "      nothing is shown as you type it. That is normal; these are the official"
echo "      installers you just reviewed."
echo ""
echo "      Installing STOPS until you type it and press Enter. If this looks"
echo "      frozen, it is almost certainly waiting on that prompt."
echo ""

# --only / --skip tag gating. Lets a viewer (or Claude) install a lean subset for
# one build instead of the whole ~5 GB set. --only wins if both are given.
# Accepts --only=a,b,c  OR  --only a,b,c  (same for --skip). The apt refresh and
# curl/gpg base steps (tag "base") always run - later installs depend on them.
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
[ -n "$ONLY" ] && { echo "  [only] installing: $ONLY (plus the always-on apt base)"; echo ""; }
[ -z "$ONLY" ] && [ -n "$SKIP" ] && { echo "  [skip] leaving out: $SKIP"; echo ""; }

want() {
    tag="$1"
    [ "$tag" = "base" ] && return 0   # apt refresh + curl/gpg base always run
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
FREE_GB="$(df -BG / 2>/dev/null | awk 'NR==2 {gsub(/[Gg]/,"",$4); print $4}')"
if [ -n "$FREE_GB" ] && [ "$FREE_GB" -lt 7 ] 2>/dev/null; then
    echo "  [WARN] Only ~${FREE_GB} GB free on / - the full manifest is ~5 GB and needs headroom to unpack."
    echo "         Free up space, or install just what one build needs, e.g.  ./bootstrap-linux.sh --only=git,gh,python,node"
    echo ""
fi

FAILED=""

#  Each install is INDEPENDENT: the WHY prints as it starts, and a failure is
#  recorded + skipped so the rest keep going (one broken item never aborts) - and
#  a failed item prints the URL to download it by hand. --only/--skip gate by tag.
#  Args: tag, label, why, url, cmd...
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

export DEBIAN_FRONTEND=noninteractive

try_install "base" "apt refresh" "update the package lists before installing anything" "" \
    sudo apt-get update -y
try_install "git" "Git" "version control - every project is a git repo, and 'gh' needs it" "https://git-scm.com/downloads" \
    sudo apt-get install -y git
try_install "base" "curl/gpg base" "needed to add the official vendor package repos below" "" \
    sudo apt-get install -y curl ca-certificates gnupg

#  GitHub CLI - official apt repo
try_install "gh" "GitHub CLI" "create and clone your repos from the terminal, no website" "https://cli.github.com" bash -c '
    sudo mkdir -p /etc/apt/keyrings &&
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null &&
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null &&
    sudo apt-get update -y && sudo apt-get install -y gh'

#  Node.js - NodeSource LTS
try_install "node" "Node.js (LTS)" "a few tools run on it - including the Railway CLI below" "https://nodejs.org/en/download" bash -c '
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - &&
    sudo apt-get install -y nodejs'

#  VS Code - Microsoft apt repo (desktop Linux; harmless no-GUI otherwise)
try_install "vscode" "VS Code" "the editor you read the AI-written code in (Claude installs it)" "https://code.visualstudio.com/download" bash -c '
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/keyrings/microsoft.asc >/dev/null &&
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.asc] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null &&
    sudo apt-get update -y && sudo apt-get install -y code'

#  Miniconda - official installer (small Python; full Anaconda is overkill via CLI)
try_install "python" "Python (Miniconda)" "the language the bots run on - a small Python whose pip installs cleanly" "https://docs.conda.io/en/latest/miniconda.html" bash -c '
    curl -fsSL https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -o /tmp/miniconda.sh &&
    bash /tmp/miniconda.sh -b -p "$HOME/miniconda3" &&
    "$HOME/miniconda3/bin/conda" init bash'

#  Heroku CLI - official installer
try_install "heroku" "Heroku CLI" "deploy a bot to the cloud so it runs 24/7 without your PC on" "https://devcenter.heroku.com/articles/heroku-cli" bash -c 'curl -fsSL https://cli-assets.heroku.com/install.sh | sh'

#  MongoDB Community + mongosh - official MongoDB apt repo (local dev DB;
#  Atlas stays the deployed bot's database). 8.0 = current major; bump when
#  MongoDB ships a new series. Compass is desktop-GUI - skipped on servers.
try_install "mongo" "MongoDB (local)" "the database the bots use - fast offline dev (Atlas in the cloud when deployed)" "https://www.mongodb.com/try/download/community" bash -c '
    curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor --yes &&
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list >/dev/null &&
    sudo apt-get update -y && sudo apt-get install -y mongodb-org mongodb-mongosh'

#  Fly.io CLI - an alternative cloud host used in some builds (official installer).
try_install "fly" "Fly.io CLI" "an alternative cloud host used in some builds" "https://fly.io/docs/flyctl/install/" bash -c 'curl -fsSL https://fly.io/install.sh | sh'

#  Google Cloud SDK (gcloud) - official Google apt repo. Large SDK.
try_install "gcloud" "Google Cloud SDK" "the gcloud CLI - deploy and manage Google Cloud (large SDK)" "https://cloud.google.com/sdk/docs/install" bash -c '
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg -o /usr/share/keyrings/cloud.google.gpg --dearmor --yes &&
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null &&
    sudo apt-get update -y && sudo apt-get install -y google-cloud-cli'

#  Other cloud CLIs (aws / az / doctl). Tag-gated like everything else, so they
#  only install when asked for - the lean --only set never pulls them in:
try_install "aws" "AWS CLI" "the aws CLI - deploy and manage AWS" "https://aws.amazon.com/cli/" bash -c '
    sudo apt-get install -y unzip &&
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o /tmp/awscliv2.zip &&
    (cd /tmp && unzip -q -o awscliv2.zip && sudo ./aws/install --update)'
try_install "az" "Azure CLI" "the az CLI - deploy and manage Azure" "https://learn.microsoft.com/cli/azure/install-azure-cli" bash -c '
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash'
try_install "doctl" "DigitalOcean CLI" "the doctl CLI - deploy and manage DigitalOcean" "https://docs.digitalocean.com/reference/doctl/how-to/install/" bash -c '
    DO_VER="$(curl -fsSL https://api.github.com/repos/digitalocean/doctl/releases/latest | grep -oP "\"tag_name\": \"v\K[^\"]+")" &&
    curl -fsSL "https://github.com/digitalocean/doctl/releases/download/v${DO_VER}/doctl-${DO_VER}-linux-amd64.tar.gz" -o /tmp/doctl.tar.gz &&
    tar -xzf /tmp/doctl.tar.gz -C /tmp && sudo mv /tmp/doctl /usr/local/bin/'

#  Railway CLI - another cloud host; ships via npm (Node above).
try_install "railway" "Railway CLI" "another cloud host - installs via npm (Node above)" "https://docs.railway.com/guides/cli" bash -c 'sudo npm install -g @railway/cli'

echo ""
echo "== AI coding agents (the videos use Claude Code; the others let you follow along in your own agent) =="
#  All three are npm-global (Node above). Claude Code is what the videos + skills
#  are tuned to; Codex/Gemini are here so non-Claude viewers aren't gatekept.
#  NOTE: on Linux, NodeSource installs npm's global prefix under root-owned
#  /usr/lib/node_modules, so every `npm install -g` here needs sudo (a plain
#  non-root install fails EACCES - caught by the clean-install test). Do NOT drop
#  the sudo. (mac/Windows npm -g write to a user-owned prefix, so those don't.)
try_install "claude" "Claude Code CLI" "the AI agent the videos are built with (skills are tuned to it)" "https://docs.claude.com/en/docs/claude-code/overview" \
    bash -c 'sudo npm install -g @anthropic-ai/claude-code'
try_install "codex" "OpenAI Codex CLI" "OpenAI's coding agent - if you prefer Codex" "https://github.com/openai/codex" \
    bash -c 'sudo npm install -g @openai/codex'
try_install "gemini" "Gemini CLI" "Google's coding agent - if you prefer Gemini" "https://github.com/google-gemini/gemini-cli" \
    bash -c 'sudo npm install -g @google/gemini-cli'
#  Grok - xAI ships no official first-party agent CLI yet; nothing to install.

echo ""
echo "== Platform CLIs (Apps Script, Firebase, Linode) =="
#  clasp + Firebase are npm-global (Node above); Linode is a pip tool (Miniconda above).
try_install "clasp" "clasp (Apps Script)" "develop Google Apps Script locally and push it" "https://github.com/google/clasp" \
    bash -c 'sudo npm install -g @google/clasp'
try_install "firebase" "Firebase CLI" "manage and deploy Firebase projects" "https://firebase.google.com/docs/cli" \
    bash -c 'sudo npm install -g firebase-tools'
try_install "linode" "Linode CLI" "manage Linode/Akamai cloud infrastructure" "https://techdocs.akamai.com/cloud-computing/docs/cli" \
    bash -c '"$HOME/miniconda3/bin/pip" install linode-cli'

if want extensions; then
    echo ""
    echo "== VS Code extensions (needs a desktop session; warns harmlessly on servers) =="
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
    #  FROM a cloned project, install its Python deps too (miniconda's pip).
    if [ -f requirements.txt ]; then
        echo "  requirements.txt found - installing project dependencies"
        "$HOME/miniconda3/bin/pip" install -r requirements.txt || echo "  [WARN] pip install failed - open a new terminal and run: pip install -r requirements.txt"
    else
        echo "  no requirements.txt here - skip (per-project deps install when you clone a build repo)"
    fi
fi

echo ""
echo "== Verify (open a new terminal if a tool is not found) =="
for cmd in "git --version" "gh --version" "code --version" "$HOME/miniconda3/bin/conda --version" "node --version" "heroku --version" "flyctl version" "gcloud --version" "railway --version" "mongosh --version"; do
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
echo "  Almost everything here is COMMAND-LINE - it lives in your terminal, not on"
echo "  your desktop. The only app with a window is VS Code (your code editor); it's"
echo "  in your applications menu. Nothing gets put on your desktop."

[ -z "$FAILED" ] || exit 1

# END

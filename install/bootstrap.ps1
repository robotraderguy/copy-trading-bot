# ============================================================
#   > robotraderguy_           dev environment bootstrap (PS)
# ------------------------------------------------------------
#   Watch AI build real trading tools, end to end.
#   YouTube:  https://youtube.com/@robotraderguy
#   Platform: https://tnttrading.net
#   Hire me:  Upwork - link in any video description
# ============================================================
# WHAT THIS DOES: installs the tools used in the build videos
# (Git, GitHub CLI, VS Code, Python, Node.js, the deploy CLIs -
# Heroku, Fly.io, Google Cloud SDK, Railway - MongoDB Community
# Server + mongosh + Compass, three AI agent CLIs, and the
# clasp/Firebase/Linode platform CLIs) from OFFICIAL sources via
# winget/npm/pip. Nothing else. Each item below has a one-line
# note on WHY it's installed. (Local MongoDB = fast offline dev
# loop; Atlas stays the cloud database the deployed bot uses.)
#
# DISCLAIMER: provided as-is, no warranty. Review before running
# (it's short and readable on purpose). Some installs may prompt
# for admin approval. Educational use; you are responsible for
# software installed on your machine.
#
# Run:  Set-ExecutionPolicy -Scope Process Bypass; .\bootstrap.ps1
# (or just double-click bootstrap.bat - same manifest, no policy step)
#
# Lean install (only some tools, or all-but-some):
#   .\bootstrap.ps1 -Only git,gh,python      # ONLY these tags
#   .\bootstrap.ps1 -Skip mongo,compass      # everything EXCEPT these
# Tags: git gh vscode python node heroku fly gcloud mongo mongosh
#   compass railway aws az doctl claude codex gemini clasp firebase
#   linode extensions deps  (see the manifest below).

param(
    [string]$Only = "",
    [string]$Skip = ""
)

Write-Host '        o' -ForegroundColor Cyan
Write-Host '        |' -ForegroundColor Cyan
Write-Host '  .----------.' -ForegroundColor Cyan
Write-Host '  | [/\/\->] |' -ForegroundColor Cyan
Write-Host '  |   . : I  |' -ForegroundColor Cyan
Write-Host "  '----------'" -ForegroundColor Cyan
Write-Host "  > robotraderguy_  dev environment bootstrap" -ForegroundColor Cyan
Write-Host "  youtube.com/@robotraderguy | tnttrading.net" -ForegroundColor DarkCyan
Write-Host ""

# Wrong-OS guard: this is the WINDOWS installer. Abort (with directions) if it's
# somehow being run on macOS/Linux via PowerShell Core, so nothing half-installs.
if ($env:OS -ne 'Windows_NT') {
    Write-Host "[ABORT] This is the Windows installer, but this isn't Windows." -ForegroundColor Red
    Write-Host "        On macOS run  bootstrap.sh   |  On Linux run  bootstrap-linux.sh" -ForegroundColor Yellow
    exit 1
}

Write-Host "  Heads up: the FULL manifest is roughly 5 GB of disk (the Google Cloud SDK," -ForegroundColor DarkGray
Write-Host "  Azure CLI, MongoDB and VS Code are the biggest). You almost certainly do NOT" -ForegroundColor DarkGray
Write-Host "  want all of it - a project only needs a few of these, so pass -Only with the" -ForegroundColor DarkGray
Write-Host "  tags for the build you're doing." -ForegroundColor DarkGray
Write-Host "" 
Write-Host "  Rough timings on a normal broadband connection:" -ForegroundColor DarkGray
Write-Host "    - everything, from nothing installed .... 25-45 min" -ForegroundColor DarkGray
Write-Host "    - everything, already installed ......... 2-5 min (just version checks)" -ForegroundColor DarkGray
Write-Host "    - a typical -Only set for one project ... 3-8 min" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Safe to re-run: anything already present is detected, and upgraded if it's" -ForegroundColor DarkGray
Write-Host "  an old version rather than skipped." -ForegroundColor DarkGray
Write-Host ""
Write-Host "  [!] EXPECT PERMISSION POPUPS. Windows will ask 'Do you want to allow this" -ForegroundColor Yellow
Write-Host "      app to make changes to your device?' for several of these installers" -ForegroundColor Yellow
Write-Host "      (Git, Node, VS Code, MongoDB and others). That is normal - they are the" -ForegroundColor Yellow
Write-Host "      official installers you just reviewed. Click YES each time, or the tool" -ForegroundColor Yellow
Write-Host "      it is asking about will not install." -ForegroundColor Yellow
Write-Host ""
Write-Host "      The window can open BEHIND this one, and installing pauses until you" -ForegroundColor Yellow
Write-Host "      answer. If this looks frozen, check your taskbar for a prompt waiting." -ForegroundColor Yellow
Write-Host ""

# --only / --skip tag gating. Lets a viewer (or Claude) install a lean subset for
# one build instead of the whole ~5 GB set. -Only wins if both are given.
$OnlyTags = @($Only -split '[,\s]+' | Where-Object { $_ })
$SkipTags = @($Skip -split '[,\s]+' | Where-Object { $_ })
function Want([string]$tag) {
    if ($OnlyTags.Count -gt 0) { return ($OnlyTags -contains $tag) }
    if ($SkipTags -contains $tag) { return $false }
    return $true
}
if ($OnlyTags.Count -gt 0) { Write-Host "  [only] installing: $($OnlyTags -join ', ')" -ForegroundColor DarkCyan; Write-Host "" }
elseif ($SkipTags.Count -gt 0) { Write-Host "  [skip] leaving out: $($SkipTags -join ', ')" -ForegroundColor DarkCyan; Write-Host "" }

# Free-disk-space check - WARN (never abort). The full set is ~5 GB; under ~7 GB
# free is tight once installers unpack, so point at -Only for a lean install.
try {
    $freeGB = [math]::Floor((Get-PSDrive C -ErrorAction Stop).Free / 1GB)
    if ($freeGB -lt 7) {
        Write-Host "  [WARN] Only ~$freeGB GB free on C: - the full manifest is ~5 GB and needs headroom to unpack." -ForegroundColor Yellow
        Write-Host "         Free up space, or install just what one build needs, e.g.  .\bootstrap.ps1 -Only git,gh,python,node" -ForegroundColor Yellow
        Write-Host ""
    }
} catch { }

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] winget not found. Install 'App Installer' from the Microsoft Store, then rerun." -ForegroundColor Red
    exit 1
}

# Each item is INDEPENDENT: the Why prints as it starts, a failure is recorded +
# skipped so the rest keep going, and a failed item prints its manual-download Url.
# Tag = the --only/--skip handle for that item.
$tools = @(
    @{ Tag = "git";      Name = "Git";              Id = "Git.Git";                    Why = "version control - every project is a git repo, and gh needs it";     Url = "https://git-scm.com/downloads" },
    @{ Tag = "gh";       Name = "GitHub CLI";       Id = "GitHub.cli";                 Why = "create and clone your repos from the terminal, no website";          Url = "https://cli.github.com" },
    @{ Tag = "vscode";   Name = "VS Code";          Id = "Microsoft.VisualStudioCode"; Why = "the editor you read the AI-written code in - Claude installs it";     Url = "https://code.visualstudio.com/download" },
    @{ Tag = "python";   Name = "Python 3.13";      Id = "Python.Python.3.13";         Why = "the language the bots run on - plain Python from python.org; Anaconda is the manual fallback (README)"; Url = "https://www.python.org/downloads/" },
    @{ Tag = "node";     Name = "Node.js LTS";      Id = "OpenJS.NodeJS.LTS";          Why = "a few tools run on it - including the Railway CLI below";            Url = "https://nodejs.org/en/download" },
    @{ Tag = "heroku";   Name = "Heroku CLI";       Id = "Heroku.HerokuCLI";           Why = "deploy a bot to the cloud so it runs 24/7 without your PC on";       Url = "https://devcenter.heroku.com/articles/heroku-cli" },
    @{ Tag = "fly";      Name = "Fly.io CLI";       Id = "Fly-io.flyctl";              Why = "an alternative cloud host used in some builds";                     Url = "https://fly.io/docs/flyctl/install/" },
    @{ Tag = "gcloud";   Name = "Google Cloud SDK"; Id = "Google.CloudSDK";            Why = "the gcloud CLI - deploy and manage Google Cloud (large SDK)";        Url = "https://cloud.google.com/sdk/docs/install" },
    # Other cloud CLIs (aws / az / doctl). Tag-gated like everything else, so they
    # only install when asked for - the lean --only set never pulls them in:
    @{ Tag = "aws";      Name = "AWS CLI";          Id = "Amazon.AWSCLI";              Why = "the aws CLI - deploy and manage AWS";                               Url = "https://aws.amazon.com/cli/" },
    @{ Tag = "az";       Name = "Azure CLI";        Id = "Microsoft.AzureCLI";         Why = "the az CLI - deploy and manage Azure";                              Url = "https://learn.microsoft.com/cli/azure/install-azure-cli" },
    @{ Tag = "doctl";    Name = "DigitalOcean CLI"; Id = "DigitalOcean.Doctl";         Why = "the doctl CLI - deploy and manage DigitalOcean";                    Url = "https://docs.digitalocean.com/reference/doctl/how-to/install/" },
    # MongoDB Server: Custom makes the MSI SKIP its bundled Compass (else it drops a
    # desktop icon + auto-opens). SHOULD_INSTALL_COMPASS=0 is the official MSI flag.
    @{ Tag = "mongo";    Name = "MongoDB Server";   Id = "MongoDB.Server";             Why = "the database the bots use - fast offline dev; Atlas when deployed"; Url = "https://www.mongodb.com/try/download/community"; Custom = @('--custom','SHOULD_INSTALL_COMPASS=0') },
    @{ Tag = "mongosh";  Name = "MongoDB Shell";    Id = "MongoDB.Shell";              Why = "MongoDB's command-line shell, for peeking at the data";             Url = "https://www.mongodb.com/try/download/shell" }
    # MongoDB Compass - OPT-IN (not default): the one tool that makes a desktop icon,
    # and VS Code's MongoDB extension (installed below) already browses the DB.
    # Uncomment to include it (then it installs, or use -Only compass for just it):
    # @{ Tag = "compass";  Name = "MongoDB Compass";  Id = "MongoDB.Compass.Full";       Why = "a point-and-click MongoDB browser, if you'd rather not type";        Url = "https://www.mongodb.com/try/download/compass" }
)
$failed = @()

foreach ($tool in $tools) {
    if (-not (Want $tool.Tag)) { continue }
    Write-Host ""
    Write-Host "==> $($tool.Name)" -ForegroundColor Cyan
    if ($tool.Why) { Write-Host "    ($($tool.Why))" }
    $extra = @(); if ($tool.Custom) { $extra = $tool.Custom }
    winget install --id $tool.Id --silent --accept-package-agreements --accept-source-agreements @extra
    if ($LASTEXITCODE -eq -1978335189) {
        # Already present - but possibly a STALE version from an older install,
        # which fails later in confusing ways. Presence is not enough; upgrade it.
        winget upgrade --id $tool.Id --silent --accept-package-agreements --accept-source-agreements @extra 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] already installed - upgraded to the latest" -ForegroundColor Green
        } else {
            Write-Host "  [OK] already installed and up to date" -ForegroundColor Green
        }
    } elseif ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERROR] $($tool.Name) failed - skipping; the rest still install." -ForegroundColor Red
        if ($tool.Url) { Write-Host "          install it by hand: $($tool.Url)" -ForegroundColor Yellow }
        $failed += $tool.Name
    }
}

# Railway CLI - deploy bots on Railway. Ships via npm (Node above), not winget.
if (Want "railway") {
    Write-Host ""
    Write-Host "==> Railway CLI" -ForegroundColor Cyan
    Write-Host "    (another cloud host - installs via npm, Node above)"
    if (-not (Get-Command railway -ErrorAction SilentlyContinue)) {
        npm install -g '@railway/cli'
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  [ERROR] Railway CLI failed - skipping; the rest still install." -ForegroundColor Red
            Write-Host "          install it by hand: https://docs.railway.com/guides/cli" -ForegroundColor Yellow
            $failed += "Railway"
        }
    } else {
        Write-Host "  [OK] already installed" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "== AI coding agents (videos use Claude Code; others let you follow along in your own agent) ==" -ForegroundColor Cyan
# All npm-global (Node above). Claude Code is what the videos + skills are tuned
# to; Codex/Gemini are here so non-Claude viewers aren't gatekept.
$agents = @(
    @{ Tag = "claude"; Name = "Claude Code CLI"; Pkg = "@anthropic-ai/claude-code"; Why = "the AI agent the videos are built with (skills are tuned to it)"; Url = "https://docs.claude.com/en/docs/claude-code/overview" },
    @{ Tag = "codex";  Name = "OpenAI Codex CLI"; Pkg = "@openai/codex";           Why = "OpenAI's coding agent - if you prefer Codex";                    Url = "https://github.com/openai/codex" },
    @{ Tag = "gemini"; Name = "Gemini CLI";       Pkg = "@google/gemini-cli";       Why = "Google's coding agent - if you prefer Gemini";                   Url = "https://github.com/google-gemini/gemini-cli" }
)
foreach ($a in $agents) {
    if (-not (Want $a.Tag)) { continue }
    Write-Host ""
    Write-Host "==> $($a.Name)" -ForegroundColor Cyan
    Write-Host "    ($($a.Why))"
    npm install -g $a.Pkg
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERROR] $($a.Name) failed - skipping; the rest still install." -ForegroundColor Red
        Write-Host "          install it by hand: $($a.Url)" -ForegroundColor Yellow
        $failed += $a.Name
    }
}
# Grok - xAI ships no official first-party agent CLI yet; nothing to install.

Write-Host ""
Write-Host "== Platform CLIs (Apps Script, Firebase, Linode) ==" -ForegroundColor Cyan
# clasp + Firebase are npm-global (Node above); Linode is a pip tool (Python above).
$platformNpm = @(
    @{ Tag = "clasp";    Name = "clasp (Apps Script)"; Pkg = "@google/clasp"; Why = "develop Google Apps Script locally and push it"; Url = "https://github.com/google/clasp" },
    @{ Tag = "firebase"; Name = "Firebase CLI";        Pkg = "firebase-tools"; Why = "manage and deploy Firebase projects";           Url = "https://firebase.google.com/docs/cli" }
)
foreach ($p in $platformNpm) {
    if (-not (Want $p.Tag)) { continue }
    Write-Host ""
    Write-Host "==> $($p.Name)" -ForegroundColor Cyan
    Write-Host "    ($($p.Why))"
    npm install -g $p.Pkg
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERROR] $($p.Name) failed - skipping; the rest still install." -ForegroundColor Red
        Write-Host "          install it by hand: $($p.Url)" -ForegroundColor Yellow
        $failed += $p.Name
    }
}
if (Want "linode") {
    Write-Host ""
    Write-Host "==> Linode CLI" -ForegroundColor Cyan
    Write-Host "    (manage Linode/Akamai cloud infrastructure)"
    python -m pip install linode-cli
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERROR] Linode CLI failed - skipping; the rest still install." -ForegroundColor Red
        Write-Host "          install it by hand: https://techdocs.akamai.com/cloud-computing/docs/cli" -ForegroundColor Yellow
        $failed += "Linode"
    }
}

if (Want "extensions") {
    Write-Host ""
    Write-Host "== VS Code extensions ==" -ForegroundColor Cyan
    $extensions = @(
        "ms-python.python",
        "anthropic.claude-code",
        "mechatroner.rainbow-csv",
        "cweijan.vscode-office",
        "qwtel.sqlite-viewer",
        "mongodb.mongodb-vscode"
    )
    if (Get-Command code -ErrorAction SilentlyContinue) {
        foreach ($ext in $extensions) {
            Write-Host "  - $ext"
            code --install-extension $ext
            if ($LASTEXITCODE -ne 0) { Write-Host "  [WARN] failed: $ext" -ForegroundColor Yellow }
        }
    } else {
        Write-Host "  [NOTE] open a NEW terminal and rerun to add extensions automatically" -ForegroundColor Yellow
    }
}

if (Want "deps") {
    Write-Host ""
    Write-Host "== Project dependencies ==" -ForegroundColor Cyan
    #  Repo-agnostic by design (this runs before any repo exists) - but when run
    #  FROM a cloned project, install its Python deps too.
    if (Test-Path "requirements.txt") {
        Write-Host "  requirements.txt found - installing project dependencies"
        pip install -r requirements.txt
        if ($LASTEXITCODE -ne 0) { Write-Host "  [WARN] pip install failed - open a NEW terminal (fresh PATH) and run: pip install -r requirements.txt" -ForegroundColor Yellow }
    } else {
        Write-Host "  no requirements.txt here - skip (per-project deps install when you clone a build repo)"
    }
}

Write-Host ""
Write-Host "== Verify (open a NEW terminal if a tool is not found) ==" -ForegroundColor Green
foreach ($cmd in @("git --version", "gh --version", "code --version", "python --version", "node --version", "heroku --version", "flyctl version", "gcloud --version", "railway --version", "mongosh --version")) {
    Write-Host ">> $cmd"
    try { Invoke-Expression $cmd } catch { Write-Host "   [not on PATH yet]" -ForegroundColor Yellow }
}

Write-Host ""
if ($failed.Count -gt 0) {
    Write-Host "[SUMMARY] FAILED installs: $($failed -join ', ') - rerun or install manually." -ForegroundColor Red
} else {
    Write-Host "[SUMMARY] All installs succeeded." -ForegroundColor Green
}
Write-Host ""
Write-Host "== Manual auth steps (one time) ==" -ForegroundColor Yellow
Write-Host "  git config --global user.name 'Your Name'        # names your commits"
Write-Host "  git config --global user.email 'you@example.com'  # git wont commit without these"
Write-Host "  gh auth login --hostname github.com --git-protocol https --web   # GitHub (also lets git push)"
Write-Host "  heroku login        # Heroku"
Write-Host "                      # 2FA may require the SALESFORCE AUTHENTICATOR app"
Write-Host "                      # on your phone (Salesforce owns Heroku) - install it first"

Write-Host ""
Write-Host "== About your new icons ==" -ForegroundColor Cyan
Write-Host "  Almost everything here is COMMAND-LINE - it lives in your terminal, not on"
Write-Host "  your desktop. The only app with a window is VS Code (your code editor) - find"
Write-Host "  it in the Start menu. Nothing needs to sit on your desktop; you can delete any"
Write-Host "  shortcut and the tool still works."

if ($failed.Count -gt 0) { exit 1 }

# END

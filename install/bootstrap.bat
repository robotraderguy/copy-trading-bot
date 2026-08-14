@echo off
setlocal enabledelayedexpansion
REM ============================================================
REM  RoboTraderGuy dev-environment bootstrap (Windows)
REM ============================================================
REM  WHAT THIS DOES: installs the tools used in the build videos
REM  (Git, GitHub CLI, VS Code, Python, Node.js, the deploy CLIs
REM  - Heroku, Fly.io, Google Cloud SDK, Railway - MongoDB
REM  Community Server + mongosh + Compass, three AI agent CLIs,
REM  and the clasp/Firebase/Linode platform CLIs) from their
REM  OFFICIAL sources via winget, Microsoft's built-in package
REM  manager, plus npm and pip. Nothing else is downloaded.
REM  (Local MongoDB = fast offline dev loop; Atlas stays the
REM  deployed bot's database.) Each item has a one-line WHY.
REM
REM  DISCLAIMER: provided as-is, no warranty. Review this file
REM  before running (it is short and readable on purpose). Some
REM  installs may prompt for admin approval. Educational use;
REM  you are responsible for software installed on your machine.
REM
REM  Run this file directly (double-click), OR install an AI coding
REM  agent first (Claude Code / Codex / Gemini) and let IT run the
REM  file - the installer sets up all three, so you're covered
REM  whichever agent you use. The videos are built with Claude Code.
REM
REM  Lean install (only some tools, or all-but-some):
REM    bootstrap.bat --only=git,gh,python      (ONLY these tags)
REM    bootstrap.bat --skip=mongo,compass      (everything EXCEPT these)
REM  Tags: git gh vscode python node heroku fly gcloud mongo mongosh
REM    compass railway aws az doctl claude codex gemini clasp firebase
REM    linode extensions deps  (see the manifest below).
REM ============================================================

REM --- Script directory, captured BEFORE the arg parser runs. `shift` below
REM     moves %0 as well as %1, so after parsing any argument %~dp0 no longer
REM     points at this script - it resolves against the current directory
REM     instead. Anything that needs a file next to this script must use
REM     %HERE%, never %~dp0. (This bit once sent a helper-script lookup to
REM     the repo root, and only when arguments were passed.) ---
set "HERE=%~dp0"

REM --- parse --only / --skip (commas OR spaces; cmd splits on commas,
REM     so a bare token after --only/--skip is appended to that list) ---
set "ONLY="
set "SKIP="
set "MODE="
:parse
if "%~1"=="" goto parsed
set "tok=%~1"
if /i "!tok:~0,7!"=="--only=" ( set "ONLY=!ONLY!,!tok:~7!" & set "MODE=ONLY" & shift & goto parse )
if /i "!tok:~0,7!"=="--skip=" ( set "SKIP=!SKIP!,!tok:~7!" & set "MODE=SKIP" & shift & goto parse )
if /i "!tok!"=="--only" ( set "MODE=ONLY" & shift & goto parse )
if /i "!tok!"=="--skip" ( set "MODE=SKIP" & shift & goto parse )
if /i "!MODE!"=="ONLY" set "ONLY=!ONLY!,!tok!"
if /i "!MODE!"=="SKIP" set "SKIP=!SKIP!,!tok!"
shift
goto parse
:parsed

echo  ============================================================
echo             o
echo             ^|
echo       .----------.
echo       ^| [/\/\-^>] ^|
echo       ^|   . : I  ^|
echo       '----------'
echo    ^> robotraderguy_          dev environment bootstrap
echo  ------------------------------------------------------------
echo    Watch AI build real trading tools, end to end.
echo    YouTube:  https://youtube.com/@robotraderguy
echo    Platform: https://tnttrading.net
echo    Hire me:  Upwork - link in any video description
echo  ============================================================
echo.

echo  Heads up: the FULL manifest is roughly 5 GB of disk ^(the Google Cloud SDK,
echo  Azure CLI, MongoDB and VS Code are the biggest^). You almost certainly do NOT
echo  want all of it - a project only needs a few of these, so pass --only=... with
echo  the tags for the build you're doing.
echo.
echo  Rough timings on a normal broadband connection:
echo    - everything, from nothing installed .... 25-45 min
echo    - everything, already installed ......... 2-5 min ^(just version checks^)
echo    - a typical --only set for one project .. 3-8 min
echo.
echo  Safe to re-run: anything already present is detected, and upgraded if it's
echo  an old version rather than skipped.
echo.
echo  [!] EXPECT PERMISSION POPUPS. Windows will ask "Do you want to allow this
echo      app to make changes to your device?" for several of these installers
echo      ^(Git, Node, VS Code, MongoDB and others^). That is normal - they are the
echo      official installers you just reviewed. Click YES each time, or the tool
echo      it is asking about will not install.
echo.
echo      The window can open BEHIND this one, and installing pauses until you
echo      answer. If this looks frozen, check your taskbar for a prompt waiting.
echo.

if defined ONLY echo  [only] installing:!ONLY! & echo.
if not defined ONLY if defined SKIP echo  [skip] leaving out:!SKIP! & echo.

REM --- Free-disk-space check - WARN (never abort). Ask PowerShell for free GB on
REM     C: (always present where winget is). Under ~7 GB is tight for a ~5 GB set. ---
set "FREEGB="
for /f "usebackq delims=" %%F in (`powershell -NoProfile -Command "[math]::Floor((Get-PSDrive C).Free/1GB)" 2^>nul`) do set "FREEGB=%%F"
if defined FREEGB (
    if !FREEGB! LSS 7 (
        echo  [WARN] Only ~!FREEGB! GB free on C: - the full manifest is ~5 GB and needs headroom to unpack.
        echo         Free up space, or install just what one build needs, e.g.  bootstrap.bat --only=git,gh,python,node
        echo.
    )
)

where winget >nul 2>nul
if %errorlevel% neq 0 (
    echo  [ERROR] winget not found. It ships with Windows 10 21H2+/11.
    echo          Install "App Installer" from the Microsoft Store, then rerun.
    pause
    exit /b 1
)

set FAILED=

call :install "git"     "Git"             "Git.Git"                    "version control - every project is a git repo, and gh needs it" "https://git-scm.com/downloads"
call :install "gh"      "GitHub CLI"      "GitHub.cli"                 "create and clone your repos from the terminal, no website" "https://cli.github.com"
call :install "vscode"  "VS Code"         "Microsoft.VisualStudioCode" "the editor you read the AI-written code in - Claude installs it" "https://code.visualstudio.com/download"
call :install "python"  "Python 3.13"     "Python.Python.3.13"         "the language the bots run on - plain Python from python.org; Anaconda is the manual fallback (README)" "https://www.python.org/downloads/"
call :install "node"    "Node.js LTS"     "OpenJS.NodeJS.LTS"          "a few tools run on it - including the Railway CLI below" "https://nodejs.org/en/download"
call :install "heroku"  "Heroku CLI"      "Heroku.HerokuCLI"           "deploy a bot to the cloud so it runs 24/7 without your PC on" "https://devcenter.heroku.com/articles/heroku-cli"
call :install "fly"     "Fly.io CLI"      "Fly-io.flyctl"              "an alternative cloud host used in some builds" "https://fly.io/docs/flyctl/install/"
call :install "gcloud"  "Google Cloud SDK" "Google.CloudSDK"           "the gcloud CLI - deploy and manage Google Cloud (large SDK)" "https://cloud.google.com/sdk/docs/install"
REM  Other cloud CLIs (aws / az / doctl). Tag-gated like everything else, so they
REM    only install when asked for - the lean --only set never pulls them in:
call :install "aws"   "AWS CLI"          "Amazon.AWSCLI"      "the aws CLI - deploy and manage AWS"          "https://aws.amazon.com/cli/"
call :install "az"    "Azure CLI"        "Microsoft.AzureCLI" "the az CLI - deploy and manage Azure"        "https://learn.microsoft.com/cli/azure/install-azure-cli"
call :install "doctl" "DigitalOcean CLI" "DigitalOcean.Doctl" "the doctl CLI - deploy and manage DigitalOcean" "https://docs.digitalocean.com/reference/doctl/how-to/install/"
REM  MongoDB Server: the "nocompass" flag makes the MSI SKIP its bundled Compass
REM    (SHOULD_INSTALL_COMPASS=0) - otherwise it drops a desktop icon + auto-opens.
call :install "mongo"   "MongoDB Server"  "MongoDB.Server"             "the database the bots use - fast offline dev; Atlas in the cloud when deployed" "https://www.mongodb.com/try/download/community" "nocompass"
call :install "mongosh" "MongoDB Shell"   "MongoDB.Shell"              "MongoDB's command-line shell, for peeking at the data" "https://www.mongodb.com/try/download/shell"
REM  MongoDB Compass - OPT-IN (not default). It's the one tool that makes a desktop
REM    icon, and VS Code's MongoDB extension (installed below) already browses the DB.
REM    Uncomment to include it (then it installs, or use --only=compass for just it):
REM  call :install "compass" "MongoDB Compass" "MongoDB.Compass.Full" "a point-and-click MongoDB browser, if you'd rather not type" "https://www.mongodb.com/try/download/compass"

REM  Railway CLI - another cloud host; ships via npm (Node above), not winget.
call :want railway
if not errorlevel 1 (
    echo.
    echo ==^> Railway CLI
    echo         another cloud host - installs via npm (Node, above)
    where railway >nul 2>nul
    if !errorlevel! neq 0 (
        call npm install -g @railway/cli
        if !errorlevel! neq 0 (
            echo  [ERROR] Railway CLI failed - skipping; the rest still install.
            echo          install it by hand: https://docs.railway.com/guides/cli
            set "FAILED=!FAILED! Railway"
        )
    ) else (
        echo  [OK] already installed.
    )
)

echo.
echo == AI coding agents (the videos use Claude Code; the others are here so you ==
echo ==   can follow along in whatever agent you prefer - install any/all) ==
REM  Claude Code - the agent the videos are built with; the builds + skills are
REM    tuned to it, so it's here even if you mainly use another.
call :npm "claude" "Claude Code CLI" "@anthropic-ai/claude-code" "the AI agent the videos are built with (skills are tuned to it)" "https://docs.claude.com/en/docs/claude-code/overview"
call :npm "codex"  "OpenAI Codex CLI" "@openai/codex" "OpenAI's coding agent - if you prefer Codex" "https://github.com/openai/codex"
call :npm "gemini" "Gemini CLI" "@google/gemini-cli" "Google's coding agent - if you prefer Gemini" "https://github.com/google-gemini/gemini-cli"
REM  Grok - xAI ships no official first-party agent CLI yet; nothing to install.

echo.
echo == Platform CLIs (Apps Script, Firebase, Linode) ==
REM  clasp - develop Google Apps Script locally and push it (npm).
call :npm "clasp"    "clasp (Apps Script)" "@google/clasp" "develop Google Apps Script locally and push it" "https://github.com/google/clasp"
REM  Firebase CLI - manage and deploy Firebase projects (npm).
call :npm "firebase" "Firebase CLI" "firebase-tools" "manage and deploy Firebase projects" "https://firebase.google.com/docs/cli"
REM  Linode CLI - manage Linode/Akamai cloud (a Python pip tool, not npm).
call :want linode
if not errorlevel 1 (
    echo.
    echo ==^> Linode CLI
    echo         manage Linode/Akamai cloud infrastructure
    call python -m pip install linode-cli
    if !errorlevel! neq 0 (
        echo  [ERROR] Linode CLI failed - skipping; the rest still install.
        echo          install it by hand: https://techdocs.akamai.com/cloud-computing/docs/cli
        set "FAILED=!FAILED! Linode"
    )
)

call :want extensions
if not errorlevel 1 (
    echo.
    echo == VS Code extensions (Python, Claude Code, CSV/Office/db viewers, MongoDB) ==
    where code >nul 2>nul
    if !errorlevel!==0 (
        echo   - Python
        call code --install-extension ms-python.python
        if !errorlevel! neq 0 echo  [WARN] Python extension failed - run manually: code --install-extension ms-python.python
        echo   - Claude Code
        call code --install-extension anthropic.claude-code
        if !errorlevel! neq 0 echo  [WARN] Claude Code extension failed - run manually: code --install-extension anthropic.claude-code
        echo   - CSV viewer
        call code --install-extension mechatroner.rainbow-csv
        if !errorlevel! neq 0 echo  [WARN] CSV viewer extension failed - run manually: code --install-extension mechatroner.rainbow-csv
        echo   - Word/Excel/PDF viewer
        call code --install-extension cweijan.vscode-office
        if !errorlevel! neq 0 echo  [WARN] Word/Excel/PDF viewer extension failed - run manually: code --install-extension cweijan.vscode-office
        echo   - SQLite/db viewer
        call code --install-extension qwtel.sqlite-viewer
        if !errorlevel! neq 0 echo  [WARN] SQLite/db viewer extension failed - run manually: code --install-extension qwtel.sqlite-viewer
        echo   - MongoDB
        call code --install-extension mongodb.mongodb-vscode
        if !errorlevel! neq 0 echo  [WARN] MongoDB extension failed - run manually: code --install-extension mongodb.mongodb-vscode
    ) else (
        echo  [NOTE] VS Code not on PATH yet. Open a NEW terminal and rerun this script
        echo         to add the extensions automatically.
    )
)

call :want deps
if not errorlevel 1 (
    echo.
    echo == Project dependencies ==
    REM  Repo-agnostic by design (runs before any repo exists) - but when run
    REM  FROM a cloned project, install its Python deps too.
    if exist requirements.txt (
        echo   requirements.txt found - installing project dependencies
        call pip install -r requirements.txt
        if !errorlevel! neq 0 echo  [WARN] pip install failed - open a NEW terminal and run: pip install -r requirements.txt
    ) else (
        echo   no requirements.txt here - skip ^(per-project deps install when you clone a build repo^)
    )
)

echo.
echo == Verify (open a NEW terminal if a tool is not found) ==
for %%c in ("git --version" "gh --version" "python --version" "node --version" "heroku --version" "flyctl version" "gcloud --version" "railway --version" "mongosh --version") do (
    echo ^>^> %%~c
    call %%~c 2>nul || echo    [not on PATH yet]
)

echo.
if defined FAILED (
    echo  [SUMMARY] Some installs FAILED:%FAILED%
    echo            Rerun this script, or install those manually.
) else (
    echo  [SUMMARY] All installs succeeded.
)
echo.
echo == Manual auth steps (one time) ==
echo   git config --global user.name "Your Name"        (names your commits)
echo   git config --global user.email "you@example.com"  (git wont commit without these)
echo   gh auth login --hostname github.com --git-protocol https --web   (GitHub - also lets git push)
echo   heroku login        (Heroku)
echo                       2FA may require the SALESFORCE AUTHENTICATOR app
echo                       on your phone ^(Salesforce owns Heroku^) - install it first
echo.
echo == About your new icons ==
echo   Almost everything here is COMMAND-LINE - it lives in your terminal, not on
echo   your desktop. The only app with a window is VS Code (your code editor) - find
echo   it in the Start menu. Nothing needs to sit on your desktop; you can delete any
echo   shortcut and the tool still works.
pause
exit /b 0

REM  :want <tag>  -> errorlevel 0 = install this item, 1 = skip it.
REM  --only wins if both are set. Lists are comma-wrapped for exact matching.
:want
set "tag=%~1"
if defined ONLY (
    echo !ONLY!,| findstr /i /c:",!tag!," >nul
    exit /b !errorlevel!
)
if defined SKIP (
    echo !SKIP!,| findstr /i /c:",!tag!," >nul
    if !errorlevel!==0 (exit /b 1) else (exit /b 0)
)
exit /b 0

REM  :install  "<tag>" "<label>" "<winget-id>" "<why>" "<manual-download-url>"
REM  Independent: a failure is recorded + skipped (the rest still install) and
REM  prints the URL to grab it by hand. %~4 (why) prints as it starts. --only/
REM  --skip gate by <tag>.
:install
call :want %~1
if errorlevel 1 exit /b 0
echo.
echo ==^> %~2
if not "%~4"=="" echo         %~4
set "EXTRA="
if "%~6"=="nocompass" set "EXTRA=--custom "SHOULD_INSTALL_COMPASS=0""
winget install --id %~3 --silent --accept-package-agreements --accept-source-agreements !EXTRA!
if %errorlevel% neq 0 (
    if %errorlevel%==-1978335189 (
        REM  Already present - but possibly a STALE version from an older install,
        REM  which fails later in confusing ways. Presence is not enough; upgrade it.
        winget upgrade --id %~3 --silent --accept-package-agreements --accept-source-agreements !EXTRA! >nul 2>&1
        if !errorlevel!==0 (
            echo  [OK] %~2 was already installed - upgraded to the latest.
        ) else (
            echo  [OK] %~2 is already installed and up to date.
        )
    ) else (
        echo  [ERROR] %~2 failed to install ^(winget exit %errorlevel%^) - skipping; the rest still install.
        if not "%~5"=="" echo          install it by hand: %~5
        set "FAILED=!FAILED! %~2"
    )
)
exit /b 0

REM  :npm  "<tag>" "<label>" "<npm-package>" "<why>" "<manual-download-url>"
REM  Same independent pattern as :install, but for npm-global tools (Node above).
:npm
call :want %~1
if errorlevel 1 exit /b 0
echo.
echo ==^> %~2
if not "%~4"=="" echo         %~4
call npm install -g %~3
if %errorlevel% neq 0 (
    echo  [ERROR] %~2 failed - skipping; the rest still install.
    if not "%~5"=="" echo          install it by hand: %~5
    set "FAILED=!FAILED! %~2"
)
exit /b 0

REM END

# ============================================================
# Claude Code Setup - Windows
# ============================================================
# Installs a complete Claude Code development environment:
# Claude Code CLI, Node.js, Git, Python, VS Code,
# GitHub CLI, and Obsidian.
#
# Run from PowerShell:
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   .\setup-windows.ps1
#
# Error handling: the script CONTINUES on failure. Each step is
# isolated - if one install fails (network, winget glitch, broken
# manifest, etc.), remaining steps still run. On any failure you
# get a structured FAILURE box with the exit code, last 10 lines
# of captured output, and a remediation hint. At the end of the
# run a recap block prints remediation for each failed step.
# ============================================================

# Non-terminating errors don't stop the script (this is the PS default,
# but being explicit for clarity).
$ErrorActionPreference = "Continue"

# Default-on logging. Start-Transcript captures all Write-Host, Write-Error,
# AND native command output (winget, git, etc.) in PS 5.1+. Overwrites on each
# run - re-runs are idempotent, so keeping old logs around isn't useful.
#
# We rely on the default %USERPROFILE% ACLs for confidentiality -- files
# created under the user's profile dir inherit "owner + SYSTEM read/write
# only" by default, so other local users on the machine cannot read this
# log.
$LogFile = Join-Path $env:USERPROFILE "claude-starter-install.log"
try { Start-Transcript -Path $LogFile -Force | Out-Null } catch { }

$FailedSteps = New-Object System.Collections.ArrayList

# ------------------------------------------------------------
# Resume / checkpoint state
# ------------------------------------------------------------
# This script is safe to run as many times as you like - already-installed
# tools and existing logins are detected live and skipped, so a re-run never
# reinstalls or re-does what is already in place. The checkpoint file below
# records which one-time actions (Claude / Codex / GitHub sign-in) finished,
# so a re-run can announce "resuming" instead of feeling like starting over.
#
# Why this matters: the single most common place people stop is the Claude
# Code sign-in step. If that happens - or the script is interrupted anywhere
# else - just run it again. It picks up right where you left off.
#
#   Resume (default):   .\setup-windows.ps1
#   Start over clean:   .\setup-windows.ps1 --fresh   (--restart is an alias)
#
# ELNORA_SETUP_STATE_FILE overrides the path (used by the test suite so a
# local re-run of the smoke test starts from a clean slate).
$SetupStateFile = if ($env:ELNORA_SETUP_STATE_FILE) { $env:ELNORA_SETUP_STATE_FILE } else { Join-Path $env:USERPROFILE ".claude-starter-setup-state" }
if ($args -contains "--fresh" -or $args -contains "--restart") {
    Remove-Item -LiteralPath $SetupStateFile -Force -ErrorAction SilentlyContinue
    Write-Host "  (--fresh: cleared saved progress - starting from the beginning.)" -ForegroundColor Gray
}
if (-not (Test-Path -LiteralPath $SetupStateFile)) {
    try { New-Item -ItemType File -Path $SetupStateFile -Force -ErrorAction Stop | Out-Null } catch { }
}

# Test-Checkpoint <name> -> $true if this checkpoint was reached on a prior run.
# Set-Checkpoint  <name> -> record a checkpoint (idempotent; one name per line).
function Test-Checkpoint {
    param([string]$Name)
    if (-not (Test-Path -LiteralPath $SetupStateFile)) { return $false }
    return @(Get-Content -LiteralPath $SetupStateFile -ErrorAction SilentlyContinue) -contains $Name
}
function Set-Checkpoint {
    param([string]$Name)
    if (-not (Test-Checkpoint $Name)) {
        try {
            Add-Content -LiteralPath $SetupStateFile -Value $Name -ErrorAction Stop
        } catch {
            Write-Host "  [WARN] Could not write checkpoint '$Name' to $SetupStateFile - a re-run will repeat this step instead of resuming past it." -ForegroundColor Yellow
        }
    }
}

function Update-SessionPath {
    # Reload PATH from the registry so this session sees binaries added by a
    # just-run installer. Without this, `winget install Git.Git` succeeds but
    # `Get-Command git` still fails until the user restarts PowerShell -
    # which would make the git-config block (and the verify summary) wrong.
    $machine = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $user    = [System.Environment]::GetEnvironmentVariable("Path", "User")
    # Split into individual entries so dedup works against single bin paths
    # (without this, -notcontains compares the full PATH string and never
    # matches, so $claudeBin gets re-appended on every call).
    $entries = @()
    foreach ($src in @($machine, $user)) {
        if ($src) { $entries += ($src -split ';' | Where-Object { $_ }) }
    }
    # Claude Code installer writes to %USERPROFILE%\.local\bin - ensure it's present.
    $claudeBin = Join-Path $env:USERPROFILE ".local\bin"
    if ((Test-Path $claudeBin) -and ($entries -notcontains $claudeBin)) {
        $entries += $claudeBin
    }
    $env:Path = ($entries -join ";")
}

# Self-defense: ensure user-local bin is on Path from line 1.
# This makes the script work even when re-run from a terminal that was
# opened before any prior install (where %USERPROFILE%\.local\bin isn't
# yet in the inherited Path). Idempotent -- no harm if the dir doesn't
# exist yet.
$localBin = Join-Path $env:USERPROFILE ".local\bin"
if ($env:Path -notlike "*$localBin*") {
    $env:Path = "$localBin;$env:Path"
}

# ------------------------------------------------------------
# Get-RemediationHint -Label "<step label>"
# ------------------------------------------------------------
# Returns a multi-line, step-specific remediation message. Used by
# Write-StepFailure (immediate failure context) AND by the end-of-run
# recap (so the user gets a full punch list of what to do next).
# Matched via -like wildcards so "Python 3.12 (PATH/alias issue)" still
# hits the Python branch.
function Get-RemediationHint {
    param([string]$Label)
    if ($Label -like "winget*") {
        return @'
winget ships with the "App Installer" package on Windows 10 (build 1809+)
and Windows 11. If it's missing:
  1. Open Microsoft Store
  2. Search for "App Installer" OR go to:
       https://apps.microsoft.com/detail/9nblggh4nns1
  3. Click Install
  4. Reopen PowerShell and re-run this script
If the Store is blocked by your org's policy:
  - Download the .msixbundle directly from
      https://github.com/microsoft/winget-cli/releases
    and install via: Add-AppxPackage <path-to-bundle>
  - Or use Chocolatey (https://chocolatey.org) / Scoop (https://scoop.sh)
    to install these tools instead.
'@
    }
    elseif ($Label -like "Node.js*") {
        return @'
Try manually:
  winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
Or download the installer:
  https://nodejs.org/en/download
Verify in a NEW PowerShell window:
  node --version    # should print vXX.X.X
  npm --version
If `node` still isn't found after a new terminal, your PATH didn't update -
check: Get-Command node  and:  $env:Path -split ';' | Select-String node
'@
    }
    elseif ($Label -like "Git*" -and $Label -notlike "Git config*") {
        return @'
Try manually:
  winget install Git.Git --accept-package-agreements --accept-source-agreements
Or download the installer:
  https://git-scm.com/download/win
Verify in a NEW PowerShell window:
  git --version
'@
    }
    elseif ($Label -like "Git config*") {
        return @'
Set the values manually:
  git config --global user.name  "Your Full Name"
  git config --global user.email "you@example.com"
  git config --global init.defaultBranch main
Verify all three at once:
  git config --global --list | Select-String -Pattern 'user\.|init\.'
'@
    }
    elseif ($Label -like "Python*") {
        return @'
Try manually:
  winget install Python.Python.3.12 --accept-package-agreements --accept-source-agreements
Or download the installer:
  https://www.python.org/downloads/windows/
If the Microsoft Store keeps intercepting `python`:
  1. Settings -> Apps -> Advanced app settings -> App execution aliases
  2. Turn OFF BOTH `python.exe` and `python3.exe`
  3. Reopen PowerShell and run:  python --version
Verify:
  python --version   # should print "Python 3.x.x" - NOT open the Store
If `python` still opens the Store but real Python is installed, use the
`py` launcher instead (lives at C:\Windows\py.exe, always available):
  py --version
  py -m pip install <pkg>
'@
    }
    elseif ($Label -like "VS Code*") {
        return @'
Try manually:
  winget install Microsoft.VisualStudioCode --accept-package-agreements --accept-source-agreements
Or download the installer:
  https://code.visualstudio.com/download
Verify by reopening PowerShell and running:
  code --version
If `code` command isn't found but VS Code is installed: add its bin dir
to PATH manually (usually $env:LOCALAPPDATA\Programs\Microsoft VS Code\bin).
'@
    }
    elseif ($Label -like "Claude Code*") {
        return @'
Try manually:
  irm https://claude.ai/install.ps1 | iex
Or install via npm (requires Node.js):
  npm install -g @anthropic-ai/claude-code
If PowerShell blocks the install script with an execution policy error:
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  irm https://claude.ai/install.ps1 | iex
If your PATH keeps reverting (corporate laptop / Group Policy), copy
the exe into WindowsApps which is always in default user PATH:
  Copy-Item "$env:USERPROFILE\.local\bin\claude.exe" `
            "$env:LOCALAPPDATA\Microsoft\WindowsApps\claude.exe" -Force
Docs: https://docs.claude.com/en/docs/claude-code/overview
Verify in a NEW PowerShell window:
  claude --version
'@
    }
    elseif ($Label -like "GitHub CLI*") {
        return @'
Try manually:
  winget install --id GitHub.cli --accept-package-agreements --accept-source-agreements
Or download the installer:
  https://cli.github.com/
Verify in a NEW PowerShell window:
  gh --version
Then authenticate:
  gh auth login        # choose GitHub.com, HTTPS, then browser login
If PATH didn't persist, copy gh.exe to WindowsApps:
  Copy-Item "$env:ProgramFiles\GitHub CLI\gh.exe" `
            "$env:LOCALAPPDATA\Microsoft\WindowsApps\gh.exe" -Force
'@
    }
    elseif ($Label -like "Obsidian*") {
        return @'
Try manually:
  winget install Obsidian.Obsidian --accept-package-agreements --accept-source-agreements
Or download the installer:
  https://obsidian.md/download
This step is OPTIONAL - you can skip it if you don't plan to use a
knowledge base. Nothing else in this setup depends on Obsidian.
'@
    }
    elseif ($Label -like "Projects folder*") {
        return @'
Try manually:
  New-Item -ItemType Directory "$env:USERPROFILE\Documents\Projects"
If that fails, check your Documents folder exists and is writable:
  Get-Item "$env:USERPROFILE\Documents"
  (Get-Acl "$env:USERPROFILE\Documents").Access | Where-Object { $_.IdentityReference -like "*$env:USERNAME*" }
Common causes: OneDrive "Known Folder Move" has relocated Documents to
a synced folder that's temporarily offline, or a corporate policy has
made Documents read-only. In that case, pick a different parent folder:
  New-Item -ItemType Directory "$env:USERPROFILE\Projects"
'@
    }
    else {
        return "No specific remediation available - scroll up to see the captured output."
    }
}

# ------------------------------------------------------------
# Write-StepFailure -Label "..." -ExitCode N [-Command "..."] [-ErrorOutput "..."]
# ------------------------------------------------------------
# Prints a structured FAILURE box with the exit code, the command,
# the last 10 lines of captured output, and a step-specific remediation hint.
#
# WARNING for future maintainers: the FAILURE box echoes -Command verbatim.
# Today no caller passes a secret in the command string (the API key path
# uses Read-Host -AsSecureString and stays out of $LASTEXITCODE / argv). If
# you ever route a secret through here -- e.g. an OAuth token interpolated
# into a scriptblock -- the failure box will leak it to the terminal and
# Start-Transcript log. Pre-redact or wrap such commands in a helper that
# passes a sanitized command line instead.
function Write-StepFailure {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][int]$ExitCode,
        [string]$Command = "",
        [string]$ErrorOutput = ""
    )
    Write-Host ""
    Write-Host "  +-- FAILURE: $Label" -ForegroundColor Red
    Write-Host "  |   Exit code: $ExitCode" -ForegroundColor Red
    if ($Command) {
        Write-Host "  |   Command:   $Command" -ForegroundColor Red
    }
    if ($ErrorOutput) {
        $lines = ($ErrorOutput -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -Last 10
        if ($lines) {
            Write-Host "  |" -ForegroundColor Red
            Write-Host "  |   Captured output (last 10 lines):" -ForegroundColor Red
            foreach ($line in $lines) {
                Write-Host "  |     $line" -ForegroundColor DarkGray
            }
        }
    }
    Write-Host "  |" -ForegroundColor Red
    Write-Host "  |   What to do:" -ForegroundColor Yellow
    $hint = Get-RemediationHint -Label $Label
    foreach ($line in ($hint -split "`r?`n")) {
        Write-Host "  |     $line" -ForegroundColor Yellow
    }
    Write-Host "  +-----------------------------------------------------------" -ForegroundColor Red
    Write-Host ""
}

function Invoke-Step {
    # Runs a scriptblock. On failure (exception or non-zero $LASTEXITCODE)
    # prints a structured FAILURE box and records the step for the end-of-run
    # recap.
    #
    # Captures stdout+stderr (via 2>&1) into a buffer while still echoing each
    # line live, so the FAILURE box can quote the last 10 lines of output.
    #
    # -SuppressPattern: optional regex; matching lines are still recorded in the
    # capture buffer (so a FAILURE box can still quote them) but are NOT echoed
    # to the user's terminal. Used to drop known noise (e.g. winget's
    # progress-bar redraws - see $wingetNoisePattern below).
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][scriptblock]$Action,
        [string]$SuppressPattern = ""
    )
    $commandText = ($Action.ToString().Trim() -replace '\s+', ' ')
    $buffer = New-Object System.Text.StringBuilder
    try {
        & $Action 2>&1 | ForEach-Object {
            $line = $_.ToString()
            [void]$buffer.AppendLine($line)
            if (-not $SuppressPattern -or $line -notmatch $SuppressPattern) {
                Write-Host $line
            }
        }
        if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
            Write-StepFailure -Label $Label -ExitCode $LASTEXITCODE `
                -Command $commandText -ErrorOutput $buffer.ToString()
            [void]$FailedSteps.Add("$Label (exit $LASTEXITCODE)")
            $global:LASTEXITCODE = 0
        }
    } catch {
        [void]$buffer.AppendLine($_.Exception.Message)
        Write-StepFailure -Label $Label -ExitCode -1 `
            -Command $commandText -ErrorOutput $buffer.ToString()
        [void]$FailedSteps.Add("$Label ($($_.Exception.Message))")
    }
}

function Test-RealPython {
    # Windows ships with a Microsoft Store "app execution alias" for `python` -
    # a 0-byte stub at %LOCALAPPDATA%\Microsoft\WindowsApps\python.exe that opens
    # the Store instead of running Python. Get-Command returns true for the stub,
    # so we have to actually invoke it and check the output.
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) { return $false }
    try {
        $version = (& python --version 2>&1 | Select-Object -First 1)
        return ($version -match '^Python 3\.\d+\.\d+')
    } catch {
        return $false
    }
}

function Remove-PythonStoreAlias {
    # Deletes the 0-byte Store stub so real Python (installed via winget) wins
    # PATH lookup. We only delete if the file is actually a 0-byte stub - never
    # touch a real python.exe.
    $stub = "$env:LOCALAPPDATA\Microsoft\WindowsApps\python.exe"
    if (-not (Test-Path $stub)) { return $false }
    $stubItem = Get-Item $stub -ErrorAction SilentlyContinue
    if (-not $stubItem -or $stubItem.Length -ne 0) { return $false }
    try {
        Remove-Item $stub -Force -ErrorAction Stop
        Write-Host "  Removed Python Store alias stub at $stub" -ForegroundColor Yellow
        return $true
    } catch {
        Write-Host "  [!] Could not remove Python Store alias stub at $stub" -ForegroundColor Red
        Write-Host "      Reason: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "      Disable it manually instead: Settings -> Apps -> Advanced app settings" -ForegroundColor Red
        Write-Host "      -> App execution aliases -> turn OFF 'python.exe' and 'python3.exe'." -ForegroundColor Red
        return $false
    }
}

function Copy-StandaloneExeToWindowsApps {
    # Copies a self-contained .exe into %LOCALAPPDATA%\Microsoft\WindowsApps -
    # always in the default user PATH on Win10/11 and immune to Group Policy
    # PATH reverts. Only safe for single-binary tools (Go binaries like gh.exe,
    # bundled binaries like claude.exe). Do NOT use for Python - python.exe
    # depends on neighbouring DLLs that won't travel with the copy.
    param(
        [Parameter(Mandatory)][string]$ExePath,
        [Parameter(Mandatory)][string]$ToolName
    )
    if (-not (Test-Path $ExePath)) {
        Write-Host "  [!] Source exe not found at $ExePath - cannot copy." -ForegroundColor Red
        return $false
    }
    $windowsApps = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
    if (-not (Test-Path $windowsApps)) {
        Write-Host "  [!] WindowsApps folder not found at $windowsApps - unusual for Win10/11." -ForegroundColor Red
        Write-Host "      You can add $((Split-Path $ExePath -Parent)) to your User PATH manually:" -ForegroundColor Red
        Write-Host "        [Environment]::SetEnvironmentVariable('Path', `"`$env:Path;$((Split-Path $ExePath -Parent))`", 'User')" -ForegroundColor Red
        return $false
    }
    try {
        Copy-Item $ExePath (Join-Path $windowsApps "$ToolName.exe") -Force -ErrorAction Stop
        Write-Host "  Copied $ToolName.exe to WindowsApps (GP-immune PATH fallback)." -ForegroundColor Green
        Write-Host "  Note: this copy will not auto-update - re-run the script after upstream releases." -ForegroundColor Gray
        return $true
    } catch {
        Write-Host "  [!] Fallback copy for $ToolName failed:" -ForegroundColor Red
        Write-Host "      Source:      $ExePath" -ForegroundColor Red
        Write-Host "      Destination: $(Join-Path $windowsApps "$ToolName.exe")" -ForegroundColor Red
        Write-Host "      Reason:      $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "      This usually means antivirus is blocking the copy, or WindowsApps" -ForegroundColor Red
        Write-Host "      is locked down by Group Policy. Try running PowerShell as Administrator" -ForegroundColor Red
        Write-Host "      and re-run, or add $(Split-Path $ExePath -Parent) to PATH manually." -ForegroundColor Red
        return $false
    }
}

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  Claude Code Setup for Windows" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  Log: $LogFile" -ForegroundColor Gray
Write-Host ""

# If we have saved progress from an earlier run, say so up front - so the
# "already installed / Skipping" lines below clearly read as "resuming",
# not "starting over".
if ((Test-Path -LiteralPath $SetupStateFile) -and ((Get-Item -LiteralPath $SetupStateFile -ErrorAction SilentlyContinue).Length -gt 0)) {
    Write-Host "  Resuming where a previous run left off - finished steps are skipped." -ForegroundColor Gray
    Write-Host "  (To start over from scratch instead:  .\setup-windows.ps1 --fresh)" -ForegroundColor Gray
    Write-Host ""
}

# --- winget progress-bar noise filter ---
# winget redraws an ASCII progress bar 100+ times per package (downloading,
# verifying, installing). When 2>&1 captures stderr into the line-buffered
# pipeline that Invoke-Step iterates, each redraw becomes its own line in
# the live output AND in the install transcript. Across Node + Git + Python
# + VS Code + GitHub CLI + Obsidian that's 200+ lines of pure noise and
# obscures real errors.
#
# Drop lines that are pure progress-bar content. Three flavours show up:
#   1. Block-char fills, e.g. `\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588 30.9 MB / 30.9 MB` \u2014 solid
#      block / shade chars (U+2588, U+2592, U+2591, plus the half-block
#      family U+2580..U+2590), with optional byte/byte readouts.
#   2. ASCII rotating-spinner frames during downloads \u2014 single
#      backslash, pipe, or forward-slash on a line of mostly whitespace
#      (`   \ `, `   | `, `   / `). winget emits these even with
#      --disable-interactivity in CI; without filtering them, the live
#      log gets a flood of one-char lines (~600 lines per smoke run).
#   3. Trailing percentage / byte readouts that survived after the bar
#      itself drained.
#
# Real error/info lines from winget are full prose ("Found
# Microsoft.VisualStudioCode...", "Successfully installed", "Installer
# hash does not match", etc.) and don't match.
#
# Pattern uses .NET regex \uXXXX escapes (ASCII source bytes) so the file
# stays clean for the ASCII-lint check; the regex engine still matches the
# real Unicode glyphs at runtime.
#
# These lines are still recorded in Invoke-Step's capture buffer, so if a
# winget call exits non-zero the FAILURE box still has the full byte trail
# for debugging.
$wingetNoisePattern = '^[\s\u2580-\u2593\\\-|/]+$|^\s*\d+(\.\d+)?\s*%\s*$|^\s*\d+(\.\d+)?\s*[KMG]?B\s*/\s*\d+(\.\d+)?\s*[KMG]?B\s*$|^[\s\u2580-\u2593]+\s*\d+(\.\d+)?\s*%\s*$'

# --- Check for winget ---
$hasWinget = Get-Command winget -ErrorAction SilentlyContinue
if (-not $hasWinget) {
    if ($env:ELNORA_SKIP_OPTIONAL_INSTALLS -eq "1") {
        # CI/non-interactive path. windows-2022 GitHub Actions runners do not
        # ship winget, and the smoke test deliberately sets
        # ELNORA_SKIP_OPTIONAL_INSTALLS=1 to opt out of every winget-backed
        # tool (Node, Git, Python, VS Code, GitHub CLI, Obsidian). Do NOT
        # block on Read-Host (no TTY) and do NOT record a FAILURE - it's a
        # documented skipped state, not a real install failure. Each
        # downstream winget step is also gated below so they print [SKIP]
        # instead of recording their own failures.
        Write-Host ""
        Write-Host "  [SKIP] winget not found - ELNORA_SKIP_OPTIONAL_INSTALLS=1, skipping every winget-backed step." -ForegroundColor DarkGray
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "  +-- PREREQUISITE: winget not found" -ForegroundColor Yellow
        Write-Host "  |" -ForegroundColor Yellow
        Write-Host "  |   winget is the Windows package manager used by this script to" -ForegroundColor Yellow
        Write-Host "  |   install Node.js, Python, VS Code, GitHub CLI, and Obsidian." -ForegroundColor Yellow
        Write-Host "  |" -ForegroundColor Yellow
        Write-Host "  |   What to do:" -ForegroundColor Yellow
        foreach ($line in ((Get-RemediationHint -Label "winget") -split "`r?`n")) {
            Write-Host "  |     $line" -ForegroundColor Yellow
        }
        Write-Host "  +-----------------------------------------------------------" -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Press Enter AFTER installing winget (script will retry), or Ctrl+C to exit"
        # Re-check; if still missing, most steps will fail but we let them run so
        # the user sees the full picture and can take action on any that use direct
        # installers (Claude Code uses irm|iex, not winget).
        $hasWinget = Get-Command winget -ErrorAction SilentlyContinue
        if (-not $hasWinget) {
            Write-Host "  [!] winget still not found - winget-based steps will fail below." -ForegroundColor Red
            [void]$FailedSteps.Add("winget (prerequisite missing)")
        }
    }
}

# --- Coding agent selection (set by install.ps1; default to claude) ---
# $env:ELNORA_AGENT is claude | codex | both; $env:ELNORA_HANDOFF_AGENT
# (claude | codex) finishes Phase 2. A direct setup-windows.ps1 run with no
# install.ps1 defaults to claude so existing muscle memory still works.
$Agent = ("$($env:ELNORA_AGENT)").ToLowerInvariant() -replace '\s',''
if ($Agent -notin @('claude','codex','both')) { $Agent = 'claude' }
if ($Agent -eq 'both') {
    $HandoffAgent = ("$($env:ELNORA_HANDOFF_AGENT)").ToLowerInvariant() -replace '\s',''
    if ($HandoffAgent -notin @('claude','codex')) { $HandoffAgent = 'claude' }
} else {
    $HandoffAgent = $Agent
}
# True when $which (claude|codex) is among the installed agent(s).
function Test-AgentInstalled([string]$which) { return ($Agent -eq $which -or $Agent -eq 'both') }

# --- [1/8] Claude Code CLI (installed FIRST - zero dependencies) ---
# Using Anthropic's native installer so Claude Code is the very first thing on
# the machine. Works even when winget is missing (unlike the rest of the tools
# below). Writes a self-contained binary to %USERPROFILE%\.local\bin\claude.exe.
if (Test-AgentInstalled 'claude') {
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "[1/8] Installing Claude Code..." -ForegroundColor Green
    Write-Host "  Using Anthropic's native installer (no prerequisites required)." -ForegroundColor Gray
    # Run the installer in a child powershell.exe. `iex` evaluates its input in
    # caller scope, so an `exit N` inside the fetched installer would terminate
    # setup-windows.ps1 itself - skipping every later step and the end-of-run
    # recap. The sub-process contains `exit`, propagates the exit code back via
    # $LASTEXITCODE for Invoke-Step to detect, and isolates any
    # $ErrorActionPreference changes made by the installer.
    #
    # The leading SecurityProtocol assignment forces TLS 1.2. powershell.exe =
    # Windows PowerShell 5.1, which on older/unpatched Windows 10 builds
    # defaults to SSL3/TLS 1.0. Modern CDNs (claude.ai) reject that handshake
    # and `irm` fails with an opaque "underlying connection was closed"
    # error the FAILURE box can't explain.
    Invoke-Step "Claude Code" { powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm https://claude.ai/install.ps1 | iex" }
    Update-SessionPath

    # The Anthropic installer writes claude.exe to %USERPROFILE%\.local\bin and
    # updates User PATH via setx. Corporate Group Policy can silently revert
    # User PATH - user opens a new terminal, claude is gone. Detect and fall
    # back to WindowsApps (default user PATH, GP-immune).
    $claudeBinDir = Join-Path $env:USERPROFILE ".local\bin"
    $claudeExe    = Join-Path $claudeBinDir "claude.exe"
    if (-not (Test-Path $claudeExe)) {
        # Installer reported success but the binary isn't on disk. If Invoke-Step
        # already logged a non-zero exit, skip to avoid duplicate entries in the
        # recap - the existing failure already routes to the right remediation.
        $alreadyLogged = @($FailedSteps | Where-Object { $_ -like "Claude Code*" }).Count -gt 0
        if (-not $alreadyLogged) {
            Write-Host "  [!] Installer completed but claude.exe is missing at $claudeExe." -ForegroundColor Red
            [void]$FailedSteps.Add("Claude Code (binary not found after install)")
        }
    } else {
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($userPath -notlike "*$claudeBinDir*") {
            Write-Host "  [!] User PATH does not contain '.local\bin' after install." -ForegroundColor Yellow
            Write-Host "      Common causes: corporate Group Policy reverting User PATH," -ForegroundColor Yellow
            Write-Host "      antivirus blocking the installer's PATH update, or running" -ForegroundColor Yellow
            Write-Host "      from a non-interactive shell (CI, scheduled task)." -ForegroundColor Yellow
            Write-Host "      Falling back: copying claude.exe to WindowsApps (always on default user PATH)." -ForegroundColor Yellow
            Write-Host "      Heads up: this fallback copy will NOT auto-update with Claude Code releases." -ForegroundColor Yellow
            Write-Host "      Re-run this script (or 'irm https://claude.ai/install.ps1 | iex')" -ForegroundColor Yellow
            Write-Host "      to refresh after upstream releases. See RECOVERY.md for details." -ForegroundColor Yellow
            if (-not (Copy-StandaloneExeToWindowsApps -ExePath $claudeExe -ToolName "claude")) {
                [void]$FailedSteps.Add("Claude Code PATH")
            }
        }
    }
} else {
    Write-Host "[1/8] Claude Code already installed: $(claude --version). Skipping." -ForegroundColor Gray
}
}  # end if Test-AgentInstalled 'claude'

# --- [2/8] Node.js (pinned to >=22 for Mac/Windows parity) ---
# Mirror setup-mac.sh's major-version probe (lines 426-432). Bare
# `Get-Command node` would let a pre-installed Node 18 / 20 satisfy the
# check and skip the install - the user then keeps the wrong major and
# every downstream tool that expects 22+ silently misbehaves.
$nodeMajorOk = $false
$nodeCurrentVersion = ""
if (Get-Command node -ErrorAction SilentlyContinue) {
    try {
        $nodeCurrentVersion = (& node --version 2>$null | Select-Object -First 1)
        if ($nodeCurrentVersion -match '^v(\d+)') {
            # [int] cast on the captured group - guards against a `node` shim
            # that prints garbage (e.g. an n / nvm wrapper that shells out
            # before printing). $matches[1] is only populated on a regex hit,
            # so the -match gate above is the safety net.
            $nodeMajor = [int]$matches[1]
            if ($nodeMajor -ge 22) { $nodeMajorOk = $true }
        }
    } catch {
        $nodeMajorOk = $false
    }
}
if (-not $nodeMajorOk) {
    # Gate the upgrade attempt on winget availability. Without this gate, an
    # environment where winget is missing (corporate Group Policy, Windows
    # Server CI runners) would print a noisy FAILURE box for Node.js even
    # though there is a usable older Node already on PATH. Pre-polish, the
    # script silently kept whatever Node was present; preserve that fallback.
    if (-not $hasWinget) {
        if ($nodeCurrentVersion) {
            Write-Host "[2/8] Node.js: detected $nodeCurrentVersion (older than LTS 22). winget is not available, so the upgrade can't run automatically. Keeping the current version. To upgrade manually, install winget (Microsoft Store > 'App Installer') and re-run, or download Node 22+ from https://nodejs.org/." -ForegroundColor Yellow
        } elseif ($env:ELNORA_SKIP_OPTIONAL_INSTALLS -eq "1") {
            # CI smoke test on a winget-less runner. Skipped, not failed -
            # see the matching pre-check at the top of the script.
            Write-Host "[2/8] Node.js: ELNORA_SKIP_OPTIONAL_INSTALLS=1 and winget unavailable - skipping." -ForegroundColor Gray
        } else {
            Write-Host "[2/8] Node.js not found and winget is not available. Install Node 22+ manually from https://nodejs.org/ and re-run this script." -ForegroundColor Red
            [void]$FailedSteps.Add("Node.js (winget unavailable, no fallback)")
        }
    } else {
        if ($nodeCurrentVersion) {
            Write-Host "[2/8] Detected Node $nodeCurrentVersion, upgrading to Node 22 LTS..." -ForegroundColor Yellow
        } else {
            Write-Host "[2/8] Installing Node.js 22 LTS..." -ForegroundColor Green
        }
        # Pin to Node 22.x -- the `OpenJS.NodeJS.LTS` alias rolls forward
        # past 22 in winget's catalog, which left mac (`brew install
        # node@22`) and Windows on different majors after the same
        # installer. Use `OpenJS.NodeJS` (the major-tracked package)
        # instead -- it carries every patchline of every major, so we
        # can hold to 22.x.
        #
        # winget catalog rolls specific patchline manifests off after a
        # few months. Hardcoding `--version 22.22.2` worked once and
        # then silently broke in CI when 22.22.2 aged out. Look up the
        # latest 22.x currently in the catalog at install time so the
        # script stays self-healing as Node 22 ages forward, with a
        # safety net fallback to LTS if 22.x is gone entirely (Node 22
        # ages out of LTS April 2027 -- by then mac side wants the
        # next LTS major too).
        # Why direct MSI download instead of winget for Node 22?
        #
        # Iter3 CI proved that winget cannot install Node 22.x on the
        # GitHub Actions windows-latest runner: `winget show --versions`
        # returns 28 versions but they are all the "Current" channel
        # (24.x / 25.x) -- the runner's winget local catalog simply
        # does not carry 22.x manifests, even though microsoft/winget
        # -pkgs has them on disk. So `winget install --id OpenJS.NodeJS
        # --version 22.22.2` exits -1978335209 ("No version found
        # matching") regardless of how cleanly we resolve the version
        # number. Using the OpenJS.NodeJS.LTS alias works but installs
        # Node 24, breaking the mac-side parity (brew node@22 = 22.22.2).
        #
        # nodejs.org always serves every released patchline as a direct
        # MSI download. Use that as the primary install path -- it
        # cannot age off, cannot be filtered by a runner-side catalog
        # snapshot, and matches the exact version string we resolve
        # from winget-pkgs.
        #
        # Bump $nodeWinPreferred in lockstep with whatever `brew info
        # node@22` reports as the current bottle. When Node 22 ages out
        # of LTS (April 2027), flip the major here AND on the macOS side.
        $nodeWinPreferred = "22.22.2"
        $nodeWinVersion = $null
        $nodeWinSource  = $null

        # ---- Resolve target version (winget-pkgs is source of truth) ----
        # Two-step: try canonical pin first (fast path, single API call),
        # then list the per-major directory to find the latest 22.x.
        Write-Host "  Resolving Node 22.x via winget-pkgs..." -ForegroundColor Gray
        try {
            $resp = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/o/OpenJS/NodeJS/22/$nodeWinPreferred" -UseBasicParsing -TimeoutSec 30
            if ($resp) {
                $nodeWinVersion = $nodeWinPreferred
                $nodeWinSource  = "canonical pin in winget-pkgs"
            }
        } catch {
            Write-Host "  Canonical pin $nodeWinPreferred not in winget-pkgs ($($_.Exception.Message)); finding latest 22.x..." -ForegroundColor DarkGray
        }
        if (-not $nodeWinVersion) {
            try {
                $resp = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/o/OpenJS/NodeJS/22" -UseBasicParsing -TimeoutSec 30
                $latest22 = $resp |
                    Where-Object { $_.type -eq 'dir' -and $_.name -match '^22\.\d+\.\d+$' } |
                    ForEach-Object { $_.name } |
                    Sort-Object -Property { [Version]$_ } -Descending |
                    Select-Object -First 1
                if ($latest22) {
                    $nodeWinVersion = $latest22
                    $nodeWinSource  = "latest 22.x in winget-pkgs"
                }
            } catch {
                Write-Host "  winget-pkgs latest-22.x query failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }

        # ---- Install: direct MSI from nodejs.org, with LTS-alias fallback ----
        if ($nodeWinVersion) {
            $msiUrl  = "https://nodejs.org/dist/v$nodeWinVersion/node-v$nodeWinVersion-x64.msi"
            $msiPath = Join-Path $env:TEMP "node-v$nodeWinVersion-x64.msi"
            Write-Host "  Installing Node $nodeWinVersion via direct MSI download [$nodeWinSource]" -ForegroundColor Gray
            Write-Host "  $msiUrl" -ForegroundColor DarkGray
            Invoke-Step "Node.js" {
                Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath -UseBasicParsing -TimeoutSec 300
                # /qn = quiet, no UI; /norestart = don't auto-reboot if msi
                # asks. Wait for the process so $LASTEXITCODE reflects the
                # install result rather than just the launch.
                $proc = Start-Process -Wait -PassThru -FilePath msiexec -ArgumentList @('/i', "`"$msiPath`"", '/qn', '/norestart')
                if ($proc.ExitCode -ne 0) { throw "msiexec exited $($proc.ExitCode)" }
                Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
            }
        } else {
            Write-Host "  WARNING: could not resolve any Node 22.x version via winget-pkgs;" -ForegroundColor Yellow
            Write-Host "  WARNING: falling back to OpenJS.NodeJS.LTS alias (may install a different major; mac/win Node parity will break)." -ForegroundColor Yellow
            Invoke-Step "Node.js" { winget install --id OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements --disable-interactivity --silent } -SuppressPattern $wingetNoisePattern
        }
        Update-SessionPath
    }
} else {
    Write-Host "[2/8] Node.js already installed: $nodeCurrentVersion. Skipping." -ForegroundColor Gray
}

# --- [2b/8] Codex CLI (after Node - the npm package needs it) ---
# Codex ships a native installer for macOS/Linux only; on Windows the supported
# path is the npm package, so this runs after Node above rather than first.
if (Test-AgentInstalled 'codex') {
    # Pick up a just-installed Node so `npm` resolves without a new terminal.
    Update-SessionPath
    if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
        if (Get-Command npm -ErrorAction SilentlyContinue) {
            Write-Host "[2b/8] Installing Codex (npm -g @openai/codex)..." -ForegroundColor Green
            Invoke-Step "Codex" { npm install -g @openai/codex }
            Update-SessionPath
            if (Get-Command codex -ErrorAction SilentlyContinue) {
                Write-Host "  Done. Version: $(codex --version 2>$null)" -ForegroundColor Gray
            }
        } else {
            Write-Host "[2b/8] Codex needs Node/npm, which isn't on PATH yet." -ForegroundColor Red
            Write-Host "      Open a new terminal (so the Node PATH refresh applies) and re-run," -ForegroundColor Yellow
            Write-Host "      or install manually:  npm install -g @openai/codex" -ForegroundColor Yellow
            [void]$FailedSteps.Add("Codex (npm unavailable)")
        }
    } else {
        Write-Host "[2b/8] Codex already installed: $(codex --version). Skipping." -ForegroundColor Gray
    }
}

# --- [3/8] Git + user config ---
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    if (-not $hasWinget -and $env:ELNORA_SKIP_OPTIONAL_INSTALLS -eq "1") {
        # CI smoke test on a winget-less runner - documented soft skip.
        Write-Host "[3/8] Git: ELNORA_SKIP_OPTIONAL_INSTALLS=1 and winget unavailable - skipping." -ForegroundColor Gray
    } else {
        Write-Host "[3/8] Installing Git..." -ForegroundColor Green
        Invoke-Step "Git" { winget install Git.Git --accept-package-agreements --accept-source-agreements --disable-interactivity --silent } -SuppressPattern $wingetNoisePattern
        Update-SessionPath
    }
} else {
    Write-Host "[3/8] Git already installed: $(git --version). Skipping." -ForegroundColor Gray
}

if (Get-Command git -ErrorAction SilentlyContinue) {
    try {
        $gitName  = git config --global user.name
        $gitEmail = git config --global user.email
        # `git config --global <key>` exits 1 when the key is unset. Reset
        # $LASTEXITCODE so the stale 1 doesn't bleed into Invoke-Step's
        # success check for a subsequent scriptblock that doesn't itself
        # set $LASTEXITCODE (pure PS cmdlets don't update it).
        $global:LASTEXITCODE = 0
        if (-not $gitName) {
            $gitName = Read-Host "  Enter your full name for git commits"
            if ($gitName) {
                git config --global user.name "$gitName"
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "  [!] 'git config --global user.name' failed (exit $LASTEXITCODE)." -ForegroundColor Red
                    Write-Host "      Run manually: git config --global user.name `"$gitName`"" -ForegroundColor Red
                    [void]$FailedSteps.Add("Git config (user.name)")
                    $global:LASTEXITCODE = 0
                }
            }
        }
        if (-not $gitEmail) {
            $gitEmail = Read-Host "  Enter your email for git commits"
            if ($gitEmail) {
                git config --global user.email "$gitEmail"
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "  [!] 'git config --global user.email' failed (exit $LASTEXITCODE)." -ForegroundColor Red
                    Write-Host "      Run manually: git config --global user.email `"$gitEmail`"" -ForegroundColor Red
                    [void]$FailedSteps.Add("Git config (user.email)")
                    $global:LASTEXITCODE = 0
                }
            }
        }
        Write-Host "  git user: $(git config --global user.name) <$(git config --global user.email)>" -ForegroundColor Gray
        $defBranch = git config --global init.defaultBranch
        if (-not $defBranch) { git config --global init.defaultBranch main; Write-Host "  git init.defaultBranch: main" -ForegroundColor Gray }
    } catch {
        Write-StepFailure -Label "Git config" -ExitCode -1 `
            -Command "git config --global ..." -ErrorOutput $_.Exception.Message
        [void]$FailedSteps.Add("Git config ($($_.Exception.Message))")
    }
} else {
    Write-Host "  [!] git not available - skipping git config." -ForegroundColor Red
    Write-Host "      See the Git remediation in the recap at the end of this run." -ForegroundColor Red
}

# --- [4/8] Python 3.12 ---
# Test-RealPython rejects the Microsoft Store stub alias - Get-Command alone
# would return a false positive on a fresh Windows laptop.
if (-not (Test-RealPython)) {
    if (-not $hasWinget -and $env:ELNORA_SKIP_OPTIONAL_INSTALLS -eq "1") {
        # CI smoke test on a winget-less runner - documented soft skip.
        Write-Host "[4/8] Python 3.12: ELNORA_SKIP_OPTIONAL_INSTALLS=1 and winget unavailable - skipping." -ForegroundColor Gray
    } else {
        Write-Host "[4/8] Installing Python 3.12..." -ForegroundColor Green
        # Remove the Store stub BEFORE install so winget's install doesn't get shadowed.
        [void](Remove-PythonStoreAlias)
        Invoke-Step "Python 3.12" { winget install Python.Python.3.12 --accept-package-agreements --accept-source-agreements --disable-interactivity --silent } -SuppressPattern $wingetNoisePattern
        Update-SessionPath
        # After install, if the Store stub is still intercepting (winget added a new
        # one, or PATH order is wrong), remove it and refresh PATH once more.
        if (-not (Test-RealPython)) {
            if (Remove-PythonStoreAlias) {
                Update-SessionPath
            }
            if (-not (Test-RealPython)) {
                # Python isn't a single binary - it depends on neighbouring DLLs -
                # so we can't use the WindowsApps copy trick. Tell the user how to
                # fix PATH manually, and point them at the py launcher as a fallback
                # (py.exe lives in C:\Windows and is always on Machine PATH).
                Write-Host ""
                Write-Host "  +-- FAILURE: Python 3.12 (PATH/alias issue)" -ForegroundColor Red
                Write-Host "  |   winget reported success, but 'python' still doesn't resolve" -ForegroundColor Red
                Write-Host "  |   to real Python in this shell." -ForegroundColor Red
                $pyCandidate = "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe"
                if (Test-Path $pyCandidate) {
                    Write-Host "  |" -ForegroundColor Red
                    Write-Host "  |   Real Python is at:  $pyCandidate" -ForegroundColor Red
                }
                $pyLauncher = "C:\Windows\py.exe"
                if (Test-Path $pyLauncher) {
                    Write-Host "  |   Py launcher is at:  $pyLauncher  (always on PATH)" -ForegroundColor Red
                }
                Write-Host "  |" -ForegroundColor Red
                Write-Host "  |   What to do:" -ForegroundColor Yellow
                foreach ($line in ((Get-RemediationHint -Label "Python 3.12") -split "`r?`n")) {
                    Write-Host "  |     $line" -ForegroundColor Yellow
                }
                Write-Host "  +-----------------------------------------------------------" -ForegroundColor Red
                Write-Host ""
                [void]$FailedSteps.Add("Python 3.12 (PATH/alias issue)")
            }
        }
    }
} else {
    Write-Host "[4/8] Python already installed: $(python --version). Skipping." -ForegroundColor Gray
}

# --- [5/8] VS Code ---
$codePaths = @(
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
    "$env:ProgramFiles\Microsoft VS Code\Code.exe",
    "${env:ProgramFiles(x86)}\Microsoft VS Code\Code.exe"
)
$codeInstalled = (Get-Command code -ErrorAction SilentlyContinue) -or ($codePaths | Where-Object { Test-Path $_ } | Select-Object -First 1)
if ($env:ELNORA_SKIP_OPTIONAL_INSTALLS -eq "1") {
    # CI/test escape hatch: skip optional editor on environments where winget
    # isn't available (windows-2022/2025 GitHub Actions runners). Used by
    # .github/workflows/install-smoke-test.yml so the smoke test validates
    # the core path (Claude Code + Group Policy fallback)
    # without false-positive FAILUREs for components that need winget on a
    # Server SKU. Real Win10/11 attendees never set this variable.
    Write-Host "[5/8] VS Code: ELNORA_SKIP_OPTIONAL_INSTALLS=1 - skipping for non-interactive run." -ForegroundColor Gray
} elseif (-not $codeInstalled) {
    Write-Host "[5/8] Installing VS Code..." -ForegroundColor Green
    Invoke-Step "VS Code" { winget install Microsoft.VisualStudioCode --accept-package-agreements --accept-source-agreements --disable-interactivity --silent } -SuppressPattern $wingetNoisePattern
    Update-SessionPath
} else {
    Write-Host "[5/8] VS Code already installed. Skipping." -ForegroundColor Gray
}

# --- [6/8] GitHub CLI ---
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    if (-not $hasWinget -and $env:ELNORA_SKIP_OPTIONAL_INSTALLS -eq "1") {
        # CI smoke test on a winget-less runner - documented soft skip.
        Write-Host "[6/8] GitHub CLI: ELNORA_SKIP_OPTIONAL_INSTALLS=1 and winget unavailable - skipping." -ForegroundColor Gray
    } else {
        Write-Host "[6/8] Installing GitHub CLI..." -ForegroundColor Green
        Invoke-Step "GitHub CLI" { winget install --id GitHub.cli --accept-package-agreements --accept-source-agreements --disable-interactivity --silent } -SuppressPattern $wingetNoisePattern
        Update-SessionPath

        # gh is a standalone Go binary - safe to copy to WindowsApps as a PATH
        # fallback if the User/Machine PATH update didn't stick (GP, or new session
        # env not refreshed in time).
        if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
            $ghCandidates = @(
                "$env:ProgramFiles\GitHub CLI\gh.exe",
                "${env:ProgramFiles(x86)}\GitHub CLI\gh.exe",
                "$env:LOCALAPPDATA\Programs\GitHub CLI\gh.exe"
            )
            $ghExe = $ghCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
            if ($ghExe) {
                Write-Host "  [!] gh installed to $ghExe but not on PATH - applying WindowsApps fallback." -ForegroundColor Yellow
                if (-not (Copy-StandaloneExeToWindowsApps -ExePath $ghExe -ToolName "gh")) {
                    [void]$FailedSteps.Add("GitHub CLI PATH")
                }
            } else {
                Write-Host "  [!] gh reported installed by winget but not found in the usual locations." -ForegroundColor Red
                Write-Host "      Check with: winget list --id GitHub.cli --exact" -ForegroundColor Red
                Write-Host "      Or reinstall: winget install --id GitHub.cli" -ForegroundColor Red
                [void]$FailedSteps.Add("GitHub CLI (binary not found after install)")
            }
        }
    }
} else {
    Write-Host "[6/8] GitHub CLI already installed: $(gh --version | Select-Object -First 1). Skipping." -ForegroundColor Gray
}

# --- [7/8] Obsidian (optional - knowledge base) ---
$obsidianPaths = @(
    "$env:LOCALAPPDATA\Obsidian\Obsidian.exe",
    "$env:LOCALAPPDATA\Programs\Obsidian\Obsidian.exe",
    "$env:APPDATA\Obsidian\Obsidian.exe",
    "$env:ProgramFiles\Obsidian\Obsidian.exe",
    "${env:ProgramFiles(x86)}\Obsidian\Obsidian.exe"
)
$obsidianInstalled = [bool]($obsidianPaths | Where-Object { Test-Path $_ } | Select-Object -First 1)
if (-not $obsidianInstalled -and $hasWinget) {
    # Fall back to winget - catches installs in non-standard locations. Gated
    # on $hasWinget so that on machines without winget (some Win10 builds, the
    # GitHub Actions windows-2022 runner), this doesn't surface a raw "term not
    # recognized" error to stderr and confuse the user.
    $wingetHas = winget list --id Obsidian.Obsidian --exact 2>$null | Select-String "Obsidian.Obsidian"
    if ($wingetHas) { $obsidianInstalled = $true }
}
if ($env:ELNORA_SKIP_OPTIONAL_INSTALLS -eq "1") {
    # See matching comment on the VS Code step above.
    Write-Host "[7/8] Obsidian: ELNORA_SKIP_OPTIONAL_INSTALLS=1 - skipping for non-interactive run." -ForegroundColor Gray
} elseif (-not $obsidianInstalled) {
    Write-Host "[7/8] Installing Obsidian (optional)..." -ForegroundColor Green
    Invoke-Step "Obsidian" { winget install Obsidian.Obsidian --accept-package-agreements --accept-source-agreements --disable-interactivity --silent } -SuppressPattern $wingetNoisePattern
    Update-SessionPath
} else {
    Write-Host "[7/8] Obsidian already installed. Skipping." -ForegroundColor Gray
}

# --- [8/8] Projects folder ---
$projectsDir = "$env:USERPROFILE\Documents\Projects"
if (-not (Test-Path $projectsDir)) {
    Write-Host "[8/8] Creating Projects folder at $projectsDir..." -ForegroundColor Green
    try {
        New-Item -ItemType Directory -Path $projectsDir -ErrorAction Stop | Out-Null
        Write-Host "  Done." -ForegroundColor Yellow
    } catch {
        Write-StepFailure -Label "Projects folder" -ExitCode -1 `
            -Command "New-Item -ItemType Directory -Path $projectsDir" `
            -ErrorOutput $_.Exception.Message
        [void]$FailedSteps.Add("Projects folder")
    }
} else {
    Write-Host "[8/8] Projects folder already exists. Skipping." -ForegroundColor Gray
}

# --- chrome-devtools MCP override (Windows-only) ---
# The committed .mcp.json uses bare `npx`, which a stdio MCP host can't
# resolve cleanly on Windows. Write a user-level ~/.claude/.mcp.json that
# wraps the same command in `cmd /c`, so the chrome-devtools server spawns
# correctly. User-level config overrides project-level for this user only;
# macOS / Linux teammates who clone the same repo are unaffected.
# See docs/chrome-devtools-mcp-setup.md for the full picture.
$claudeConfigDir = Join-Path $env:USERPROFILE ".claude"
$mcpConfigPath = Join-Path $claudeConfigDir ".mcp.json"
if (-not (Test-Path $claudeConfigDir)) {
    New-Item -ItemType Directory -Path $claudeConfigDir -Force | Out-Null
}
$cdtBlock = [pscustomobject]@{
    type    = "stdio"
    command = "cmd"
    args    = @("/c", "npx", "chrome-devtools-mcp@latest", "--autoConnect")
}
# BOM-less UTF-8 writer. Out-File / Set-Content with -Encoding utf8 on Windows
# PowerShell 5.1 prepends a UTF-8 BOM (EF BB BF), and Node's JSON.parse -- which
# is what Claude Code's MCP host uses -- rejects BOM-prefixed JSON. PS 7 already
# defaults to BOM-less, so this stays correct on both.
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
try {
    if (Test-Path $mcpConfigPath) {
        # Merge: only touch the chrome-devtools entry, leave other servers alone.
        $existing = Get-Content $mcpConfigPath -Raw | ConvertFrom-Json
        if (-not $existing.mcpServers) {
            $existing | Add-Member -NotePropertyName mcpServers -NotePropertyValue ([pscustomobject]@{}) -Force
        }
        $existing.mcpServers | Add-Member -NotePropertyName "chrome-devtools" -NotePropertyValue $cdtBlock -Force
        $json = $existing | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($mcpConfigPath, $json, $utf8NoBom)
        Write-Host "[OK] Updated $mcpConfigPath with chrome-devtools (cmd /c npx) override" -ForegroundColor Green
    } else {
        $newConfig = [pscustomobject]@{
            mcpServers = [pscustomobject]@{ "chrome-devtools" = $cdtBlock }
        }
        $json = $newConfig | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($mcpConfigPath, $json, $utf8NoBom)
        Write-Host "[OK] Created $mcpConfigPath with chrome-devtools (cmd /c npx) override" -ForegroundColor Green
    }
} catch {
    Write-Host "[WARN] Could not write chrome-devtools override to $mcpConfigPath - $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "       chrome-devtools MCP may not work until you fix this manually." -ForegroundColor Yellow
    Write-Host "       See docs/chrome-devtools-mcp-setup.md for the expected file shape." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==========================================="
Write-Host "  Install summary"
Write-Host "==========================================="
Write-Host ""
Update-SessionPath

# Force UTF-8 output so the unicode check / cross marks render. PS 5.1 defaults
# to OEM codepage which mangles them - without this, the check-mark glyph
# shows as garbled bytes in the very summary row that's supposed to scream
# "all good". Note: we keep the glyphs out of this source file (see [char]
# escapes below) and only emit them at runtime, so the script itself stays
# pure ASCII and survives PS 5.1's BOM-less ANSI script parsing.
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

function Get-ToolVersion {
    param([string]$Name, [string]$VersionArg = "--version")
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $cmd) { return "" }
    try {
        $out = & $Name $VersionArg 2>$null | Select-Object -First 1
        if ($out) { return $out } else { return "installed" }
    } catch {
        return "installed"
    }
}

function Get-AppInstalled {
    param([string]$Path, [string]$Label)
    if (Test-Path $Path) {
        try {
            $v = (Get-Item $Path).VersionInfo.ProductVersion
            if ($v) { return "installed ($v)" } else { return "installed" }
        } catch { return "installed" }
    } else {
        return ""
    }
}

# Write-Status "<label>" "<version-or-empty>"
# Empty / "not found" version  => red [X] NOT INSTALLED
# Sentinel "__SKIPPED_OPTIONAL" => gray [-] skipped (optional, env flag)
# Anything else                 => green [OK] <version>
#
# The skipped-optional state is only set when ELNORA_SKIP_OPTIONAL_INSTALLS=1
# (CI smoke test) caused the install step itself to be skipped AND the tool
# isn't already on disk - so the tool genuinely isn't installed, but it's
# not a failure either. Without the third state, those rows print as
# alarming red NOT INSTALLED markers identical to a real failure.
function Write-Status {
    param([string]$Label, [string]$Version)
    $padded = ($Label + ":").PadRight(13)
    if ($Version -eq "__SKIPPED_OPTIONAL") {
        Write-Host "  " -NoNewline
        Write-Host "-" -ForegroundColor DarkGray -NoNewline
        Write-Host " $padded " -NoNewline
        Write-Host "skipped (optional, env flag)" -ForegroundColor DarkGray
    } elseif (-not $Version -or $Version -eq "not found") {
        Write-Host "  " -NoNewline
        Write-Host ([char]0x2717) -ForegroundColor Red -NoNewline   # cross mark
        Write-Host " $padded " -NoNewline
        Write-Host "NOT INSTALLED" -ForegroundColor Red
    } else {
        Write-Host "  " -NoNewline
        Write-Host ([char]0x2713) -ForegroundColor Green -NoNewline  # check mark
        Write-Host " $padded " -NoNewline
        Write-Host $Version -ForegroundColor Green
    }
}

# Compute every tool's version up-front so the summary AND the headline use the
# same data. Storing in an ordered dict keeps output order stable.
#
# When ELNORA_SKIP_OPTIONAL_INSTALLS=1 AND winget is missing (windows-2022 CI
# runners), the install loop above deliberately skipped Node.js / Git /
# Python / GitHub CLI without recording a FAILURE. Reflect that in the
# summary as "skipped (optional, env flag)" instead of red NOT INSTALLED so
# the recap headline ("All N installed") stays accurate.
$ciSkipMissingWinget = ($env:ELNORA_SKIP_OPTIONAL_INSTALLS -eq "1" -and -not $hasWinget)

$results = [ordered]@{}
$nodeVer = Get-ToolVersion 'node'
if (-not $nodeVer -and $ciSkipMissingWinget) { $nodeVer = "__SKIPPED_OPTIONAL" }
$results["Node.js"]     = $nodeVer

$gitVer = Get-ToolVersion 'git'
if (-not $gitVer -and $ciSkipMissingWinget) { $gitVer = "__SKIPPED_OPTIONAL" }
$results["Git"]         = $gitVer

$pythonVer = Get-ToolVersion 'python'
if (-not $pythonVer -and $ciSkipMissingWinget) { $pythonVer = "__SKIPPED_OPTIONAL" }
$results["Python"]      = $pythonVer

$vscodeExe = @(
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
    "$env:ProgramFiles\Microsoft VS Code\Code.exe",
    "${env:ProgramFiles(x86)}\Microsoft VS Code\Code.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($vscodeExe) {
    $results["VS Code"] = Get-AppInstalled $vscodeExe 'VS Code'
} else {
    $codeVer = Get-ToolVersion 'code'
    if (-not $codeVer -and $env:ELNORA_SKIP_OPTIONAL_INSTALLS -eq "1") {
        $results["VS Code"] = "__SKIPPED_OPTIONAL"
    } else {
        $results["VS Code"] = $codeVer
    }
}

# Only show the agent row(s) the user actually chose to install, so a Codex-only
# run never reports a phantom "Claude Code NOT INSTALLED" (and vice versa).
if (Test-AgentInstalled 'claude') { $results["Claude Code"] = Get-ToolVersion 'claude' }
if (Test-AgentInstalled 'codex')  { $results["Codex"]       = Get-ToolVersion 'codex' }

$ghVer = Get-ToolVersion 'gh'
if (-not $ghVer -and $ciSkipMissingWinget) { $ghVer = "__SKIPPED_OPTIONAL" }
$results["GitHub CLI"]  = $ghVer

$obsidianExe = @(
    "$env:LOCALAPPDATA\Obsidian\Obsidian.exe",
    "$env:LOCALAPPDATA\Programs\Obsidian\Obsidian.exe",
    "$env:APPDATA\Obsidian\Obsidian.exe",
    "$env:ProgramFiles\Obsidian\Obsidian.exe",
    "${env:ProgramFiles(x86)}\Obsidian\Obsidian.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($obsidianExe) {
    $results["Obsidian"] = Get-AppInstalled $obsidianExe 'Obsidian'
} else {
    $wingetHas = $null
    if ($hasWinget) {
        $wingetHas = winget list --id Obsidian.Obsidian --exact 2>$null | Select-String "Obsidian.Obsidian"
    }
    if ($wingetHas) {
        $results["Obsidian"] = "installed (winget)"
    } elseif ($env:ELNORA_SKIP_OPTIONAL_INSTALLS -eq "1") {
        $results["Obsidian"] = "__SKIPPED_OPTIONAL"
    } else {
        $results["Obsidian"] = ""
    }
}

foreach ($key in $results.Keys) {
    Write-Status $key $results[$key]
}

# A "skipped optional" row is neither installed nor missing - it's a
# deliberate non-event in CI. Exclude it from both counters so the headline
# tells the truth ("All N installed" remains accurate when CI skipped the
# optional editor / vault).
$missing = @($results.GetEnumerator() | Where-Object { -not $_.Value -or $_.Value -eq "not found" }).Count
$skippedOptional = @($results.GetEnumerator() | Where-Object { $_.Value -eq "__SKIPPED_OPTIONAL" }).Count
$total   = $results.Count - $skippedOptional
Write-Host ""
if ($missing -eq 0) {
    if ($skippedOptional -gt 0) {
        Write-Host "  All $total required components installed ($skippedOptional optional skipped)." -ForegroundColor Green
    } else {
        Write-Host "  All $total components installed." -ForegroundColor Green
    }
} else {
    Write-Host "  $missing component(s) NOT installed - see red X rows above and remediation below." -ForegroundColor Red
    Write-Host "  If something says NOT INSTALLED but you think it is, open a new PowerShell/VS Code window and re-check."
}
Write-Host ""
Write-Host ""
# VS Code reminder banner. Bright yellow box with blank lines above and below
# so the "quit fully" rule reads as a separate section, not as another summary
# row. Real users on workshops have walked past this in plain-text form and
# wondered why their newly-installed `claude` command wasn't
# visible in the VS Code integrated terminal - the answer is always that
# VS Code cached its PATH at launch time.
Write-Host "  +============================================================+" -ForegroundColor Yellow
Write-Host "  |                                                            |" -ForegroundColor Yellow
Write-Host "  |   IMPORTANT - to see the new PATH in VS Code:              |" -ForegroundColor Yellow
Write-Host "  |                                                            |" -ForegroundColor Yellow
Write-Host "  |   Quit VS Code FULLY (File -> Exit), then reopen it.       |" -ForegroundColor Yellow
Write-Host "  |   Closing just the terminal panel is not enough -          |" -ForegroundColor Yellow
Write-Host "  |   VS Code caches its PATH at app launch time.              |" -ForegroundColor Yellow
Write-Host "  |                                                            |" -ForegroundColor Yellow
Write-Host "  +============================================================+" -ForegroundColor Yellow
Write-Host ""
Write-Host ""

if ($FailedSteps.Count -gt 0) {
    Write-Host "==========================================="
    Write-Host "  $($FailedSteps.Count) step(s) failed - remediation below"
    Write-Host "==========================================="
    foreach ($stepEntry in $FailedSteps) {
        # Strip trailing "(exit N)" / "(message)" to recover the bare label for lookup.
        $stepLabel = ($stepEntry -replace '\s*\([^)]*\)\s*$', '').Trim()
        if (-not $stepLabel) { $stepLabel = $stepEntry }
        Write-Host ""
        Write-Host "-- $stepEntry --"
        $hint = Get-RemediationHint -Label $stepLabel
        foreach ($line in ($hint -split "`r?`n")) {
            Write-Host "  $line"
        }
    }
    Write-Host ""
    Write-Host "Once you've fixed the issue(s), re-run:  .\setup-windows.ps1"
    Write-Host "The script is idempotent - already-installed steps are skipped."
    Write-Host "==========================================="
    Write-Host ""
}

Write-Host "==========================================="
Write-Host "  Authenticating services"
Write-Host "==========================================="
Write-Host ""

# Bypass entire auth section in CI / non-interactive modes
if ($env:ELNORA_SKIP_HANDOFF -eq "1" -or $env:ELNORA_HANDOFF_MODE -eq "headless") {
    Write-Host "  (Skipped -- non-interactive run.)"
    Write-Host ""
} else {
    # ---- Handoff-agent auth ----
    # Only the agent that finishes Phase 2 ($HandoffAgent) must be signed in
    # here. If both were installed, the other signs in on its own first launch.
    if ($HandoffAgent -eq 'codex') {
    Write-Host "[1/2] Codex"
    $codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
    if (($env:OPENAI_API_KEY -or $env:CODEX_API_KEY) -and -not (Test-Path -LiteralPath (Join-Path $codexHome 'auth.json'))) {
        # Codex does not pick these env vars up implicitly (CODEX_API_KEY is
        # honored by `codex exec` only) -- persist a real login so the
        # interactive session that follows actually authenticates.
        $apiKey = if ($env:OPENAI_API_KEY) { $env:OPENAI_API_KEY } else { $env:CODEX_API_KEY }
        $apiKey | codex login --with-api-key *> $null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "      OPENAI_API_KEY/CODEX_API_KEY set -- logged in with API key."
            Set-Checkpoint "auth-codex"
        } else {
            Write-Host "      [WARN] API-key login failed -- Codex will prompt on first launch."
        }
        $global:LASTEXITCODE = 0
    } elseif (Test-Path -LiteralPath (Join-Path $codexHome 'auth.json')) {
        Write-Host "      [OK] Already signed in."
        Set-Checkpoint "auth-codex"
    } else {
        Write-Host "      Not signed in. A browser will open so you can sign in to ChatGPT."
        Write-Host "      [Y]es / [s]kip+continue without Codex / [q]uit script"
        $answer = Read-Host "      >"
        if ([string]::IsNullOrWhiteSpace($answer)) { $answer = "Y" }
        switch -Regex ($answer) {
            "^[Yy]" {
                codex login
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "      [FAIL] Codex sign-in didn't complete."
                    Write-Host ""
                    Write-Host "         Nothing is lost. When you're ready, run again:"
                    Write-Host ""
                    Write-Host "             .\setup-windows.ps1"
                    Write-Host ""
                    Write-Host "         To try the login by hand first:  codex login"
                    exit 1
                }
                Write-Host "      [OK] Signed in."
                Set-Checkpoint "auth-codex"
            }
            "^[Ss]" {
                Write-Host "      [SKIP] Phase 2 needs a signed-in agent. Re-run when ready:  .\setup-windows.ps1"
                exit 0
            }
            "^[Qq]" {
                Write-Host "      Quit. Re-run anytime:  .\setup-windows.ps1"
                exit 0
            }
            default {
                Write-Host "      Unrecognized response, treating as skip."
                exit 0
            }
        }
    }
    } else {
    # ---- Claude auth ----
    Write-Host "[1/2] Claude Code"
    if ($env:ANTHROPIC_API_KEY) {
        Write-Host "      ANTHROPIC_API_KEY set -- using API key, skipping OAuth."
    } else {
        $claudeStatus = claude auth status --json 2>$null
        if ($claudeStatus -match '"loggedIn"\s*:\s*true') {
            $emailMatch = [regex]::Match($claudeStatus, '"email"\s*:\s*"([^"]+)"')
            $email = if ($emailMatch.Success) { $emailMatch.Groups[1].Value } else { "unknown" }
            Write-Host "      [OK] Already logged in as $email"
            Set-Checkpoint "auth-claude"
        } else {
            Write-Host "      Not logged in. A browser will open so you can sign in."
            Write-Host "      [Y]es / [s]kip+continue without Claude / [q]uit script"
            $answer = Read-Host "      >"
            if ([string]::IsNullOrWhiteSpace($answer)) { $answer = "Y" }
            switch -Regex ($answer) {
                "^[Yy]" {
                    claude auth login --claudeai
                    if ($LASTEXITCODE -ne 0) {
                        Write-Host "      [FAIL] Claude sign-in didn't complete."
                        Write-Host ""
                        Write-Host "         This is the most common place setup stops. Nothing is lost."
                        Write-Host "         When you're ready, run the SAME command again:"
                        Write-Host ""
                        Write-Host "             .\setup-windows.ps1"
                        Write-Host ""
                        Write-Host "         It resumes right here at the Claude sign-in step - every"
                        Write-Host "         tool above is already installed and is skipped instantly."
                        exit 1
                    }
                    $recheck = claude auth status --json 2>$null
                    if ($recheck -notmatch '"loggedIn"\s*:\s*true') {
                        Write-Host "      [FAIL] Login flow returned but you are still not signed in."
                        Write-Host ""
                        Write-Host "         This is the most common place setup stops. Nothing is lost."
                        Write-Host "         When you're ready, run the SAME command again:"
                        Write-Host ""
                        Write-Host "             .\setup-windows.ps1"
                        Write-Host ""
                        Write-Host "         It resumes right here at the Claude sign-in step - every"
                        Write-Host "         tool above is already installed and is skipped instantly."
                        Write-Host "         To try the login by hand first:  claude auth login --claudeai"
                        exit 1
                    }
                    Write-Host "      [OK] Logged in."
                    Set-Checkpoint "auth-claude"
                }
                "^[Ss]" {
                    # Use the live working directory for the resume hint -- the
                    # user picked their workspace name in install.ps1, so the
                    # folder is no longer guaranteed to be Documents\elnora-ai-agent-hackathon-starter-kit.
                    $kitDirDisplay = (Get-Location).Path
                    # OrdinalIgnoreCase: Windows paths are case-insensitive
                    # but PowerShell's String.StartsWith defaults to ordinal
                    # (case-sensitive). If $env:USERPROFILE casing differs
                    # from (Get-Location).Path casing — happens with mixed-
                    # case mount points or some PSReadLine setups — the
                    # default would silently no-op the collapse and the
                    # user would see the literal full path.
                    if ($kitDirDisplay.StartsWith($env:USERPROFILE, [System.StringComparison]::OrdinalIgnoreCase)) {
                        $kitDirDisplay = '$env:USERPROFILE' + $kitDirDisplay.Substring($env:USERPROFILE.Length)
                    }
                    # The ASCII box is 60 chars wide; the cd line carries 8
                    # chars of prefix ("  |     cd ") plus a 52-char field
                    # plus the trailing "|". {0,-52} pads short strings but
                    # does NOT truncate long ones, so a path > 52 chars
                    # would push the right border off the row. Pre-truncate
                    # with an ellipsis so the box stays aligned regardless
                    # of workspace name.
                    if ($kitDirDisplay.Length -gt 52) {
                        $kitDirDisplay = $kitDirDisplay.Substring(0, 49) + '...'
                    }
                    Write-Host ""
                    Write-Host "  +============================================================+"
                    Write-Host "  |                                                            |"
                    Write-Host "  |   You skipped Claude Code login.                           |"
                    Write-Host "  |                                                            |"
                    Write-Host "  |   That's fine - but Phase 2 (where Claude finishes setup)  |"
                    Write-Host "  |   needs an authenticated session, so we can't continue     |"
                    Write-Host "  |   right now.                                               |"
                    Write-Host "  |                                                            |"
                    Write-Host "  |   When you're ready:                                       |"
                    Write-Host "  |                                                            |"
                    Write-Host ("  |     cd {0,-52}|" -f $kitDirDisplay)
                    Write-Host "  |     .\setup-windows.ps1                                    |"
                    Write-Host "  |                                                            |"
                    Write-Host "  |   Re-running is safe - installs are skipped if already     |"
                    Write-Host "  |   present, and the script picks up at the auth step.       |"
                    Write-Host "  |                                                            |"
                    Write-Host "  +============================================================+"
                    Write-Host ""
                    exit 0
                }
                "^[Qq]" {
                    Write-Host "      Quit. Re-run anytime:  .\setup-windows.ps1"
                    exit 0
                }
                default {
                    Write-Host "      Unrecognized response, treating as skip."
                    exit 0
                }
            }
        }
    }
    }  # end handoff-agent auth (codex / claude branch)

    # When both agents were installed, the non-handoff one is optional here --
    # it prompts for sign-in on its own first launch. Just remind the user.
    if ($Agent -eq 'both') {
        if ($HandoffAgent -eq 'claude') {
            Write-Host "      Note: Codex is installed too -- sign in anytime with 'codex login'."
        } else {
            Write-Host "      Note: Claude Code is installed too -- sign in anytime with 'claude auth login --claudeai'."
        }
    }
    Write-Host ""

    # ---- GitHub auth ----
    Write-Host "[2/2] GitHub CLI"
    if ($env:GH_TOKEN -or $env:GITHUB_TOKEN) {
        Write-Host "      GH_TOKEN/GITHUB_TOKEN set -- skipping OAuth."
    } else {
        gh auth status 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $ghUser = (gh api user --jq .login 2>$null)
            if ([string]::IsNullOrWhiteSpace($ghUser)) { $ghUser = "unknown" }
            Write-Host "      [OK] Already logged in as $ghUser"
            Set-Checkpoint "auth-github"
        } else {
            Write-Host "      Not logged in. Phase 2 needs this to create your starter repo."
            Write-Host "      [Y]es / [s]kip (Phase 2 will prompt you again later)"
            $answer = Read-Host "      >"
            if ([string]::IsNullOrWhiteSpace($answer)) { $answer = "Y" }
            switch -Regex ($answer) {
                "^[Yy]" {
                    gh auth login --web --hostname github.com --git-protocol https
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "      [OK] Logged in."
                        Set-Checkpoint "auth-github"
                    } else {
                        Write-Host "      [WARN] Login didn't complete. Phase 2 will prompt you."
                    }
                }
                default {
                    Write-Host "      [SKIP] To do later:  gh auth login --web"
                }
            }
        }
    }
    Write-Host ""
}

Write-Host "==========================================="
Write-Host "  Quick PATH note"
Write-Host "==========================================="
Write-Host ""
Write-Host "  'claude' is at %USERPROFILE%\.local\bin\."
Write-Host "  - In any terminal opened AFTER this install: works automatically."
Write-Host "  - In a terminal opened BEFORE this install (rare):"
Write-Host "      `$env:Path = `"`$env:USERPROFILE\.local\bin;`$env:Path`""
Write-Host "    or just open a fresh PowerShell window."
Write-Host ""

Write-Host "==========================================="
Write-Host "  Phase 1 complete - handing off to Claude"
Write-Host "==========================================="
Write-Host ""

# CI integration: propagate the script's accumulated PATH to $env:GITHUB_PATH
# so subsequent workflow steps (handoff-e2e assertions, install-smoke-test
# verifications, bootstrap-e2e checks) see every binary Phase 1 installed.
# Without this, a fresh pwsh in the next step inherits the runner's job-
# start PATH snapshot, which doesn't include %USERPROFILE%\.local\bin
# (Claude) or anything winget added after job
# start. Update-SessionPath fixed this for the current process; this fixes
# it for downstream steps. No-op outside GH Actions (variable unset).
if ($env:GITHUB_PATH) {
    foreach ($dir in ($env:Path -split ';')) {
        if ($dir) { Add-Content -Path $env:GITHUB_PATH -Value $dir }
    }
    Write-Host "  (CI: propagated PATH to `$GITHUB_PATH for downstream steps)"
}

# Close the transcript before handing off, so the log file is flushed and
# Claude can read it as part of Phase 2.
try { Stop-Transcript | Out-Null } catch { }

# The exact prompt handed to Claude. Defined once so the headless test mode
# below uses byte-for-byte the same string as the production handoff -
# divergence here is the bug headless mode is supposed to catch.
$HandoffPrompt = "Phase 1 of the Elnora AI Agent Hackathon Starter Kit install just completed. Please read INSTALL_FOR_AGENTS.md in this directory and finish Phase 2 setup. The Phase 1 install log is at $env:USERPROFILE\claude-starter-install.log."

# Resolve the handoff agent's binary, display name, and first-run auth note.
if ($HandoffAgent -eq 'codex') {
    $agentBin  = 'codex'
    $agentName = 'Codex'
    $authNote  = "On first run, a browser may open so you can sign in to your ChatGPT (OpenAI) account."
} else {
    $agentBin  = 'claude'
    $agentName = 'Claude Code'
    $authNote  = "On first run, your browser will open to log into your Claude Pro/Max account."
}

$agentAvailable = Get-Command $agentBin -ErrorAction SilentlyContinue
if ($agentAvailable) {
    if ($env:ELNORA_SKIP_HANDOFF -eq "1") {
        # CI/test escape hatch: print what would happen and exit cleanly. Used
        # by .github/workflows/install-smoke-test.yml so the smoke test doesn't
        # hang on the agent trying to open a browser for first-run auth.
        # Echo the prompt itself so the smoke test has something to grep on.
        Write-Host "ELNORA_SKIP_HANDOFF=1 set - would hand off to $agentName with the Phase 2 prompt. Skipping for non-interactive run." -ForegroundColor Gray
        Write-Host "  Phase 2 prompt: $HandoffPrompt" -ForegroundColor Gray
        exit 0
    }

    # Verify INSTALL_FOR_AGENTS.md hasn't been tampered with since
    # install.ps1 extracted the zip. install.ps1 records the sha256 in
    # .elnora-ai-agent-hackathon-starter-kit-marker on fresh extract. If the file changed
    # post-extract, abort - the agent shouldn't be handed off to a doc we
    # didn't ship, especially when headless mode runs with bypassPermissions.
    #
    # Cases:
    #   1. Marker + matching hash -> proceed silently.
    #   2. Marker + mismatched hash -> exit 3, point user at the recovery.
    #   3. No marker (pre-existing install from before integrity markers
    #      shipped, or marker manually deleted) -> soft warn for the
    #      interactive handoff; refuse for headless mode where claude
    #      would run with bypassPermissions (see headless branch below).
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

    # ---- VS Code workspace + window restore -------------------------------
    # Two fixes for "I closed VS Code and it forgot which folder this was":
    #   1. Open a NAMED <workspace>.code-workspace instead of a bare folder, so
    #      it lands in File > Open Recent as one clear, re-openable entry.
    #   2. Set window.restoreWindows:"all" in the user's GLOBAL VS Code / Cursor
    #      settings so relaunching the app reopens this workspace automatically.
    # Both are best-effort: any failure must never break the handoff. Mirrors
    # ensure_vscode_workspace in setup-mac.sh (PowerShell JSON instead of
    # python3, since Windows has no guaranteed python3).
    $workspaceFile = Join-Path $scriptDir ("$(Split-Path -Leaf $scriptDir).code-workspace")
    function Initialize-VSCodeWorkspace {
        # 1. Named workspace file (idempotent: only write if missing).
        if (-not (Test-Path -LiteralPath $workspaceFile)) {
            $wsJson = @'
{
  "folders": [
    { "path": "." }
  ],
  "settings": {}
}
'@
            Set-Content -LiteralPath $workspaceFile -Value $wsJson -Encoding UTF8
        }

        # 2. Merge restoreWindows into global settings for installed editors.
        foreach ($app in @('Code', 'Code - Insiders', 'Cursor')) {
            $userDir = Join-Path $env:APPDATA (Join-Path $app 'User')
            # Only touch editors the user has actually launched (User dir
            # exists); don't fabricate settings for one that isn't installed.
            if (-not (Test-Path -LiteralPath $userDir)) { continue }
            $settings = Join-Path $userDir 'settings.json'
            try {
                $obj = $null
                if (Test-Path -LiteralPath $settings) {
                    $raw = Get-Content -LiteralPath $settings -Raw
                    if ([string]::IsNullOrWhiteSpace($raw)) {
                        $obj = [pscustomobject]@{}
                    } else {
                        # VS Code settings are JSONC. If comments/trailing
                        # commas make this throw, we fall to catch and leave the
                        # file ALONE rather than risk clobbering it.
                        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
                    }
                } else {
                    $obj = [pscustomobject]@{}
                }
                if (($obj.PSObject.Properties.Name -contains 'window.restoreWindows') -and ($obj.'window.restoreWindows' -eq 'all')) {
                    continue
                }
                $obj | Add-Member -NotePropertyName 'window.restoreWindows' -NotePropertyValue 'all' -Force
                $obj | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $settings -Encoding UTF8
            } catch {
                # Unparseable JSONC or write error -- never let it abort setup.
            }
        }
    }

    $markerFile = Join-Path $scriptDir ".elnora-ai-agent-hackathon-starter-kit-marker"
    $docFile = Join-Path $scriptDir "INSTALL_FOR_AGENTS.md"
    $markerMissing = $false
    if (Test-Path -LiteralPath $docFile) {
        if (Test-Path -LiteralPath $markerFile) {
            $markerLines = Get-Content -LiteralPath $markerFile
            $expectedSha = ""
            foreach ($line in $markerLines) {
                if ($line -match '^\s*install_for_agents_sha256:\s*([0-9a-fA-F]+)\s*$') {
                    $expectedSha = $matches[1].ToLowerInvariant()
                    break
                }
            }
            $actualSha = (Get-FileHash -Path $docFile -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($expectedSha -and ($expectedSha -ne $actualSha)) {
                Write-Host "[!] INSTALL_FOR_AGENTS.md has been modified since this starter kit was installed." -ForegroundColor Red
                Write-Host "    Expected sha256: $expectedSha" -ForegroundColor Red
                Write-Host "    Actual sha256:   $actualSha" -ForegroundColor Red
                Write-Host ""
                Write-Host "    Refusing to hand off to claude. If you intentionally edited the doc," -ForegroundColor Red
                Write-Host "    delete $markerFile and re-run, or re-run the bootstrap one-liner for" -ForegroundColor Red
                Write-Host "    a clean copy:" -ForegroundColor Red
                Write-Host "      irm https://raw.githubusercontent.com/Elnora-AI/elnora-ai-agent-hackathon-starter-kit/main/install.ps1 | iex" -ForegroundColor Red
                exit 3
            }
        } else {
            $markerMissing = $true
            Write-Host "  (no integrity marker found at $markerFile - this is a pre-existing install." -ForegroundColor Gray
            Write-Host "   Continuing without doc-tamper verification for the interactive handoff.)" -ForegroundColor Gray
        }
    }

    if ($env:ELNORA_HANDOFF_MODE -eq "headless") {
        # Headless E2E test mode. Used by .github/workflows/handoff-e2e.yml so
        # we can verify what Claude actually does after the handoff, not just
        # that the handoff fired. Same prompt, same cwd as production - only
        # the I/O wrapper changes (one-shot print mode + bypassPermissions
        # because nobody's there to approve tool calls).
        #
        # Requires ANTHROPIC_API_KEY in env so claude skips browser OAuth.

        # Hard requirement for headless mode: the integrity marker MUST be
        # present. The marker is what proves the doc claude is about to
        # follow under bypassPermissions hasn't been swapped out. The
        # interactive handoff can fall back to "warn and proceed" because a
        # human is on the other end approving each tool call; headless
        # mode is not allowed that latitude.
        if ($markerMissing) {
            Write-Host "[!] ELNORA_HANDOFF_MODE=headless requires .elnora-ai-agent-hackathon-starter-kit-marker," -ForegroundColor Red
            Write-Host "    which is missing at $markerFile." -ForegroundColor Red
            Write-Host ""
            Write-Host "    The marker is the integrity gate that lets us run claude with" -ForegroundColor Red
            Write-Host "    --permission-mode bypassPermissions. Without it we cannot prove" -ForegroundColor Red
            Write-Host "    INSTALL_FOR_AGENTS.md is the doc we shipped." -ForegroundColor Red
            Write-Host ""
            Write-Host "    To recover, re-run the bootstrap one-liner (writes a fresh marker):" -ForegroundColor Red
            Write-Host "      irm https://raw.githubusercontent.com/Elnora-AI/elnora-ai-agent-hackathon-starter-kit/main/install.ps1 | iex" -ForegroundColor Red
            exit 4
        }

        # bypassPermissions gate. Three states:
        #   1. Real CI (GITHUB_ACTIONS=true && CI=true) - proceed silently.
        #   2. Local opt-in (ELNORA_HANDOFF_LOCAL_BYPASS=1) - print a 5-second
        #      warning, then proceed. For local handoff testing by a maintainer.
        #   3. Anything else - refuse. Just having ELNORA_HANDOFF_MODE=headless
        #      isn't enough; that env var is too easy to flip from a profile
        #      or a stray script. We want bypassPermissions to require an
        #      explicit "yes I know what this is" gesture from a human.
        if ($env:GITHUB_ACTIONS -eq "true" -and $env:CI -eq "true") {
            # CI mode - proceed silently
        } elseif ($env:ELNORA_HANDOFF_LOCAL_BYPASS -eq "1") {
            Write-Host ""
            Write-Host "  ============================================================" -ForegroundColor Yellow
            Write-Host "  WARNING: about to run claude with --permission-mode bypassPermissions." -ForegroundColor Yellow
            Write-Host "  This grants the agent full filesystem and shell access without prompts." -ForegroundColor Yellow
            Write-Host "  Press Ctrl+C in the next 5 seconds to abort." -ForegroundColor Yellow
            Write-Host "  ============================================================" -ForegroundColor Yellow
            foreach ($i in 5,4,3,2,1) { Write-Host -NoNewline "  $i... "; Start-Sleep -Seconds 1 }
            Write-Host ""
        } else {
            Write-Host "[!] ELNORA_HANDOFF_MODE=headless is set but no CI markers" -ForegroundColor Red
            Write-Host "    (GITHUB_ACTIONS=true && CI=true) and no explicit local opt-in" -ForegroundColor Red
            Write-Host "    (ELNORA_HANDOFF_LOCAL_BYPASS=1)." -ForegroundColor Red
            Write-Host ""
            Write-Host "    Refusing to run claude with --permission-mode bypassPermissions" -ForegroundColor Red
            Write-Host "    outside CI without an explicit acknowledgment. Either run this in" -ForegroundColor Red
            Write-Host "    CI, or `$env:ELNORA_HANDOFF_LOCAL_BYPASS = '1' to acknowledge that" -ForegroundColor Red
            Write-Host "    you are about to grant the agent unprompted shell + file access." -ForegroundColor Red
            exit 2
        }
        $transcript = if ($env:ELNORA_HANDOFF_TRANSCRIPT) { $env:ELNORA_HANDOFF_TRANSCRIPT } else { Join-Path $env:USERPROFILE "handoff-transcript.jsonl" }
        # The trailing `| Out-Null` on each branch is load-bearing (mirrors the
        # Mac script's `> /dev/null` after `tee`): without it the agent's own
        # conversation stream (including the literal text "FAILED:" inside
        # INSTALL_FOR_AGENTS.md) lands in ~/claude-starter-install.log and
        # poisons the next agent's grep FAILED:. Send it to the transcript only.
        if ($agentBin -eq 'codex') {
            Write-Host "ELNORA_HANDOFF_MODE=headless - running codex exec (transcript: $transcript)" -ForegroundColor Cyan
            # `codex exec` is the non-interactive analog of `claude -p`;
            # --dangerously-bypass-approvals-and-sandbox is Codex's equivalent of
            # --permission-mode bypassPermissions (nobody is there to approve
            # tool calls). Gated by the same CI / local-opt-in checks above.
            #
            # Auth: codex exec does NOT read OPENAI_API_KEY implicitly -- it
            # only honors CODEX_API_KEY for a single non-interactive run
            # (developers.openai.com/codex/environment-variables). Map the
            # standard var so CI can keep providing OPENAI_API_KEY.
            if (-not $env:CODEX_API_KEY -and $env:OPENAI_API_KEY) {
                $env:CODEX_API_KEY = $env:OPENAI_API_KEY
            }
            & codex exec $HandoffPrompt --dangerously-bypass-approvals-and-sandbox 2>&1 `
              | Tee-Object -FilePath $transcript | Out-Null
            $rc = $LASTEXITCODE
        } else {
            Write-Host "ELNORA_HANDOFF_MODE=headless - running claude -p (transcript: $transcript)" -ForegroundColor Cyan
            # --verbose is REQUIRED with -p --output-format=stream-json (Claude Code
            # rejects the combo otherwise). --max-turns 80 caps a runaway loop;
            # Phase 2 averages ~40-50 turns when GitHub bootstrap (gh auth + repo
            # create + push + verify) runs in full, so 80 leaves ~30-turn
            # headroom for transient retries (network, tool errors).
            & claude -p $HandoffPrompt `
                --permission-mode bypassPermissions `
                --output-format stream-json `
                --verbose `
                --max-turns 80 `
              | Tee-Object -FilePath $transcript | Out-Null
            $rc = $LASTEXITCODE
        }
        Write-Host ""
        # An empty/missing transcript means the agent died before emitting a
        # single event (auth failure, crash on startup) - that must read as a
        # FAILED: marker in the install log, not as a quiet success line.
        if ((Test-Path -LiteralPath $transcript) -and ((Get-Item -LiteralPath $transcript).Length -gt 0)) {
            $transcriptEvents = @(Get-Content -LiteralPath $transcript).Count
            Write-Host "$agentName handoff exited with code $rc (transcript saved to $transcript, $transcriptEvents events)" -ForegroundColor Cyan
        } else {
            Write-Host "FAILED: $agentName handoff produced no transcript at $transcript (exit $rc) - the agent likely crashed before emitting output; check the lines above for auth or network errors." -ForegroundColor Red
            if ($rc -eq 0) { $rc = 1 }
        }
        exit $rc
    }

    # Interactive handoff. Three branches by environment:
    #
    #   1. Already inside VS Code's integrated terminal ($env:TERM_PROGRAM=vscode):
    #      the user has the IDE on screen already, so just call claude in this
    #      shell. No window-launching dance needed.
    #
    #   2. `code` CLI on PATH and the user hasn't opted out: write a one-shot
    #      sentinel containing the handoff prompt, open VS Code at this repo,
    #      and exit. VS Code's runOn:folderOpen task picks up the sentinel and
    #      hands off to claude inside the integrated terminal -- so users get
    #      the file tree, source control panel, and IDE around their session
    #      instead of a bare PowerShell window. ELNORA_SKIP_VSCODE_HANDOFF=1 is
    #      the user-facing escape hatch.
    #
    #   3. Fallback: claude in this shell (today's behavior). Triggered when
    #      VS Code wasn't installed (ELNORA_SKIP_OPTIONAL_INSTALLS=1) or the
    #      `code` shim isn't on PATH yet.
    if ($env:TERM_PROGRAM -eq "vscode") {
        # Already in VS Code, so we don't launch a window -- but still drop the
        # named workspace file and set restoreWindows so the NEXT relaunch
        # reopens this project instead of an empty window.
        try { Initialize-VSCodeWorkspace } catch { }
        Write-Host "Already inside VS Code - starting $agentName in this terminal." -ForegroundColor White
        Write-Host $authNote -ForegroundColor White
        Write-Host ""
        & $agentBin $HandoffPrompt
        exit $LASTEXITCODE
    }

    # The VS Code sentinel handoff drives `claude` specifically (run-handoff.ps1
    # invokes claude), so it only applies when Claude is the handoff agent. Codex
    # falls through to the terminal call below.
    $codeAvailable = Get-Command code -ErrorAction SilentlyContinue
    if ($agentBin -eq 'claude' -and $codeAvailable -and $env:ELNORA_SKIP_VSCODE_HANDOFF -ne "1") {
        $vscodeDir = Join-Path $scriptDir ".vscode"
        $sentinel  = Join-Path $vscodeDir ".handoff-pending"
        $helper    = Join-Path $vscodeDir "run-handoff.ps1"
        if ((Test-Path -LiteralPath $vscodeDir) -and (Test-Path -LiteralPath $helper)) {
            # The sentinel's content IS the prompt -- single source of truth
            # lives in $HandoffPrompt above. The helper reads, deletes, then
            # invokes claude. BOM-less UTF-8 to keep Get-Content -Raw clean.
            [System.IO.File]::WriteAllText($sentinel, $HandoffPrompt, [System.Text.UTF8Encoding]::new($false))

            # Create the named workspace file + set restoreWindows BEFORE we
            # open, so we open the workspace (not the bare folder) and the
            # window sticks across relaunches.
            try { Initialize-VSCodeWorkspace } catch { }

            Write-Host "Opening VS Code - Claude will continue Phase 2 setup there." -ForegroundColor White
            Write-Host ""
            Write-Host "VS Code will show TWO one-time prompts before the handoff fires."
            Write-Host "Click through both:"
            Write-Host "  1. 'Do you trust the authors of the files in this folder?'"
            Write-Host "       -> Click 'Yes, I trust the authors'"
            Write-Host "  2. 'This workspace has tasks ... that can launch processes"
            Write-Host "      automatically. Do you want to allow automatic tasks ...?'"
            Write-Host "       -> Click 'Allow'  (VS Code remembers this globally)"
            Write-Host ""
            Write-Host "Once both are approved, an integrated terminal opens with Claude"
            Write-Host "already on the Phase 2 prompt. On first run, your browser will"
            Write-Host "open to log into your Claude Pro/Max account."
            Write-Host ""
            Write-Host "If you click Disallow on the second prompt, or Claude does not"
            Write-Host "auto-start for any other reason, open a terminal in VS Code"
            Write-Host "(Ctrl+`` or View > Terminal) and run:"
            Write-Host "    powershell -ExecutionPolicy Bypass -File .vscode\run-handoff.ps1"
            Write-Host ""
            Write-Host "You can close this PowerShell window once VS Code has loaded."
            Write-Host ""

            # `code` (code.cmd) returns immediately after asking the GUI to open
            # the workspace. We open the named .code-workspace (not the bare
            # folder) so it lands in Open Recent as one clear, re-openable entry.
            # Wrap in try/catch so a stale shim falls through to the in-terminal
            # fallback rather than aborting the script.
            $codeLaunched = $false
            try {
                & code $workspaceFile | Out-Null
                if ($LASTEXITCODE -eq 0) { $codeLaunched = $true }
            } catch {
                Write-Host "  [!] 'code' command failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
            if ($codeLaunched) {
                exit 0
            }
            Write-Host "  [!] Falling back to terminal handoff." -ForegroundColor Yellow
            Remove-Item -LiteralPath $sentinel -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host "Starting $agentName - it will read INSTALL_FOR_AGENTS.md and finish setup." -ForegroundColor White
    Write-Host $authNote -ForegroundColor White
    Write-Host ""
    # PowerShell has no `exec` - call the agent as a child process and let it own
    # the terminal until it exits. Then the script exits cleanly.
    & $agentBin $HandoffPrompt
    exit 0
}

# Fallback: handoff agent not on PATH (its install failed) - show the manual
# continuation path so the user can recover after fixing the issue.
Write-Host "  ! '$agentBin' command not found - $agentName install may have failed." -ForegroundColor Yellow
Write-Host ""
Write-Host "  See the remediation hints above. Once you've fixed it, re-run:" -ForegroundColor White
Write-Host "      .\setup-windows.ps1"
Write-Host ""
Write-Host "  Or continue manually:" -ForegroundColor White
Write-Host "      cd $(Get-Location)"
Write-Host "      $agentBin"
Write-Host "      Then say: 'Read INSTALL_FOR_AGENTS.md and finish setup.'"
Write-Host ""

# Exit 0 even if some steps failed - the remediation recap above tells the user
# exactly what to do, and a non-zero exit would trip callers (e.g. IDE terminals
# that highlight failures) in ways that can hide the remediation text.
exit 0

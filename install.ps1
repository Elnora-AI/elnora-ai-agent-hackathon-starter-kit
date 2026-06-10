# ============================================================
# Elnora AI Agent Hackathon Starter Kit - One-liner Installer (Windows)
# ============================================================
# Usage (PowerShell):
#   irm https://raw.githubusercontent.com/Elnora-AI/elnora-ai-agent-hackathon-starter-kit/main/install.ps1 | iex
#
# Prompts for a workspace name (used for BOTH the local folder name AND
# the GitHub repo name created in Phase 2), downloads the starter kit zip
# (no git required), extracts to %USERPROFILE%\Documents\<workspace-name>,
# and runs setup-windows.ps1.
# ============================================================

$ErrorActionPreference = "Stop"

# Force TLS 1.2 for the Invoke-WebRequest below. Windows PowerShell 5.1 (the
# default on Win10/11) defaults to SSL3/TLS 1.0 on older unpatched builds;
# GitHub's CDN (codeload.github.com) rejects that handshake and the zip
# download fails with an opaque "underlying connection was closed" error
# before we reach setup-windows.ps1. Mirrors the same fix that setup-windows.ps1
# applies to its installer sub-processes.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RepoOwner = "Elnora-AI"
$RepoName  = "elnora-ai-agent-hackathon-starter-kit"
$Branch    = "main"

# ---- Workspace name -------------------------------------------------------
# This name is used for BOTH the local folder under Documents\ AND the
# GitHub repo we create later in Phase 2. Locking them in lockstep up
# front avoids a class of bugs where the local path and GitHub remote
# drift out of sync.
#
# Resolution order:
#   1. $env:ELNORA_WORKSPACE_NAME (CI / scripted runs).
#   2. Interactive Read-Host prompt (irm | iex runs in the caller's
#      session, so Read-Host reaches the real console).
#   3. Fallback to "elnora-ai-agent-hackathon-starter-kit" for non-interactive contexts
#      with no env override.
#
# Validation enforces the project naming convention (see CLAUDE.md
# > Naming Conventions): lowercase letters, digits, and dashes only.
# No uppercase, no spaces, no underscores, no dots. Self-explaining
# names with the user's name as a prefix are encouraged
# (e.g. carmen-agents, carmen-vault, carmen-knowledge-base).
#
# Anchored on both ends with alphanumerics so we reject leading/trailing
# dashes and dash-only inputs (`-foo`, `foo-`, `--`, `-`). A leading dash
# would be parsed as a flag by `gh repo create` later; a folder named
# `-rf` would be a particularly mean foot-gun. Single-char inputs
# (`a`, `1`) are still allowed via the optional middle group.
#
# This is stricter than GitHub's own repo-name rule ([A-Za-z0-9._-]+),
# so anything that passes here also passes `gh repo create`. Mirrors
# install.sh's NAME_RE — cross-platform parity matters for the rule.
$nameRegex = '^[a-z0-9]([a-z0-9-]*[a-z0-9])?$'

# Normalize $env:USERNAME for the default suggestion: lowercase + replace
# whitespace runs with single dashes + strip illegal chars. Windows
# accounts often have title-case names ("Carmen") or contain spaces
# ("First Last") — the raw $env:USERNAME would fail the strict regex.
# Mirrors install.sh's tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-'.
$userLower = ($env:USERNAME -as [string]).ToLowerInvariant() -replace '\s+', '-' -replace '[^a-z0-9-]', ''
if ([string]::IsNullOrWhiteSpace($userLower)) { $userLower = 'me' }
$defaultName = "$userLower-agents"

# >>> ELNORA_REGISTRY_LIB_START >>>
# Everything between these two markers is self-contained (no dependency on the
# rest of this script) so tests/registry/registry_test.ps1 can extract and
# dot-source it directly, exercising the REAL code instead of a drifting copy.
# If you add a registry helper, keep it inside the markers.
# ---- Workspace registry ---------------------------------------------------
# Single source of truth for "which folder is the real workspace", so a
# stalled-and-retried install resumes the same folder instead of spawning
# carmen-agents, carmen-workspace, my-agents... and leaving the user with a
# pile of half-finished repos. Plain TSV (name<TAB>path<TAB>created<TAB>
# last_run); comment lines start with '#'. Mirrors install.sh.
$RegistryDir  = Join-Path $env:APPDATA 'elnora'
$RegistryFile = Join-Path $RegistryDir 'workspaces.tsv'

# Current UTC timestamp. Factored out (mirrors install.sh's _registry_now) so
# the registry unit test can stub it for deterministic assertions.
function Get-RegistryNow { (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }

function Get-RegistryEntries {
    if (-not (Test-Path -LiteralPath $RegistryFile)) { return @() }
    $entries = @()
    foreach ($line in (Get-Content -LiteralPath $RegistryFile)) {
        if ($line -match '^\s*#' -or [string]::IsNullOrWhiteSpace($line)) { continue }
        $parts = $line -split "`t"
        if ($parts.Count -ge 2) {
            $created = ''
            if ($parts.Count -ge 3) { $created = $parts[2] }
            $lastRun = ''
            if ($parts.Count -ge 4) { $lastRun = $parts[3] }
            $entries += [pscustomobject]@{
                Name    = $parts[0]
                Path    = $parts[1]
                Created = $created
                LastRun = $lastRun
            }
        }
    }
    return $entries
}

function Write-Registry {
    param([object[]]$Entries)
    New-Item -ItemType Directory -Path $RegistryDir -Force -ErrorAction SilentlyContinue | Out-Null
    $lines = @(
        '# Elnora workspace registry (managed by install.ps1 -- do not edit by hand)',
        '# columns: name<TAB>path<TAB>created(UTC)<TAB>last_run(UTC)'
    )
    foreach ($e in $Entries) {
        $lines += ($e.Name + "`t" + $e.Path + "`t" + $e.Created + "`t" + $e.LastRun)
    }
    Set-Content -LiteralPath $RegistryFile -Value $lines -Encoding UTF8
}

# Append or update one entry, preserving its original Created timestamp.
function Set-RegistryEntry {
    param([string]$Name, [string]$Path)
    $now = Get-RegistryNow
    $entries = @(Get-RegistryEntries)
    $created = $now
    $existing = $entries | Where-Object { $_.Path -eq $Path } | Select-Object -First 1
    if ($existing -and $existing.Created) { $created = $existing.Created }
    $kept = @($entries | Where-Object { $_.Path -ne $Path })
    $kept += [pscustomobject]@{ Name = $Name; Path = $Path; Created = $created; LastRun = $now }
    Write-Registry -Entries $kept
}

# Drop one entry by path (used when the user forgets a dead folder).
function Remove-RegistryEntry {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $RegistryFile)) { return }
    $kept = @(Get-RegistryEntries | Where-Object { $_.Path -ne $Path })
    Write-Registry -Entries $kept
}

# Interactive resume menu. Returns the chosen workspace name to resume, or
# $null if the caller should fall through to the fresh-name prompt.
function Invoke-ResumeMenu {
    $entries = @(Get-RegistryEntries)
    if ($entries.Count -eq 0) { return $null }
    while ($true) {
        Write-Host "You already have Elnora workspace(s) on this machine:"
        Write-Host ""
        for ($i = 0; $i -lt $entries.Count; $i++) {
            $e = $entries[$i]
            $status = if (Test-Path -LiteralPath $e.Path) { 'ready' } else { 'folder missing' }
            Write-Host ("  [{0}] {1}" -f ($i + 1), $e.Name)
            Write-Host ("        {0}  ({1})" -f $e.Path, $status)
        }
        Write-Host ""
        Write-Host "  [n] Create a NEW workspace with a different name"
        Write-Host ""
        $reply = Read-Host -Prompt ("Resume which workspace? [1-{0} / n]" -f $entries.Count)
        if ($reply -match '^(n|new)$') { return $null }
        $num = 0
        if (-not [int]::TryParse($reply, [ref]$num) -or $num -lt 1 -or $num -gt $entries.Count) {
            Write-Host ("  [!] Please enter a number between 1 and {0}, or 'n' for new." -f $entries.Count) -ForegroundColor Yellow
            Write-Host ""
            continue
        }
        $sel = $entries[$num - 1]
        if (Test-Path -LiteralPath $sel.Path) {
            Write-Host ""
            Write-Host ("Resuming '{0}' at {1}" -f $sel.Name, $sel.Path)
            Write-Host ""
            return $sel.Name
        }
        # Folder is gone but still registered -- ask rather than assume.
        Write-Host ""
        Write-Host ("  '{0}' is registered at {1}, but that folder is gone." -f $sel.Name, $sel.Path)
        Write-Host "    [r] Re-create the workspace there"
        Write-Host "    [f] Forget it (remove from this list)"
        Write-Host "    [b] Back to the list"
        $sub = Read-Host -Prompt "  Choose [r/f/b]"
        switch -Regex ($sub) {
            '^r$' { Write-Host ""; Write-Host ("Re-creating '{0}' at {1}" -f $sel.Name, $sel.Path); Write-Host ""; return $sel.Name }
            '^f$' {
                Remove-RegistryEntry -Path $sel.Path
                Write-Host ("  Removed '{0}' from the registry." -f $sel.Name)
                Write-Host ""
                $entries = @(Get-RegistryEntries)
                if ($entries.Count -eq 0) { return $null }
            }
            default { Write-Host "" }
        }
    }
}
# <<< ELNORA_REGISTRY_LIB_END <<<

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  Elnora AI Agent Hackathon Starter Kit - Bootstrap" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

if (-not [string]::IsNullOrWhiteSpace($env:ELNORA_WORKSPACE_NAME)) {
    $WorkspaceName = $env:ELNORA_WORKSPACE_NAME
} elseif ([Environment]::UserInteractive -and $Host.UI.RawUI) {
    # Offer to resume a known workspace before asking for a name -- this is how
    # we stop a retried install from spawning a duplicate folder. Only prompt
    # for a fresh name when the user declines or there's nothing to resume.
    $resumed = Invoke-ResumeMenu
    if ($resumed) {
        $WorkspaceName = $resumed
    } else {
    Write-Host "Pick a name for your workspace. This becomes BOTH:"
    Write-Host "  - the local folder under $env:USERPROFILE\Documents\"
    Write-Host "  - the GitHub repo we'll create for you in Phase 2"
    Write-Host ""
    Write-Host "Naming rules (project convention):"
    Write-Host "  - lowercase letters, digits, and dashes only"
    Write-Host "  - no spaces, no underscores, no uppercase"
    Write-Host "  - self-explaining: $userLower-agents, $userLower-vault,"
    Write-Host "    $userLower-knowledge-base, $userLower-filesystem, etc."
    Write-Host ""
    while ($true) {
        $reply = Read-Host -Prompt "Workspace name [$defaultName]"
        if ([string]::IsNullOrWhiteSpace($reply)) { $reply = $defaultName }
        if ($reply -match $nameRegex) {
            $WorkspaceName = $reply
            break
        }
        Write-Host "  [!] '$reply' isn't a legal name. Use lowercase letters, digits, and dashes only; must start and end with a letter or digit (no leading/trailing dash)." -ForegroundColor Yellow
    }
    Write-Host ""
    }
} else {
    $WorkspaceName = "elnora-ai-agent-hackathon-starter-kit"
}

if ($WorkspaceName -notmatch $nameRegex) {
    Write-Host "[!] ELNORA_WORKSPACE_NAME='$WorkspaceName' violates the project naming convention." -ForegroundColor Red
    Write-Host "    Allowed: lowercase letters, digits, and dashes; must start and end with a letter/digit (^[a-z0-9]([a-z0-9-]*[a-z0-9])?`$)." -ForegroundColor Red
    throw "Invalid workspace name: $WorkspaceName"
}

# ---- Coding agent selection -----------------------------------------------
# Works with two coding agents: Claude Code (Anthropic) and Codex (OpenAI).
# Phase 1 installs whichever you pick; Phase 2 ("finish setup") is driven by
# exactly ONE agent. Resolution: $env:ELNORA_AGENT -> prompt -> default claude.
# When "both", a second choice ($env:ELNORA_HANDOFF_AGENT) picks who finishes.
function Get-NormAgent($v) { ($v -replace '\s','').ToLower() }

if (-not [string]::IsNullOrWhiteSpace($env:ELNORA_AGENT)) {
    $Agent = Get-NormAgent $env:ELNORA_AGENT
} elseif ([Environment]::UserInteractive -and $Host.UI.RawUI) {
    Write-Host "Which coding agent do you want to use?"
    Write-Host "  1) Claude Code   (Anthropic; needs a Claude Pro/Max plan or API key)"
    Write-Host "  2) Codex         (OpenAI; needs a ChatGPT Plus/Pro plan or API key)"
    Write-Host "  3) Both          (install both; you'll pick which finishes setup)"
    Write-Host ""
    while ($true) {
        $reply = Read-Host -Prompt "Agent [1]"
        if ([string]::IsNullOrWhiteSpace($reply)) { $reply = "1" }
        $n = Get-NormAgent $reply
        if ($n -in @("1","claude"))     { $Agent = "claude"; break }
        elseif ($n -in @("2","codex"))  { $Agent = "codex";  break }
        elseif ($n -in @("3","both"))   { $Agent = "both";   break }
        else { Write-Host "  [!] Enter 1, 2, or 3 (or claude / codex / both)." -ForegroundColor Yellow }
    }
    Write-Host ""
} else {
    # Non-interactive with no $env:ELNORA_AGENT (piped/headless run) -- default
    # to Claude Code instead of blocking on Read-Host, mirroring install.sh's
    # /dev/tty gate.
    $Agent = "claude"
}

if ($Agent -notin @("claude","codex","both")) {
    throw "ELNORA_AGENT='$Agent' is invalid. Use: claude | codex | both."
}

if ($Agent -eq "both") {
    if (-not [string]::IsNullOrWhiteSpace($env:ELNORA_HANDOFF_AGENT)) {
        $HandoffAgent = Get-NormAgent $env:ELNORA_HANDOFF_AGENT
    } elseif ([Environment]::UserInteractive -and $Host.UI.RawUI) {
        Write-Host "You're installing both. Which one should finish setup right now?"
        Write-Host "  1) Claude Code"
        Write-Host "  2) Codex"
        Write-Host "  (The other stays installed and ready to launch anytime.)"
        Write-Host ""
        while ($true) {
            $reply = Read-Host -Prompt "Finish setup with [1]"
            if ([string]::IsNullOrWhiteSpace($reply)) { $reply = "1" }
            $n = Get-NormAgent $reply
            if ($n -in @("1","claude"))    { $HandoffAgent = "claude"; break }
            elseif ($n -in @("2","codex")) { $HandoffAgent = "codex";  break }
            else { Write-Host "  [!] Enter 1 or 2 (or claude / codex)." -ForegroundColor Yellow }
        }
        Write-Host ""
    } else {
        # Non-interactive with no $env:ELNORA_HANDOFF_AGENT -- default to Claude.
        $HandoffAgent = "claude"
    }
} else {
    $HandoffAgent = $Agent
}

if ($HandoffAgent -notin @("claude","codex")) {
    throw "ELNORA_HANDOFF_AGENT='$HandoffAgent' is invalid. Use: claude | codex."
}

# Pass the choice through to setup-windows.ps1 via the process environment.
$env:ELNORA_AGENT = $Agent
$env:ELNORA_HANDOFF_AGENT = $HandoffAgent

$TargetDir = Join-Path $env:USERPROFILE "Documents\$WorkspaceName"

$agentLabel = switch ($Agent) { "claude" { "Claude Code" } "codex" { "Codex" } "both" { "Claude Code + Codex" } }
Write-Host "This will:"
Write-Host "  1. Download the starter kit to $TargetDir"
Write-Host "  2. Run setup-windows.ps1 (installs $agentLabel + dev tools)"
Write-Host ""

# Always wipe + re-extract on every run. If the customer is running this
# script again it's because something didn't work the first time -- they
# want a fresh starting point, not a half-stale copy of last week's repo.
# System tools (Claude, Node, Python, Obsidian) are NOT touched here:
# setup-windows.ps1 detects existing installs and updates in place, so
# re-running won't blow away a working toolchain.
#
# EXCEPTION: if the agent left a handoff resume marker
# (.elnora-handoff-resume.json) in this folder, refuse to wipe. The marker
# means a previous Phase 2 hit a GitHub-name collision and asked the user
# to re-run setup-windows.ps1, NOT install.ps1. Wiping would silently drop
# the resume state and the next agent session would start over instead of
# picking up at step 6c.3. Tell the user the right command and bail.
# Files inside $TargetDir that are USER DATA (not kit-shipped) and must
# survive a re-run wipe. Customer-typed credentials and per-user config
# live here; losing them on re-install is a regression. .elnora-handoff
# -resume.json is also user-state but is handled separately above (we
# refuse to wipe at all when that marker exists).
$preservePaths = @(
    ".env",
    ".claude/knowledge-base.local.md",
    ".claude/settings.local.json"
)

$preserveDir = $null

if (Test-Path $TargetDir) {
    if (Test-Path (Join-Path $TargetDir ".elnora-handoff-resume.json")) {
        Write-Host "[!] $TargetDir already contains an in-progress Phase 2 handoff" -ForegroundColor Red
        Write-Host "    (.elnora-handoff-resume.json marker present)." -ForegroundColor Red
        Write-Host ""
        Write-Host "    Don't re-run install.ps1 -- it would erase the resume state." -ForegroundColor Red
        Write-Host "    Instead, finish the handoff from the existing folder:" -ForegroundColor Red
        Write-Host ""
        Write-Host "      powershell -ExecutionPolicy Bypass -File `"$TargetDir\setup-windows.ps1`"" -ForegroundColor Red
        Write-Host ""
        throw "Refusing to wipe in-progress handoff at $TargetDir"
    }
    # A workspace that FINISHED setup has had its install scaffolding removed
    # (Phase 2's final cleanup deletes setup-windows.ps1 and friends, then
    # commits) -- so "folder exists, is a git repo, has no setup script"
    # means there is nothing left to install. Wiping it would destroy the
    # user's post-setup work (the wipe preserves only .env and two .claude
    # config files). Tell them how to actually continue and stop here.
    if (-not (Test-Path (Join-Path $TargetDir "setup-windows.ps1")) -and (Test-Path (Join-Path $TargetDir ".git"))) {
        Write-Host "[OK] '$WorkspaceName' already finished setup - there's nothing to install." -ForegroundColor Green
        Write-Host ""
        Write-Host "    (The install scripts inside it were removed by the final cleanup"
        Write-Host "    step, which only runs after a successful setup.)"
        Write-Host ""
        Write-Host "    To continue working with your agent:"
        Write-Host ""
        Write-Host "      cd `"$TargetDir`""
        Write-Host "      claude"
        Write-Host ""
        Write-Host "    (Or 'codex' if that's the agent you picked.)"
        Write-Host ""
        Write-Host "    To set up a brand-new, separate workspace instead, re-run this"
        Write-Host "    installer and pick a DIFFERENT name - re-installing into this"
        Write-Host "    folder would overwrite the work you've done in it."
        return
    }
    Write-Host "Existing starter kit detected at $TargetDir" -ForegroundColor Gray

    # Preserve user-data files across the wipe. Stash them in a temp dir,
    # then restore after re-extract. Cleaned up in the finally block.
    $stash = Join-Path $env:TEMP ("elnora-preserve-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stash -Force | Out-Null
    $preservedCount = 0
    foreach ($rel in $preservePaths) {
        $src = Join-Path $TargetDir $rel
        if (Test-Path -LiteralPath $src) {
            $dst = Join-Path $stash $rel
            New-Item -ItemType Directory -Path (Split-Path $dst -Parent) -Force | Out-Null
            Copy-Item -LiteralPath $src -Destination $dst -Force
            $preservedCount++
            Write-Host "  Preserving $rel across wipe." -ForegroundColor Gray
        }
    }
    if ($preservedCount -gt 0) {
        $preserveDir = $stash
    } else {
        Remove-Item -Path $stash -Recurse -Force -ErrorAction SilentlyContinue
    }
    # NOTE: we do NOT wipe $TargetDir here. The wipe happens only AFTER the
    # new copy has downloaded and verified (see below), so a failed download
    # on flaky conference/hotel wifi can never leave the user with no
    # workspace -- and no stashed user data -- at all.
}

Write-Host "Downloading starter kit zip..." -ForegroundColor Green
$zipUrl  = "https://github.com/$RepoOwner/$RepoName/archive/refs/heads/$Branch.zip"
$zipPath = Join-Path $env:TEMP "$RepoName-bootstrap.zip"
$tmpExtractDir = Join-Path $env:TEMP "$RepoName-bootstrap"

try {
    # Retry up to 3 times on flaky networks (hotel / conference wifi).
    # -TimeoutSec caps the whole request; retries cover transient DNS/TLS
    # hiccups that return immediately instead of hanging.
    $maxAttempts = 3
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing -TimeoutSec 300
            break
        } catch {
            if ($attempt -eq $maxAttempts) { throw }
            Write-Host "  Download attempt $attempt failed: $($_.Exception.Message). Retrying in 2s..." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
    }
    if (Test-Path $tmpExtractDir) { Remove-Item $tmpExtractDir -Recurse -Force }
    Expand-Archive -Path $zipPath -DestinationPath $tmpExtractDir -Force

    $extracted = Join-Path $tmpExtractDir "$RepoName-$Branch"
    if (-not (Test-Path $extracted)) {
        throw "Expected folder not found after extract: $extracted"
    }

    New-Item -ItemType Directory -Path (Split-Path $TargetDir -Parent) -Force -ErrorAction SilentlyContinue | Out-Null
    # The fresh copy is downloaded and verified -- only now is it safe to
    # remove the previous install and swap the new one in. Doing the wipe
    # here (not before the download) means a failed download leaves the
    # existing workspace untouched. System tools like Claude, Node, Python
    # live outside $TargetDir and are never touched.
    if (Test-Path $TargetDir) {
        Write-Host "Wiping previous install for a fresh copy (system tools are kept)..." -ForegroundColor Gray
        Remove-Item -Path $TargetDir -Recurse -Force
    }
    Move-Item -Path $extracted -Destination $TargetDir -Force
    Write-Host "Extracted to $TargetDir" -ForegroundColor Green

    # Restore any user-data files we stashed before the wipe. Has to
    # happen AFTER the move so we're laying these on top of the freshly
    # extracted zip contents (which carry the .gitignored templates,
    # not the user's filled-in versions).
    if ($preserveDir -and (Test-Path -LiteralPath $preserveDir)) {
        foreach ($rel in $preservePaths) {
            $src = Join-Path $preserveDir $rel
            if (Test-Path -LiteralPath $src) {
                $dst = Join-Path $TargetDir $rel
                New-Item -ItemType Directory -Path (Split-Path $dst -Parent) -Force | Out-Null
                Copy-Item -LiteralPath $src -Destination $dst -Force
                Write-Host "  Restored $rel." -ForegroundColor Gray
            }
        }
    }
} catch {
    Write-Host "[!] Failed to download starter kit from $zipUrl" -ForegroundColor Red
    Write-Host "    Reason: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "    Check your internet connection and retry:" -ForegroundColor Red
    Write-Host "      irm https://raw.githubusercontent.com/$RepoOwner/$RepoName/$Branch/install.ps1 | iex" -ForegroundColor Red
    # `throw` instead of `exit 1`: this script is invoked via `irm ... | iex`,
    # which runs in the caller's scope. `exit` would terminate the caller's
    # shell/parent script silently; `throw` surfaces as a catchable error and
    # still halts this installer if uncaught.
    throw "Starter kit bootstrap: failed to download from $zipUrl ($($_.Exception.Message))"
} finally {
    if (Test-Path $zipPath)       { Remove-Item $zipPath -Force -ErrorAction SilentlyContinue }
    if (Test-Path $tmpExtractDir) { Remove-Item $tmpExtractDir -Recurse -Force -ErrorAction SilentlyContinue }
    if ($preserveDir -and (Test-Path -LiteralPath $preserveDir)) {
        Remove-Item -Path $preserveDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Set-Location $TargetDir

# Record this workspace (or refresh its last_run) so the next re-run can offer
# to resume THIS folder instead of asking for a name and spawning a sibling.
# Best-effort: a registry write failure must never abort an otherwise-good
# install.
try {
    Set-RegistryEntry -Name $WorkspaceName -Path $TargetDir
} catch {
    Write-Host "[WARN] Could not record this workspace in $RegistryFile - the next re-run won't offer to resume this folder and may create a sibling copy." -ForegroundColor Yellow
}

# Strip dev/CI scaffolding the customer can't use anyway. tests/handoff/ exists
# for our CI assertions; .github/ holds workflows + dependabot config that only
# fire on the official Elnora-AI/elnora-ai-agent-hackathon-starter-kit repo. Both ride along in the
# zip and would just clutter the customer's directory. -ErrorAction
# SilentlyContinue keeps this idempotent on re-runs after the dirs are gone.
Write-Host "Stripping dev/CI scaffolding (tests/, .github/)..." -ForegroundColor Cyan
Remove-Item -Path (Join-Path $TargetDir "tests")   -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path (Join-Path $TargetDir ".github") -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "  Done." -ForegroundColor Gray

# Write a marker file recording the SHA256 of INSTALL_FOR_AGENTS.md as it was
# extracted from GitHub. setup-windows.ps1 verifies this hash before handing
# off to claude with bypassPermissions -- if a third party tampers with the
# doc between extract and setup, the verify step trips and the handoff
# aborts. This is the trust anchor for the headless Phase 2 flow.
#
# Every install.ps1 run is a fresh extract from the official zip (we always
# wipe + re-download above), so re-blessing here is correct: the doc is
# always exactly what GitHub just served, and the marker stays in lockstep
# with whatever INSTALL_FOR_AGENTS.md content the customer is about to run.
$markerPath = Join-Path $TargetDir ".elnora-ai-agent-hackathon-starter-kit-marker"
$installForAgentsPath = Join-Path $TargetDir "INSTALL_FOR_AGENTS.md"
if (Test-Path -LiteralPath $installForAgentsPath) {
    $hash = (Get-FileHash -Path $installForAgentsPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $now = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $markerContent = "version: 1`ncreated: $now`ninstall_for_agents_sha256: $hash`n"
    [System.IO.File]::WriteAllText($markerPath, $markerContent, [System.Text.UTF8Encoding]::new($false))
    Write-Host "  Wrote integrity marker (.elnora-ai-agent-hackathon-starter-kit-marker)." -ForegroundColor Gray
}

# Bypass execution policy for this process so setup-windows.ps1 runs without
# the user setting it manually (as the older flow did). On GPO-managed/corporate
# machines a MachinePolicy/UserPolicy can override the process scope and make
# this throw under $ErrorActionPreference='Stop', so catch it and continue --
# the launch below passes -ExecutionPolicy Bypass explicitly, which works even
# when the policy change is blocked or a downloaded script carries Mark-of-the-Web.
try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop
} catch {
    Write-Host "  (Could not change process execution policy: $($_.Exception.Message). Continuing.)" -ForegroundColor DarkGray
}
Write-Host ""
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $TargetDir "setup-windows.ps1")

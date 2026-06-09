# ============================================================
# Elnora Starter Kit - One-liner Installer (Windows)
# ============================================================
# Usage (PowerShell):
#   irm https://raw.githubusercontent.com/Elnora-AI/elnora-starter-kit/main/install.ps1 | iex
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
$RepoName  = "elnora-starter-kit"
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
#   3. Fallback to "elnora-starter-kit" for non-interactive contexts
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

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  Elnora Starter Kit - Bootstrap" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

if (-not [string]::IsNullOrWhiteSpace($env:ELNORA_WORKSPACE_NAME)) {
    $WorkspaceName = $env:ELNORA_WORKSPACE_NAME
} elseif ([Environment]::UserInteractive -and $Host.UI.RawUI) {
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
} else {
    $WorkspaceName = "elnora-starter-kit"
}

if ($WorkspaceName -notmatch $nameRegex) {
    Write-Host "[!] ELNORA_WORKSPACE_NAME='$WorkspaceName' violates the project naming convention." -ForegroundColor Red
    Write-Host "    Allowed: lowercase letters, digits, and dashes; must start and end with a letter/digit (^[a-z0-9]([a-z0-9-]*[a-z0-9])?`$)." -ForegroundColor Red
    throw "Invalid workspace name: $WorkspaceName"
}

$TargetDir = Join-Path $env:USERPROFILE "Documents\$WorkspaceName"

Write-Host "This will:"
Write-Host "  1. Download the starter kit to $TargetDir"
Write-Host "  2. Run setup-windows.ps1 (installs Claude Code + dev tools)"
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
        Write-Host "      cd `"$TargetDir`"; .\setup-windows.ps1" -ForegroundColor Red
        Write-Host ""
        throw "Refusing to wipe in-progress handoff at $TargetDir"
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
    Write-Host "Wiping for a fresh install (system tools like Claude, Node, Python are kept)..." -ForegroundColor Gray
    Remove-Item -Path $TargetDir -Recurse -Force
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
    # still halts this installer if uncaught. Same reasoning as Bug 2 in the
    # elnora-cli handoff doc.
    throw "Starter kit bootstrap: failed to download from $zipUrl ($($_.Exception.Message))"
} finally {
    if (Test-Path $zipPath)       { Remove-Item $zipPath -Force -ErrorAction SilentlyContinue }
    if (Test-Path $tmpExtractDir) { Remove-Item $tmpExtractDir -Recurse -Force -ErrorAction SilentlyContinue }
    if ($preserveDir -and (Test-Path -LiteralPath $preserveDir)) {
        Remove-Item -Path $preserveDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Set-Location $TargetDir

# Strip dev/CI scaffolding the customer can't use anyway. tests/handoff/ exists
# for our CI assertions; .github/ holds workflows + dependabot config that only
# fire on the official Elnora-AI/elnora-starter-kit repo. Both ride along in the
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
$markerPath = Join-Path $TargetDir ".elnora-starter-kit-marker"
$installForAgentsPath = Join-Path $TargetDir "INSTALL_FOR_AGENTS.md"
if (Test-Path -LiteralPath $installForAgentsPath) {
    $hash = (Get-FileHash -Path $installForAgentsPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $now = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $markerContent = "version: 1`ncreated: $now`ninstall_for_agents_sha256: $hash`n"
    [System.IO.File]::WriteAllText($markerPath, $markerContent, [System.Text.UTF8Encoding]::new($false))
    Write-Host "  Wrote integrity marker (.elnora-starter-kit-marker)." -ForegroundColor Gray
}

# Bypass execution policy for this process only so setup-windows.ps1 runs
# without requiring the user to set it manually (as the older flow did).
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
Write-Host ""
& .\setup-windows.ps1

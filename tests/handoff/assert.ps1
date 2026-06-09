# ============================================================
# Handoff E2E -- post-state assertions (Windows)
# ============================================================
# Run AFTER the headless handoff completes. Verifies on disk
# that Claude actually did the Phase 2 work -- independent of
# what the transcript says.
#
# Usage:
#   .\tests\handoff\assert.ps1 <repo-dir> <transcript-path>
#
# Exits 0 if all assertions pass, 1 if any fail.
# ============================================================

param(
    [string]$RepoDir = $PWD,
    [string]$Transcript = (Join-Path $env:USERPROFILE "handoff-transcript.jsonl")
)

$ErrorActionPreference = "Continue"

$Pass = 0
$Fail = 0
$FailMsgs = New-Object System.Collections.ArrayList

function Assert-Ok {
    param([string]$Msg)
    Write-Host "  [OK] $Msg" -ForegroundColor Green
    $script:Pass++
}
function Assert-Fail {
    param([string]$Msg)
    Write-Host "  [FAIL] $Msg" -ForegroundColor Red
    $script:Fail++
    [void]$script:FailMsgs.Add($Msg)
}

# Pre-check the repo dir before Set-Location so a missing path produces a
# clean structured failure instead of an opaque cmdlet exception. Mirrors
# `assert.sh`'s `cd "$REPO_DIR" || { echo FATAL; exit 2; }` pattern.
if (-not (Test-Path -LiteralPath $RepoDir)) {
    Write-Host "FATAL: cannot cd to $RepoDir (directory does not exist)" -ForegroundColor Red
    exit 2
}
Set-Location -LiteralPath $RepoDir

Write-Host "==========================================="
Write-Host "  Handoff E2E assertions"
Write-Host "==========================================="
Write-Host "  Repo:       $RepoDir"
Write-Host "  Transcript: $Transcript"
Write-Host ""

# --- Elnora CLI auth ---
# The CLI persists credentials to ~/.elnora/profiles.toml via
# `elnora auth login --api-key ...`. Verify Claude actually authenticated
# the CLI (not just wrote a useless .env file -- the CLI doesn't read .env).
Write-Host "[elnora auth]"
$profilesPath = Join-Path $env:USERPROFILE ".elnora\profiles.toml"
if (Test-Path $profilesPath) {
    Assert-Ok "$profilesPath exists"
    $profilesContent = Get-Content $profilesPath -Raw
    # Allow leading whitespace -- TOML lets `api_key = ...` appear indented
    # inside a [profile] table section, and the CLI is free to format that way.
    if ($profilesContent -match '(?m)^\s*api_key\s*=\s*"elnora_live_') {
        Assert-Ok "profiles.toml contains api_key = elnora_live_*"
    } else {
        Assert-Fail "profiles.toml missing api_key = `"elnora_live_*`" line"
    }
} else {
    Assert-Fail "$profilesPath was not created (Claude did not run 'elnora auth login --api-key ...')"
}
# Resolve the CLI binary explicitly. The Phase 1 install adds it to PATH for
# subsequent shells via setx, but a fresh pwsh step in CI doesn't always
# inherit that -- Get-Command can come up empty even though the binary is on
# disk. Fall back to the known install location before declaring auth dead.
$elnoraExe = (Get-Command elnora -ErrorAction SilentlyContinue).Source
if (-not $elnoraExe) {
    $candidate = Join-Path $env:USERPROFILE ".elnora\bin\elnora.exe"
    if (Test-Path $candidate) { $elnoraExe = $candidate }
}
if ($elnoraExe) {
    & $elnoraExe auth status > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Assert-Ok "elnora auth status returns success"
    } else {
        Assert-Fail "elnora auth status failed (CLI is not authenticated)"
    }
} else {
    Assert-Fail "elnora binary not found on PATH or at $env:USERPROFILE\.elnora\bin\elnora.exe"
}
$global:LASTEXITCODE = 0

# --- git repo ---
Write-Host ""
Write-Host "[git]"
if (Test-Path .git) {
    Assert-Ok ".git directory exists"
    $commitCount = (git -C $RepoDir log --oneline 2>$null | Measure-Object -Line).Lines
    $branch = git -C $RepoDir symbolic-ref --short HEAD 2>$null
    if (-not $branch) { $branch = "?" }
    # Expected end-state is exactly 2 commits: "Initial commit" + the step 11
    # cleanup commit ("chore: remove one-shot install scaffolding"). Anything
    # less means cleanup didn't land; anything more means an unexpected extra
    # commit slipped in.
    if ($commitCount -eq 2) {
        Assert-Ok "git history has 2 commits (initial + cleanup) on $branch"
    } elseif ($commitCount -eq 1) {
        Assert-Fail "git history has 1 commit (cleanup commit didn't land -- Phase 2 step 11 incomplete)"
    } elseif ($commitCount -eq 0) {
        Assert-Fail "git history is empty (Claude did not run 'git commit' for the initial commit)"
    } else {
        Assert-Fail "git history has $commitCount commits (expected exactly 2: initial + cleanup)"
    }
    # Two branches based on whether the workflow provisioned a PAT and
    # asked the agent to do the GitHub bootstrap.
    # `git remote` returns one remote per line. PowerShell's native command
    # capture turns a single-line result into a bare string (no trailing
    # newline) -- and `Measure-Object -Line` on that returns 0, not 1, because
    # it counts newline-terminated lines. Split + filter empties so the count
    # is right whether there are 0, 1, or many remotes.
    $remotes = git -C $RepoDir remote 2>$null
    $remoteList = @($remotes -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $remoteCount = $remoteList.Count
    if ($env:ELNORA_HANDOFF_REPO_NAME) {
        # PAT path -- expect exactly one remote 'origin' pointing at the
        # CI-named repo, with HEAD == origin/main and visibility = PRIVATE.
        if ($remoteCount -eq 1 -and $remoteList[0] -eq "origin") {
            Assert-Ok "exactly one remote 'origin' configured"
        } else {
            Assert-Fail "expected exactly one remote 'origin', found ${remoteCount}: $($remoteList -join ' ')"
        }
        $originUrl = git -C $RepoDir remote get-url origin 2>$null
        if (-not $originUrl) { $originUrl = "" }
        if ($originUrl -match [regex]::Escape("/$env:ELNORA_HANDOFF_REPO_NAME")) {
            Assert-Ok "origin URL contains repo name '$env:ELNORA_HANDOFF_REPO_NAME' ($originUrl)"
        } else {
            Assert-Fail "origin URL does not reference '$env:ELNORA_HANDOFF_REPO_NAME': got '$originUrl'"
        }
        $localHead = git -C $RepoDir rev-parse HEAD 2>$null
        $remoteHead = git -C $RepoDir rev-parse origin/main 2>$null
        if ($localHead -and $localHead -eq $remoteHead) {
            Assert-Ok "local HEAD matches origin/main ($localHead)"
        } else {
            Assert-Fail "local HEAD ($localHead) != origin/main ($remoteHead)"
        }
        # `gh repo view` needs auth. The agent exported GH_TOKEN earlier,
        # so gh inherits the token from the environment on this runner.
        $visibility = gh repo view $env:ELNORA_HANDOFF_REPO_NAME --json visibility --jq .visibility 2>$null
        if ($visibility -eq "PRIVATE") {
            Assert-Ok "GitHub repo $env:ELNORA_HANDOFF_REPO_NAME visibility=PRIVATE"
        } else {
            $shown = if ($visibility) { $visibility } else { "<unreachable>" }
            Assert-Fail "expected GitHub repo $env:ELNORA_HANDOFF_REPO_NAME visibility=PRIVATE, got '$shown'"
        }
    } else {
        # Legacy headless path -- no PAT provisioned, GitHub bootstrap skipped.
        if ($remoteCount -eq 0) {
            Assert-Ok "no git remotes configured (expected -- GitHub bootstrap was skipped without ELNORA_HANDOFF_REPO_NAME)"
        } else {
            Assert-Fail "expected 0 remotes (no PAT provisioned), found ${remoteCount}: $($remoteList -join ' ')"
        }
    }
    $global:LASTEXITCODE = 0
} else {
    Assert-Fail ".git directory was not created"
}

# --- Knowledge base config ---
# The doc tells the agent to ALWAYS write `.claude/knowledge-base.local.md`,
# even when no vault was found -- leaving `vault_path:` as the
# `<ABSOLUTE_PATH_TO_YOUR_VAULT>` placeholder. So the file's existence is
# always required; the placeholder-replaced check only fires when the test
# fixture actually staged a vault (signalled by KB_STAGED=1).
Write-Host ""
Write-Host "[knowledge base]"
$kbPath = ".claude/knowledge-base.local.md"
if (Test-Path $kbPath) {
    Assert-Ok "$kbPath exists"
    $kbContent = Get-Content $kbPath -Raw
    if ($env:KB_STAGED -eq "1") {
        if ($kbContent -match '<ABSOLUTE_PATH_TO_YOUR_VAULT>') {
            Assert-Fail "$kbPath still contains <ABSOLUTE_PATH_TO_YOUR_VAULT> placeholder (vault was staged; agent should have replaced it)"
        } else {
            Assert-Ok "$kbPath placeholder was replaced"
        }
    } else {
        Write-Host "  -  placeholder-replacement check skipped (KB_STAGED unset; no vault was staged for this run)"
    }
} else {
    Assert-Fail "$kbPath was not created"
}

# --- CLAUDE.md self-cleanup ---
Write-Host ""
Write-Host "[CLAUDE.md self-cleanup]"
$claudeMd = Get-Content CLAUDE.md -Raw
if ($claudeMd -match '### First-run setup') {
    Assert-Fail "CLAUDE.md still contains '### First-run setup' block (should have self-deleted)"
} else {
    Assert-Ok "CLAUDE.md '### First-run setup' block was removed"
}

# --- Step 11 cleanup ---
# Phase 2 step 11 removes the one-shot install scaffolding (bootstrap
# downloaders, Phase 1 installers, this Phase 2 doc, the recovery doc, the
# integrity marker, and the .vscode/ handoff helpers). The expected
# end-state for the user is a clean repo containing only what they need.
Write-Host ""
Write-Host "[step 11 cleanup]"
$cleanupFiles = @(
    "install.sh", "install.ps1",
    "setup-mac.sh", "setup-windows.ps1",
    "INSTALL_FOR_AGENTS.md", "RECOVERY.md",
    ".elnora-starter-kit-marker"
)
$cleanupOk = $true
foreach ($f in $cleanupFiles) {
    if (Test-Path -LiteralPath $f) {
        Assert-Fail "step 11 cleanup did not remove '$f' -- still present after handoff"
        $cleanupOk = $false
    }
}
if (Test-Path -LiteralPath ".vscode") {
    Assert-Fail "step 11 cleanup did not remove '.vscode/' -- still present after handoff"
    $cleanupOk = $false
}
if ($cleanupOk) {
    Assert-Ok "all one-shot scaffolding removed (install/setup scripts, INSTALL_FOR_AGENTS.md, RECOVERY.md, .vscode/, marker)"
}

# --- INSTALL_FOR_AGENTS.md hardening (regression check, source-file based) ---
# Regression check: PR1 of the security plan removed the python3 -c bypass
# instructions that gave agents a generic file-write primitive against
# .claude/ paths. The doc still mentions `python3 -c` inside backticks
# ("do not use python3 -c ...") which is fine; we only fail on actual
# code-block invocations and on python file-opens against .claude/ paths.
#
# After step 11 cleanup the post-handoff repo no longer contains
# INSTALL_FOR_AGENTS.md, so we read it from the source checkout via
# ELNORA_KIT_SOURCE_DIR (the workflow exports the path of the kit
# checkout that fed the handoff). Falls back to RepoDir if unset.
Write-Host ""
Write-Host "[INSTALL_FOR_AGENTS.md hardening]"
$hardeningPath = $null
if ($env:ELNORA_KIT_SOURCE_DIR -and (Test-Path -LiteralPath (Join-Path $env:ELNORA_KIT_SOURCE_DIR "INSTALL_FOR_AGENTS.md"))) {
    $hardeningPath = Join-Path $env:ELNORA_KIT_SOURCE_DIR "INSTALL_FOR_AGENTS.md"
} elseif (Test-Path -LiteralPath "INSTALL_FOR_AGENTS.md") {
    $hardeningPath = "INSTALL_FOR_AGENTS.md"
}
if ($hardeningPath) {
    $docLines = Get-Content -LiteralPath $hardeningPath
    $indentedPython = $docLines | Where-Object { $_ -match '^\s+python3? -c' }
    if ($indentedPython) {
        Assert-Fail "$hardeningPath contains an indented 'python3 -c' invocation (looks like coaching)"
    } else {
        Assert-Ok "$hardeningPath has no indented python3 -c invocations"
    }
    $sensitivePathOpen = $docLines | Where-Object { $_ -match "open\(['""][^'""]*\.claude/" }
    if ($sensitivePathOpen) {
        Assert-Fail "$hardeningPath contains a python open() call against .claude/ (sensitive-paths bypass)"
    } else {
        Assert-Ok "$hardeningPath has no python open() against .claude/ paths"
    }
} else {
    Write-Host "  - INSTALL_FOR_AGENTS.md not present in $RepoDir or via ELNORA_KIT_SOURCE_DIR -- hardening regression check skipped" -ForegroundColor Yellow
}

# --- HANDOFF_COMPLETE marker in transcript ---
Write-Host ""
Write-Host "[transcript]"
if (Test-Path $Transcript) {
    $lineCount = (Get-Content $Transcript | Measure-Object -Line).Lines
    Assert-Ok "transcript file exists ($lineCount lines)"
    $transcriptText = Get-Content $Transcript -Raw
    if ($transcriptText -match 'HANDOFF_COMPLETE') {
        Assert-Ok "transcript contains HANDOFF_COMPLETE marker"
    } else {
        Assert-Fail "transcript does not contain HANDOFF_COMPLETE marker"
    }
    # Match the auth/verification commands from INSTALL_FOR_AGENTS.md (steps 4-7).
    # `elnora --version` alone is not enough -- it doesn't prove auth works.
    if ($transcriptText -match 'elnora\s+(whoami|doctor|auth\s+(login|status))') {
        Assert-Ok "transcript shows Claude invoked an elnora auth/verification command"
    } else {
        Assert-Fail "transcript shows no elnora auth/verification command (whoami|doctor|auth login|auth status)"
    }
} else {
    Assert-Fail "transcript file not found at $Transcript"
}

# --- Summary ---
Write-Host ""
Write-Host "==========================================="
Write-Host "  Result: $Pass passed, $Fail failed"
Write-Host "==========================================="
if ($Fail -gt 0) {
    Write-Host ""
    Write-Host "Failures:"
    foreach ($m in $FailMsgs) {
        Write-Host "  - $m"
    }
    exit 1
}
exit 0

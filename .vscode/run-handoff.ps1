# ============================================================
# Phase 1 -> Phase 2 handoff helper (Windows)
# ============================================================
# Fired by .vscode/tasks.json on folderOpen. Consumes the one-shot sentinel
# .vscode\.handoff-pending (whose contents ARE the handoff prompt -- single
# source of truth lives in setup-windows.ps1) plus its sibling
# .vscode\.handoff-agent (which names the agent to launch: claude or codex).
# On subsequent opens (sentinel absent), exits silently so the task is a
# no-op.
#
# Stay pure ASCII. Windows PowerShell 5.1 (the default `powershell.exe` the
# VS Code task invokes) reads BOM-less .ps1 files as ANSI/CP-1252; UTF-8
# em-dashes and arrows get mangled into bytes that break string parsing.

$ErrorActionPreference = "Stop"

$RepoDir   = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Sentinel  = Join-Path $RepoDir ".vscode\.handoff-pending"
$AgentFile = Join-Path $RepoDir ".vscode\.handoff-agent"

# No sentinel = nothing to do. This is the steady state on every folder
# open after the initial handoff. Exit 0 so VS Code's task UI doesn't show
# a spurious failure marker.
if (-not (Test-Path -LiteralPath $Sentinel)) {
    exit 0
}

$Prompt = Get-Content -LiteralPath $Sentinel -Raw

# Trim trailing newline. PowerShell's Set-Content / WriteAllText combos
# usually emit a trailing CRLF; the agent CLIs don't care, but it makes
# transcripts and any echoes cleaner.
$Prompt = $Prompt.TrimEnd("`r", "`n")

# Which agent drives Phase 2. Allowlisted because this value is invoked as a
# command: anything other than the two agents the kit installs collapses to
# the claude default (also covers pre-agent-file installs, where the file
# simply doesn't exist).
$AgentBin = "claude"
if (Test-Path -LiteralPath $AgentFile) {
    $agentRaw = (Get-Content -LiteralPath $AgentFile -Raw).Trim()
    if ($agentRaw -eq "codex") { $AgentBin = "codex" }
}
$AgentName = if ($AgentBin -eq "codex") { "Codex" } else { "Claude" }

# Delete the sentinel BEFORE launching the agent. If we delete after, a crash
# or Ctrl+C in the agent leaves the sentinel and would re-fire next
# folder-open with the same stale prompt. Pre-deleting also makes the handoff
# exactly one-shot regardless of whether the agent exits cleanly.
Remove-Item -LiteralPath $Sentinel -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $AgentFile -Force -ErrorAction SilentlyContinue

# Belt-and-suspenders PATH fix. VS Code caches PATH at app launch time, so
# if VS Code was already running when setup-windows.ps1 installed the agent
# into %USERPROFILE%\.local\bin, the integrated terminal won't see it on
# PATH. We prepend the canonical install dir here.
$agentBinDir = Join-Path $env:USERPROFILE ".local\bin"
if ((Test-Path $agentBinDir) -and (($env:Path -split ';') -notcontains $agentBinDir)) {
    $env:Path = "$agentBinDir;$env:Path"
}

if (-not (Get-Command $AgentBin -ErrorAction SilentlyContinue)) {
    Write-Host "[!] '$AgentBin' command not found on PATH inside VS Code's terminal." -ForegroundColor Red
    Write-Host "    Quit VS Code fully (File -> Exit) and reopen -- the integrated" -ForegroundColor Red
    Write-Host "    terminal caches PATH at app launch. If that doesn't help," -ForegroundColor Red
    Write-Host "    re-run setup: .\setup-windows.ps1" -ForegroundColor Red
    exit 127
}

Set-Location -LiteralPath $RepoDir

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  Continuing Elnora setup with $AgentName" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# PowerShell has no `exec`. Call the agent as a child process and let it own
# the terminal until it exits, then exit with its return code so the task
# panel reports correctly.
& $AgentBin $Prompt
exit $LASTEXITCODE

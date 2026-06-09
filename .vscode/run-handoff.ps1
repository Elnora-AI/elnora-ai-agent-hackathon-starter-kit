# ============================================================
# Phase 1 -> Phase 2 handoff helper (Windows)
# ============================================================
# Fired by .vscode/tasks.json on folderOpen. Consumes the one-shot sentinel
# .vscode\.handoff-pending (whose contents ARE the handoff prompt -- single
# source of truth lives in setup-windows.ps1). On subsequent opens (sentinel
# absent), exits silently so the task is a no-op.
#
# Stay pure ASCII. Windows PowerShell 5.1 (the default `powershell.exe` the
# VS Code task invokes) reads BOM-less .ps1 files as ANSI/CP-1252; UTF-8
# em-dashes and arrows get mangled into bytes that break string parsing.

$ErrorActionPreference = "Stop"

$RepoDir  = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Sentinel = Join-Path $RepoDir ".vscode\.handoff-pending"

# No sentinel = nothing to do. This is the steady state on every folder
# open after the initial handoff. Exit 0 so VS Code's task UI doesn't show
# a spurious failure marker.
if (-not (Test-Path -LiteralPath $Sentinel)) {
    exit 0
}

$Prompt = Get-Content -LiteralPath $Sentinel -Raw

# Trim trailing newline. PowerShell's Set-Content / WriteAllText combos
# usually emit a trailing CRLF; claude's CLI doesn't care, but it makes
# transcripts and any echoes cleaner.
$Prompt = $Prompt.TrimEnd("`r", "`n")

# Delete the sentinel BEFORE launching claude. If we delete after, a crash
# or Ctrl+C in claude leaves the sentinel and would re-fire next folder-open
# with the same stale prompt. Pre-deleting also makes the handoff exactly
# one-shot regardless of whether claude exits cleanly.
Remove-Item -LiteralPath $Sentinel -Force -ErrorAction SilentlyContinue

# Belt-and-suspenders PATH fix. VS Code caches PATH at app launch time, so
# if VS Code was already running when setup-windows.ps1 installed Claude
# Code into %USERPROFILE%\.local\bin, the integrated terminal won't see
# `claude` on PATH. We prepend the canonical install dir here.
$claudeBin = Join-Path $env:USERPROFILE ".local\bin"
if ((Test-Path $claudeBin) -and (($env:Path -split ';') -notcontains $claudeBin)) {
    $env:Path = "$claudeBin;$env:Path"
}

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "[!] 'claude' command not found on PATH inside VS Code's terminal." -ForegroundColor Red
    Write-Host "    Quit VS Code fully (File -> Exit) and reopen -- the integrated" -ForegroundColor Red
    Write-Host "    terminal caches PATH at app launch. If that doesn't help," -ForegroundColor Red
    Write-Host "    re-run setup: .\setup-windows.ps1" -ForegroundColor Red
    exit 127
}

Set-Location -LiteralPath $RepoDir

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  Continuing Elnora setup with Claude" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# PowerShell has no `exec`. Call claude as a child process and let it own
# the terminal until it exits, then exit with its return code so the task
# panel reports correctly.
& claude $Prompt
exit $LASTEXITCODE

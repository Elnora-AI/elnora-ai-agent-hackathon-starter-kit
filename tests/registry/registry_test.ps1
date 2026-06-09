# ============================================================
# Unit test for the install.ps1 workspace registry.
#
# Hermetic: no network, no install. It EXTRACTS the registry helpers from
# install.ps1 (the block between the ELNORA_REGISTRY_LIB markers) and
# dot-sources them, so it tests the real shipping code, not a copy that can
# drift. Covers the data layer (record / forget / dedup / created-preservation)
# -- the part that can silently corrupt a user's registry.
#
# The interactive resume menu uses Read-Host (console input), which isn't
# scriptable cross-platform, so it's covered by the macOS pty test in
# registry_test.sh and by manual validation, not here.
#
# Usage:  pwsh tests/registry/registry_test.ps1
# Exit:   0 = all assertions passed, 1 = at least one failed.
# ============================================================
$ErrorActionPreference = 'Stop'

$repoRoot  = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$installPs1 = Join-Path $repoRoot 'install.ps1'

$script:pass = 0
$script:fail = 0
function Assert-Eq($expected, $actual, $msg) {
    if ("$expected" -eq "$actual") {
        $script:pass++
        Write-Host "  ok   - $msg"
    } else {
        $script:fail++
        Write-Host "  FAIL - $msg (expected [$expected], got [$actual])"
    }
}

# Sandbox first. The lib sets $RegistryDir from $env:APPDATA at source time;
# on Linux CI runners APPDATA is unset, so point it at the sandbox before
# sourcing to avoid a null Join-Path. We override $RegistryDir/$RegistryFile
# explicitly below anyway.
$work = Join-Path ([System.IO.Path]::GetTempPath()) ("elnora-reg-" + [System.Guid]::NewGuid().ToString('N'))
$env:APPDATA = $work

# --- Extract and dot-source the real registry lib ---------------------------
$inBlock = $false
$libLines = foreach ($l in (Get-Content -LiteralPath $installPs1)) {
    if ($l -match 'ELNORA_REGISTRY_LIB_START') { $inBlock = $true; continue }
    if ($l -match 'ELNORA_REGISTRY_LIB_END')   { $inBlock = $false; continue }
    if ($inBlock) { $l }
}
$lib = ($libLines -join "`n")
if ($lib -notmatch 'function Set-RegistryEntry') {
    Write-Host "[!] Could not extract the registry lib from $installPs1"
    Write-Host "    (markers ELNORA_REGISTRY_LIB_START / _END missing or moved?)"
    exit 1
}
Invoke-Expression $lib

# Redirect the registry into the sandbox and make timestamps deterministic by
# overriding Get-RegistryNow (defined inside the lib).
$script:RegistryDir  = Join-Path $work 'cfg'
$script:RegistryFile = Join-Path $RegistryDir 'workspaces.tsv'
$script:FakeNow = '2026-01-01T00:00:00Z'
function Get-RegistryNow { $script:FakeNow }

function DataLines { @(Get-RegistryEntries) }

try {
    Write-Host "registry data-layer tests"

    # T1: no file yet -> Get-RegistryEntries returns empty.
    Assert-Eq 0 (DataLines).Count "no registry file -> 0 entries"

    # T2: first record creates the file with one entry.
    Set-RegistryEntry -Name 'carmen-agents' -Path '/Users/x/Documents/carmen-agents'
    Assert-Eq 1 (DataLines).Count "first record -> 1 entry"
    Assert-Eq 'carmen-agents' ((DataLines)[0].Name) "first record stores the name"

    # T3: a second distinct path appends.
    Set-RegistryEntry -Name 'old-agents' -Path '/Users/x/Documents/old-agents'
    Assert-Eq 2 (DataLines).Count "second distinct record -> 2 entries"

    # T4: re-record same path -> no dup; created preserved, last_run advances.
    $script:FakeNow = '2026-02-02T22:22:22Z'
    Set-RegistryEntry -Name 'carmen-agents' -Path '/Users/x/Documents/carmen-agents'
    Assert-Eq 2 (DataLines).Count "re-record same path -> still 2 entries (no dup)"
    $e = @(Get-RegistryEntries) | Where-Object { $_.Path -eq '/Users/x/Documents/carmen-agents' } | Select-Object -First 1
    Assert-Eq '2026-01-01T00:00:00Z' $e.Created "re-record preserves original created"
    Assert-Eq '2026-02-02T22:22:22Z' $e.LastRun "re-record advances last_run"

    # T5: forget removes only the targeted entry.
    Remove-RegistryEntry -Path '/Users/x/Documents/old-agents'
    Assert-Eq 1 (DataLines).Count "forget -> 1 entry"
    Assert-Eq 'carmen-agents' ((DataLines)[0].Name) "forget removes the right entry"

    # T6: header comment lines are preserved.
    $comments = @(Get-Content -LiteralPath $RegistryFile | Where-Object { $_ -match '^\s*#' })
    Assert-Eq 2 $comments.Count "two header comment lines kept"

    # T7: tab-delimited storage tolerates spaces in a path.
    Set-RegistryEntry -Name 'spacey' -Path '/Users/x/Documents/my agents'
    $sp = @(Get-RegistryEntries) | Where-Object { $_.Path -eq '/Users/x/Documents/my agents' } | Select-Object -First 1
    Assert-Eq 'spacey' $sp.Name "path containing a space round-trips"
}
finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ""
Write-Host "registry tests: $($script:pass) passed, $($script:fail) failed"
if ($script:fail -ne 0) { exit 1 } else { exit 0 }

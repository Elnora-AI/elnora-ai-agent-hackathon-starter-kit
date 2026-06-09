#!/bin/bash
# ============================================================
# Unit test for the install.sh workspace registry.
#
# Hermetic: no network, no API key, no real install. It EXTRACTS the registry
# helpers from install.sh (the block between the ELNORA_REGISTRY_LIB markers)
# and sources them, so it tests the real shipping code, not a copy that can
# drift. The data layer (record / forget / dedup / created-preservation) is the
# part that can silently corrupt a user's registry, so that's what we lock down.
#
# The interactive resume menu reads from /dev/tty, so it's only exercised when a
# `script`-style pty is available (local macOS dev); in CI that part is skipped
# with a SKIP line rather than failing.
#
# Usage:  bash tests/registry/registry_test.sh
# Exit:   0 = all assertions passed, 1 = at least one failed.
# ============================================================
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALL_SH="$REPO_ROOT/install.sh"

pass=0
fail=0
ok()   { pass=$((pass + 1)); printf '  ok   - %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf '  FAIL - %s\n' "$1"; }
# assert_eq EXPECTED ACTUAL MESSAGE
assert_eq() { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3 (expected [$1], got [$2])"; fi; }

# --- Extract and source the real registry lib -------------------------------
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
LIB="$WORK/lib.sh"
awk '/ELNORA_REGISTRY_LIB_START/{f=1;next} /ELNORA_REGISTRY_LIB_END/{f=0} f' "$INSTALL_SH" > "$LIB"

if ! grep -q 'registry_record()' "$LIB"; then
    echo "[!] Could not extract the registry lib from $INSTALL_SH"
    echo "    (markers ELNORA_REGISTRY_LIB_START / _END missing or moved?)"
    exit 1
fi
# shellcheck disable=SC1090
. "$LIB"

# Redirect the registry into our sandbox and make timestamps deterministic.
REGISTRY_DIR="$WORK/cfg"
REGISTRY_FILE="$REGISTRY_DIR/workspaces.tsv"
NOW="2026-01-01T00:00:00Z"
_registry_now() { echo "$NOW"; }

datalines() { awk -F'\t' '!/^#/ && NF>=2' "$REGISTRY_FILE" 2>/dev/null; }
field() { awk -F'\t' -v p="$2" -v c="$3" '!/^#/ && $2==p {print $c; exit}' "$REGISTRY_FILE"; }

echo "registry data-layer tests"

# T1: no registry file yet -> resume menu bails without touching the tty.
( registry_resume_menu )
assert_eq "1" "$?" "resume menu returns 1 when no registry exists"

# T2: first record creates the file with exactly one data line.
registry_record "carmen-agents" "/Users/x/Documents/carmen-agents"
assert_eq "1" "$(datalines | wc -l | tr -d ' ')" "first record -> 1 data line"
assert_eq "carmen-agents" "$(field x "/Users/x/Documents/carmen-agents" 1)" "first record stores the name"

# T3: a second, different path appends a second line.
registry_record "old-agents" "/Users/x/Documents/old-agents"
assert_eq "2" "$(datalines | wc -l | tr -d ' ')" "second distinct record -> 2 data lines"

# T4: re-recording the SAME path must not duplicate; created is preserved,
#     last_run advances.
NOW="2026-02-02T22:22:22Z"
registry_record "carmen-agents" "/Users/x/Documents/carmen-agents"
assert_eq "2" "$(datalines | wc -l | tr -d ' ')" "re-record same path -> still 2 data lines (no dup)"
assert_eq "2026-01-01T00:00:00Z" "$(field x "/Users/x/Documents/carmen-agents" 3)" "re-record preserves original created"
assert_eq "2026-02-02T22:22:22Z" "$(field x "/Users/x/Documents/carmen-agents" 4)" "re-record advances last_run"

# T5: forget removes only the targeted entry.
registry_forget "/Users/x/Documents/old-agents"
assert_eq "1" "$(datalines | wc -l | tr -d ' ')" "forget -> 1 data line"
assert_eq "carmen-agents" "$(datalines | awk -F'\t' '{print $1}')" "forget removes the right entry"

# T6: header comment lines are always preserved (parser must skip them).
assert_eq "2" "$(grep -c '^#' "$REGISTRY_FILE")" "two header comment lines kept"

# T7: tab-delimited storage tolerates spaces in a path.
registry_record "spacey" "/Users/x/Documents/my agents"
assert_eq "spacey" "$(field x "/Users/x/Documents/my agents" 1)" "path containing a space round-trips"

# --- Optional: drive the interactive menu through a pty ---------------------
# Only when a usable `script` is present. The invocation differs between the
# BSD `script` (macOS) and util-linux `script` (most CI), so we detect and skip
# cleanly when we can't drive a pty rather than failing the suite.
echo "resume-menu interactive tests"
run_menu() {  # stdin = keystrokes; echoes the menu's RESULT line
    local keys="$1" runner="$WORK/run.sh"
    cat > "$runner" <<RUNEOF
. "$LIB"
REGISTRY_DIR="$REGISTRY_DIR"; REGISTRY_FILE="$REGISTRY_FILE"
WORKSPACE_NAME=""
if registry_resume_menu; then echo "RESULT:resume=\$WORKSPACE_NAME"; else echo "RESULT:fresh"; fi
RUNEOF
    if script --version 2>&1 | grep -qi 'util-linux'; then
        printf '%s' "$keys" | script -qec "bash '$runner'" /dev/null 2>/dev/null
    else
        printf '%s' "$keys" | script -q /dev/null bash "$runner" 2>/dev/null
    fi
}

if command -v script >/dev/null 2>&1; then
    # Seed: one ready folder, one missing folder.
    mkdir -p "$WORK/ready"
    : > "$REGISTRY_FILE"
    {
        printf '# h1\n# h2\n'
        printf 'ready-ws\t%s\t%s\t%s\n' "$WORK/ready" "$NOW" "$NOW"
        printf 'gone-ws\t%s\t%s\t%s\n' "$WORK/gone"  "$NOW" "$NOW"
    } > "$REGISTRY_FILE"

    out="$(run_menu '1
')"
    case "$out" in *"RESULT:resume=ready-ws"*) ok "menu: pick ready -> resume=ready-ws" ;;
        *) bad "menu: pick ready (got: $(printf '%s' "$out" | tr -d '\r' | grep RESULT))" ;; esac

    out="$(run_menu 'n
')"
    case "$out" in *"RESULT:fresh"*) ok "menu: choose 'n' -> fresh prompt" ;;
        *) bad "menu: choose 'n' (got: $(printf '%s' "$out" | tr -d '\r' | grep RESULT))" ;; esac

    out="$(run_menu '2
r
')"
    case "$out" in *"RESULT:resume=gone-ws"*) ok "menu: missing folder -> [r] recreate" ;;
        *) bad "menu: missing -> recreate (got: $(printf '%s' "$out" | tr -d '\r' | grep RESULT))" ;; esac
else
    echo "  SKIP - no 'script' utility; interactive menu validated by data-layer + manual test"
fi

echo ""
echo "registry tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

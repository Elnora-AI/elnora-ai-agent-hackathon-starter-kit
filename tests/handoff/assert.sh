#!/bin/bash
# ============================================================
# Handoff E2E -- post-state assertions (macOS / Linux)
# ============================================================
# Run AFTER the headless handoff completes. Verifies on disk
# that Claude actually did the Phase 2 work -- independent of
# what the transcript says.
#
# Usage:
#   tests/handoff/assert.sh <repo-dir> <transcript-path>
#
# Exits 0 if all assertions pass, 1 if any fail. Each failure
# prints what was expected vs. found so the workflow log is
# useful for debugging.
# ============================================================

set -u
set -o pipefail

REPO_DIR="${1:-$PWD}"
TRANSCRIPT="${2:-$HOME/handoff-transcript.jsonl}"

PASS=0
FAIL=0
FAIL_MSGS=()

ok()   { echo "  [OK] $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); FAIL_MSGS+=("$1"); }

cd "$REPO_DIR" || { echo "FATAL: cannot cd to $REPO_DIR"; exit 2; }

echo "==========================================="
echo "  Handoff E2E assertions"
echo "==========================================="
echo "  Repo:       $REPO_DIR"
echo "  Transcript: $TRANSCRIPT"
echo ""

# --- Elnora CLI auth ---
# The CLI persists credentials to ~/.elnora/profiles.toml via
# `elnora auth login --api-key ...`. Verify Claude actually authenticated
# the CLI (not just exported a useless .env file -- the CLI doesn't read
# .env, so writing it does nothing for future shells).
echo "[elnora auth]"
if [ -f "$HOME/.elnora/profiles.toml" ]; then
    ok "~/.elnora/profiles.toml exists"
    # Note: the CLI sets mode 600 itself; we don't re-check it here. The
    # customer-visible contract for the starter kit is "key persisted +
    # auth status returns success" (covered below) -- re-validating the
    # CLI's own file-mode behavior isn't this test's responsibility, and
    # there's no equivalent ACL check on Windows anyway.
    # Allow leading whitespace -- TOML lets `api_key = ...` appear indented
    # inside a [profile] table section, and the CLI is free to format that way.
    if grep -qE '^[[:space:]]*api_key[[:space:]]*=[[:space:]]*"elnora_live_' "$HOME/.elnora/profiles.toml"; then
        ok "profiles.toml contains api_key = elnora_live_*"
    else
        fail "profiles.toml missing api_key = \"elnora_live_*\" line"
    fi
else
    fail "~/.elnora/profiles.toml was not created (Claude did not run 'elnora auth login --api-key ...')"
fi
if elnora auth status >/dev/null 2>&1; then
    ok "elnora auth status returns success"
else
    fail "elnora auth status failed (CLI is not authenticated)"
fi

# --- git repo ---
echo ""
echo "[git]"
if [ -d .git ]; then
    ok ".git directory exists"
    commit_count=$(git -C "$REPO_DIR" log --oneline 2>/dev/null | wc -l | tr -d ' ')
    # Expected end-state is exactly 2 commits: "Initial commit" + the step 11
    # cleanup commit ("chore: remove one-shot install scaffolding"). Anything
    # less means cleanup didn't land; anything more means an unexpected extra
    # commit slipped in.
    if [ "$commit_count" -eq 2 ]; then
        ok "git history has $commit_count commits (initial + cleanup) on $(git -C "$REPO_DIR" symbolic-ref --short HEAD 2>/dev/null || echo '?')"
    elif [ "$commit_count" -eq 1 ]; then
        fail "git history has 1 commit (cleanup commit didn't land -- Phase 2 step 11 incomplete)"
    elif [ "$commit_count" -eq 0 ]; then
        fail "git history is empty (Claude did not run 'git commit' for the initial commit)"
    else
        fail "git history has $commit_count commits (expected exactly 2: initial + cleanup)"
    fi
    # Two branches based on whether the workflow provisioned a PAT and
    # asked the agent to do the GitHub bootstrap.
    remote_count=$(git -C "$REPO_DIR" remote 2>/dev/null | wc -l | tr -d ' ')
    if [ -n "${ELNORA_HANDOFF_REPO_NAME:-}" ]; then
        # PAT path -- expect exactly one remote 'origin' pointing at the
        # CI-named repo, with HEAD == origin/main and visibility = PRIVATE.
        if [ "$remote_count" -eq 1 ] && [ "$(git -C "$REPO_DIR" remote)" = "origin" ]; then
            ok "exactly one remote 'origin' configured"
        else
            fail "expected exactly one remote 'origin', found $remote_count: $(git -C "$REPO_DIR" remote | tr '\n' ' ')"
        fi
        origin_url=$(git -C "$REPO_DIR" remote get-url origin 2>/dev/null || echo "")
        case "$origin_url" in
            *"/$ELNORA_HANDOFF_REPO_NAME"*|*"/$ELNORA_HANDOFF_REPO_NAME.git"*)
                ok "origin URL contains repo name '$ELNORA_HANDOFF_REPO_NAME' ($origin_url)"
                ;;
            *)
                fail "origin URL does not reference '$ELNORA_HANDOFF_REPO_NAME': got '$origin_url'"
                ;;
        esac
        local_head=$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null || echo "")
        remote_head=$(git -C "$REPO_DIR" rev-parse origin/main 2>/dev/null || echo "")
        if [ -n "$local_head" ] && [ "$local_head" = "$remote_head" ]; then
            ok "local HEAD matches origin/main ($local_head)"
        else
            fail "local HEAD ($local_head) != origin/main ($remote_head)"
        fi
        # `gh repo view` needs auth. The agent exported GH_TOKEN earlier,
        # so gh inherits the token from the environment on this runner.
        if visibility=$(gh repo view "$ELNORA_HANDOFF_REPO_NAME" --json visibility --jq .visibility 2>/dev/null) && [ "$visibility" = "PRIVATE" ]; then
            ok "GitHub repo $ELNORA_HANDOFF_REPO_NAME visibility=PRIVATE"
        else
            fail "expected GitHub repo $ELNORA_HANDOFF_REPO_NAME visibility=PRIVATE, got '${visibility:-<unreachable>}'"
        fi
    else
        # Legacy headless path -- no PAT provisioned, GitHub bootstrap skipped.
        if [ "$remote_count" -eq 0 ]; then
            ok "no git remotes configured (expected -- GitHub bootstrap was skipped without ELNORA_HANDOFF_REPO_NAME)"
        else
            fail "expected 0 remotes (no PAT provisioned), found $remote_count: $(git -C "$REPO_DIR" remote | tr '\n' ' ')"
        fi
    fi
else
    fail ".git directory was not created"
fi

# --- Knowledge base config ---
# The doc tells the agent to ALWAYS write `.claude/knowledge-base.local.md`,
# even when no vault was found -- leaving `vault_path:` as the
# `<ABSOLUTE_PATH_TO_YOUR_VAULT>` placeholder. So the file's existence is
# always required; the placeholder-replaced check only fires when the test
# fixture actually staged a vault (signalled by KB_STAGED=1).
echo ""
echo "[knowledge base]"
if [ -f .claude/knowledge-base.local.md ]; then
    ok ".claude/knowledge-base.local.md exists"
    if [ "${KB_STAGED:-}" = "1" ]; then
        if grep -q '<ABSOLUTE_PATH_TO_YOUR_VAULT>' .claude/knowledge-base.local.md; then
            fail "knowledge-base.local.md still contains <ABSOLUTE_PATH_TO_YOUR_VAULT> placeholder (vault was staged; agent should have replaced it)"
        else
            ok "knowledge-base.local.md placeholder was replaced"
        fi
    else
        echo "  - placeholder-replacement check skipped (KB_STAGED unset; no vault was staged for this run)"
    fi
else
    fail ".claude/knowledge-base.local.md was not created"
fi

# --- CLAUDE.md self-cleanup ---
echo ""
echo "[CLAUDE.md self-cleanup]"
if grep -q '### First-run setup' CLAUDE.md; then
    fail "CLAUDE.md still contains '### First-run setup' block (should have self-deleted)"
else
    ok "CLAUDE.md '### First-run setup' block was removed"
fi

# --- Step 11 cleanup ---
# Phase 2 step 11 removes the one-shot install scaffolding (bootstrap
# downloaders, Phase 1 installers, this Phase 2 doc, the recovery doc, the
# integrity marker, and the .vscode/ handoff helpers). The expected
# end-state for the user is a clean repo containing only what they need.
echo ""
echo "[step 11 cleanup]"
cleanup_files="install.sh install.ps1 setup-mac.sh setup-windows.ps1 INSTALL_FOR_AGENTS.md RECOVERY.md .elnora-starter-kit-marker"
cleanup_ok=1
for f in $cleanup_files; do
    if [ -e "$f" ]; then
        fail "step 11 cleanup did not remove '$f' -- still present after handoff"
        cleanup_ok=0
    fi
done
if [ -d .vscode ]; then
    fail "step 11 cleanup did not remove '.vscode/' -- still present after handoff"
    cleanup_ok=0
fi
if [ "$cleanup_ok" -eq 1 ]; then
    ok "all one-shot scaffolding removed (install/setup scripts, INSTALL_FOR_AGENTS.md, RECOVERY.md, .vscode/, marker)"
fi

# --- INSTALL_FOR_AGENTS.md hardening (regression check, source-file based) ---
# Regression check: PR1 of the security plan removed the python3 -c bypass
# instructions that gave agents a generic file-write primitive against
# .claude/ paths. The doc still mentions `python3 -c` inside backticks
# ("do **not** use python3 -c ...") which is fine; we only fail on actual
# code-block invocations and on python file-opens against .claude/ paths.
#
# After step 11 cleanup the post-handoff repo no longer contains
# INSTALL_FOR_AGENTS.md, so we read it from the source checkout via
# ELNORA_KIT_SOURCE_DIR (the workflow exports the path of the kit
# checkout that fed the handoff). Falls back to PWD if unset (legacy
# call sites, or local dev runs that pre-date cleanup).
echo ""
echo "[INSTALL_FOR_AGENTS.md hardening]"
hardening_path=""
if [ -n "${ELNORA_KIT_SOURCE_DIR:-}" ] && [ -f "$ELNORA_KIT_SOURCE_DIR/INSTALL_FOR_AGENTS.md" ]; then
    hardening_path="$ELNORA_KIT_SOURCE_DIR/INSTALL_FOR_AGENTS.md"
elif [ -f INSTALL_FOR_AGENTS.md ]; then
    hardening_path="INSTALL_FOR_AGENTS.md"
fi
if [ -n "$hardening_path" ]; then
    if grep -nE "^[[:space:]]+python3? -c" "$hardening_path" >/dev/null 2>&1; then
        fail "$hardening_path contains an indented 'python3 -c' invocation (looks like coaching)"
    else
        ok "$hardening_path has no indented python3 -c invocations"
    fi
    if grep -nE "open\(['\"][^'\"]*\.claude/" "$hardening_path" >/dev/null 2>&1; then
        fail "$hardening_path contains a python open() call against .claude/ (sensitive-paths bypass)"
    else
        ok "$hardening_path has no python open() against .claude/ paths"
    fi
else
    echo "  - INSTALL_FOR_AGENTS.md not present in $REPO_DIR or via ELNORA_KIT_SOURCE_DIR -- hardening regression check skipped"
fi

# --- HANDOFF_COMPLETE marker in transcript ---
echo ""
echo "[transcript]"
if [ -f "$TRANSCRIPT" ]; then
    ok "transcript file exists ($(wc -l < "$TRANSCRIPT" | tr -d ' ') lines)"
    if grep -q 'HANDOFF_COMPLETE' "$TRANSCRIPT"; then
        ok "transcript contains HANDOFF_COMPLETE marker"
    else
        fail "transcript does not contain HANDOFF_COMPLETE marker"
    fi
    # Sanity check: did Claude actually authenticate + verify the Elnora CLI?
    # Match the auth/verification commands from INSTALL_FOR_AGENTS.md (steps 4-7).
    # We grep for any of: `elnora whoami`, `elnora doctor`, or `elnora auth login`
    # so the test fails if Claude only ran `elnora --version` and skipped the
    # actual auth check.
    if grep -qE 'elnora (whoami|doctor|auth (login|status))' "$TRANSCRIPT"; then
        ok "transcript shows Claude invoked an elnora auth/verification command"
    else
        fail "transcript shows no elnora auth/verification command (whoami|doctor|auth login|auth status)"
    fi
else
    fail "transcript file not found at $TRANSCRIPT"
fi

# --- Summary ---
echo ""
echo "==========================================="
echo "  Result: $PASS passed, $FAIL failed"
echo "==========================================="
if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "Failures:"
    for m in "${FAIL_MSGS[@]}"; do
        echo "  - $m"
    done
    exit 1
fi
exit 0

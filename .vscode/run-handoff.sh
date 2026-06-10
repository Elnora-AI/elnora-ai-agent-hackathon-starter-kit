#!/usr/bin/env bash
# ============================================================
# Phase 1 -> Phase 2 handoff helper (macOS / Linux)
# ============================================================
# Fired by .vscode/tasks.json on folderOpen. Consumes the one-shot sentinel
# `.vscode/.handoff-pending` (whose contents ARE the handoff prompt -- single
# source of truth lives in setup-mac.sh) plus its sibling
# `.vscode/.handoff-agent` (which names the agent to launch: claude or
# codex). On subsequent opens (sentinel absent), exits silently so the task
# is a no-op.

set -eu

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SENTINEL="$REPO_DIR/.vscode/.handoff-pending"
AGENT_FILE="$REPO_DIR/.vscode/.handoff-agent"

# No sentinel = nothing to do. This is the steady state on every folder
# open after the initial handoff. Exit 0 so VS Code's task UI doesn't show
# a spurious failure marker.
if [ ! -f "$SENTINEL" ]; then
    exit 0
fi

PROMPT="$(cat "$SENTINEL")"

# Which agent drives Phase 2. Allowlisted because this value is exec'd as a
# command: anything other than the two agents the kit installs collapses to
# the claude default (also covers pre-agent-file installs, where the file
# simply doesn't exist).
AGENT_BIN="claude"
if [ -f "$AGENT_FILE" ]; then
    case "$(tr -d '[:space:]' < "$AGENT_FILE")" in
        codex) AGENT_BIN="codex" ;;
    esac
fi
case "$AGENT_BIN" in
    codex) AGENT_NAME="Codex" ;;
    *)     AGENT_NAME="Claude" ;;
esac

# Delete the sentinel BEFORE launching the agent. If we delete after, a crash
# or Ctrl+C in the agent leaves the sentinel and would re-fire next
# folder-open with the same stale prompt. Pre-deleting also makes the handoff
# exactly one-shot regardless of whether the agent exits cleanly.
rm -f "$SENTINEL" "$AGENT_FILE"

# Belt-and-suspenders PATH fix. VS Code caches PATH at app launch time, so
# if VS Code was already running when setup-mac.sh installed the agent
# into ~/.local/bin, the integrated terminal won't see it on PATH.
# We prepend the canonical install dirs here. Harmless if already present
# (PATH dedup is the user's shell's problem, not ours -- the agent only needs
# to resolve once).
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

if ! command -v "$AGENT_BIN" >/dev/null 2>&1; then
    echo "[!] '$AGENT_BIN' command not found on PATH inside VS Code's terminal." >&2
    echo "    Quit VS Code fully (Cmd+Q) and reopen -- the integrated" >&2
    echo "    terminal caches PATH at app launch. If that doesn't help," >&2
    echo "    re-run setup: bash \"$REPO_DIR/setup-mac.sh\"" >&2
    exit 127
fi

cd "$REPO_DIR"

echo "==========================================="
echo "  Continuing Elnora setup with $AGENT_NAME"
echo "==========================================="
echo ""

# exec replaces this shell with the agent -- once Phase 2 wraps up, the
# user's integrated terminal lands at a normal shell prompt inside the repo.
exec "$AGENT_BIN" "$PROMPT"

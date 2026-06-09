#!/usr/bin/env bash
# ============================================================
# Phase 1 -> Phase 2 handoff helper (macOS / Linux)
# ============================================================
# Fired by .vscode/tasks.json on folderOpen. Consumes the one-shot sentinel
# `.vscode/.handoff-pending` (whose contents ARE the handoff prompt -- single
# source of truth lives in setup-mac.sh). On subsequent opens (sentinel
# absent), exits silently so the task is a no-op.

set -eu

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SENTINEL="$REPO_DIR/.vscode/.handoff-pending"

# No sentinel = nothing to do. This is the steady state on every folder
# open after the initial handoff. Exit 0 so VS Code's task UI doesn't show
# a spurious failure marker.
if [ ! -f "$SENTINEL" ]; then
    exit 0
fi

PROMPT="$(cat "$SENTINEL")"

# Delete the sentinel BEFORE launching claude. If we delete after, a crash
# or Ctrl+C in claude leaves the sentinel and would re-fire next folder-open
# with the same stale prompt. Pre-deleting also makes the handoff exactly
# one-shot regardless of whether claude exits cleanly.
rm -f "$SENTINEL"

# Belt-and-suspenders PATH fix. VS Code caches PATH at app launch time, so
# if VS Code was already running when setup-mac.sh installed Claude Code
# into ~/.local/bin, the integrated terminal won't see `claude` on PATH.
# We prepend the canonical install dirs here. Harmless if already present
# (PATH dedup is the user's shell's problem, not ours -- claude only needs
# to resolve once).
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

if ! command -v claude >/dev/null 2>&1; then
    echo "[!] 'claude' command not found on PATH inside VS Code's terminal." >&2
    echo "    Quit VS Code fully (Cmd+Q) and reopen -- the integrated" >&2
    echo "    terminal caches PATH at app launch. If that doesn't help," >&2
    echo "    re-run setup: ./setup-mac.sh" >&2
    exit 127
fi

cd "$REPO_DIR"

echo "==========================================="
echo "  Continuing Elnora setup with Claude"
echo "==========================================="
echo ""

# exec replaces this shell with claude -- once Phase 2 wraps up, the user's
# integrated terminal lands at a normal shell prompt inside the repo.
exec claude "$PROMPT"

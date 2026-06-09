#!/bin/bash
# ============================================================
# Elnora Starter Kit - One-liner Installer (macOS)
# ============================================================
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Elnora-AI/elnora-starter-kit/main/install.sh | bash
#
# Prompts for a workspace name (used for BOTH the local folder name AND
# the GitHub repo name created in Phase 2), downloads the starter kit
# tarball (no git required), extracts to ~/Documents/<workspace-name>,
# and runs setup-mac.sh.
# ============================================================

set -euo pipefail

REPO_OWNER="Elnora-AI"
REPO_NAME="elnora-starter-kit"
BRANCH="main"

# ---- Workspace name -------------------------------------------------------
# This name is used for BOTH the local folder under ~/Documents AND the
# GitHub repo we create later in Phase 2. Locking them in lockstep up
# front avoids a class of bugs where the local path and GitHub remote
# drift out of sync.
#
# Resolution order:
#   1. $ELNORA_WORKSPACE_NAME env var (CI / scripted runs).
#   2. Interactive prompt on /dev/tty (curl|bash leaves stdin closed,
#      so we read the user's tty directly, same pattern setup-mac.sh
#      uses for git config prompts).
#   3. Fallback to "elnora-starter-kit" so non-interactive contexts
#      with no env var (older test rigs, headless runners) still work.
#
# Validation enforces the project naming convention (see CLAUDE.md
# > Naming Conventions): lowercase letters, digits, and dashes only.
# No uppercase, no spaces, no underscores, no dots. Self-explaining
# names with the user's name as a prefix are encouraged
# (e.g. carmen-agents, carmen-vault, carmen-knowledge-base).
#
# Anchored on both ends with alphanumerics so we reject leading/trailing
# dashes and dash-only inputs (`-foo`, `foo-`, `--`, `-`). A leading dash
# would be parsed as a flag by `gh repo create` / `mkdir` later; a folder
# named `-rf` would be a particularly mean foot-gun. Single-char inputs
# (`a`, `1`) are still allowed via the optional middle group.
#
# This is stricter than GitHub's own repo-name rule ([A-Za-z0-9._-]+),
# so anything that passes here also passes `gh repo create`.
NAME_RE='^[a-z0-9]([a-z0-9-]*[a-z0-9])?$'

# Normalize $USER for the default suggestion: lowercase + replace
# spaces with dashes + strip illegal chars. Accounts/Macs sometimes
# have mixed-case usernames or spaces ("First Last"), and we still
# want a reasonable default the regex will accept.
_user_lower="$(printf '%s' "${USER:-me}" \
    | tr '[:upper:]' '[:lower:]' \
    | tr ' ' '-' \
    | tr -cd 'a-z0-9-')"
[ -z "$_user_lower" ] && _user_lower="me"
default_name="${_user_lower}-agents"

echo "==========================================="
echo "  Elnora Starter Kit - Bootstrap"
echo "==========================================="
echo ""

if [ -n "${ELNORA_WORKSPACE_NAME:-}" ]; then
    WORKSPACE_NAME="$ELNORA_WORKSPACE_NAME"
elif [ -c /dev/tty ] && (exec 3</dev/tty) 2>/dev/null; then
    echo "Pick a name for your workspace. This becomes BOTH:"
    echo "  - the local folder under ~/Documents/"
    echo "  - the GitHub repo we'll create for you in Phase 2"
    echo ""
    echo "Naming rules (project convention):"
    echo "  - lowercase letters, digits, and dashes only"
    echo "  - no spaces, no underscores, no uppercase"
    echo "  - self-explaining: ${_user_lower}-agents, ${_user_lower}-vault,"
    echo "    ${_user_lower}-knowledge-base, ${_user_lower}-filesystem, etc."
    echo ""
    while :; do
        printf "Workspace name [%s]: " "$default_name" > /dev/tty
        IFS= read -r reply < /dev/tty || reply=""
        WORKSPACE_NAME="${reply:-$default_name}"
        if [[ "$WORKSPACE_NAME" =~ $NAME_RE ]]; then
            break
        fi
        echo "  [!] '$WORKSPACE_NAME' isn't a legal name. Use lowercase letters, digits, and dashes only; must start and end with a letter or digit (no leading/trailing dash)." > /dev/tty
    done
    echo ""
else
    WORKSPACE_NAME="elnora-starter-kit"
fi

if ! [[ "$WORKSPACE_NAME" =~ $NAME_RE ]]; then
    echo "[!] ELNORA_WORKSPACE_NAME='$WORKSPACE_NAME' violates the project naming convention." >&2
    echo "    Allowed: lowercase letters, digits, and dashes; must start and end with a letter/digit (^[a-z0-9]([a-z0-9-]*[a-z0-9])?\$)." >&2
    exit 1
fi

TARGET_DIR="$HOME/Documents/$WORKSPACE_NAME"

echo "This will:"
echo "  1. Download the starter kit to $TARGET_DIR"
echo "  2. Run setup-mac.sh (installs Claude Code + dev tools)"
echo ""

# Always wipe + re-extract on every run. If the customer is running this
# script again it's because something didn't work the first time -- they
# want a fresh starting point, not a half-stale copy of last week's repo.
# System tools (Claude, Node, Python, brew, Obsidian) are NOT touched here:
# setup-mac.sh detects existing installs and updates in place, so re-running
# won't blow away a working toolchain.
#
# EXCEPTION: if the agent left a handoff resume marker
# (.elnora-handoff-resume.json) in this folder, refuse to wipe. The marker
# means a previous Phase 2 hit a GitHub-name collision and asked the user
# to re-run setup-mac.sh, NOT install.sh. Wiping would silently drop the
# resume state and the next agent session would start over instead of
# picking up at step 6c.3. Tell the user the right command and bail.
# Files inside $TARGET_DIR that are USER DATA (not kit-shipped) and must
# survive a re-run wipe. Customer-typed credentials and per-user config
# live here; losing them on re-install is a regression. .elnora-handoff
# -resume.json is also user-state but is handled separately above (we
# refuse to wipe at all when that marker exists, since the user needs to
# run setup-mac.sh, not install.sh).
PRESERVE_PATHS=(
    ".env"
    ".claude/knowledge-base.local.md"
    ".claude/settings.local.json"
)

if [ -d "$TARGET_DIR" ]; then
    if [ -f "$TARGET_DIR/.elnora-handoff-resume.json" ]; then
        echo "[!] $TARGET_DIR already contains an in-progress Phase 2 handoff" >&2
        echo "    (.elnora-handoff-resume.json marker present)." >&2
        echo "" >&2
        echo "    Don't re-run install.sh -- it would erase the resume state." >&2
        echo "    Instead, finish the handoff from the existing folder:" >&2
        echo "" >&2
        echo "      cd \"$TARGET_DIR\" && bash setup-mac.sh" >&2
        echo "" >&2
        exit 1
    fi
    echo "Existing starter kit detected at $TARGET_DIR"
    # Preserve user-data files across the wipe. Stash them in a temp dir
    # keyed off TARGET_DIR, then restore after re-extract. The temp dir
    # gets cleaned up on EXIT regardless of success/failure.
    PRESERVE_DIR="$(mktemp -d)"
    preserved_count=0
    for rel in "${PRESERVE_PATHS[@]}"; do
        if [ -e "$TARGET_DIR/$rel" ]; then
            mkdir -p "$PRESERVE_DIR/$(dirname "$rel")"
            cp -p "$TARGET_DIR/$rel" "$PRESERVE_DIR/$rel"
            preserved_count=$((preserved_count + 1))
            echo "  Preserving $rel across wipe."
        fi
    done
    if [ "$preserved_count" -eq 0 ]; then
        # Nothing user-customized to keep; clean up the empty stash dir.
        rm -rf "$PRESERVE_DIR"
        unset PRESERVE_DIR
    fi
    echo "Wiping for a fresh install (system tools like Claude, Node, Python are kept)..."
    rm -rf "$TARGET_DIR"
fi

echo "Downloading starter kit tarball..."
TARBALL_URL="https://github.com/$REPO_OWNER/$REPO_NAME/archive/refs/heads/$BRANCH.tar.gz"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR" "${PRESERVE_DIR:-/nonexistent-noop}"' EXIT

if curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 30 --max-time 300 "$TARBALL_URL" | tar xz -C "$TMP_DIR"; then
    mkdir -p "$(dirname "$TARGET_DIR")"
    # GitHub's tarball extracts to "<repo>-<branch>". Verify that path
    # exists before moving -- protects against branch names that contain
    # slashes (GitHub rewrites '/' to '-' inside the archive but $BRANCH
    # would still carry the slash) and against silent tar failures
    # mid-pipe that don't trip curl's exit code. install.ps1 already
    # has the equivalent check; parity matters.
    EXTRACTED="$TMP_DIR/$REPO_NAME-$BRANCH"
    if [ ! -d "$EXTRACTED" ]; then
        echo "[!] Expected extracted folder not found: $EXTRACTED" >&2
        echo "    The tarball may have changed shape, or tar failed silently." >&2
        exit 1
    fi
    mv "$EXTRACTED" "$TARGET_DIR"
    echo "Extracted to $TARGET_DIR"
    # Restore any user-data files we stashed before the wipe. Has to
    # happen AFTER the mv so we're laying these on top of the freshly
    # extracted tarball contents (which carry the .gitignored templates,
    # not the user's filled-in versions).
    if [ -n "${PRESERVE_DIR:-}" ] && [ -d "$PRESERVE_DIR" ]; then
        for rel in "${PRESERVE_PATHS[@]}"; do
            if [ -e "$PRESERVE_DIR/$rel" ]; then
                mkdir -p "$TARGET_DIR/$(dirname "$rel")"
                cp -p "$PRESERVE_DIR/$rel" "$TARGET_DIR/$rel"
                echo "  Restored $rel."
            fi
        done
    fi
else
    echo "[!] Failed to download starter kit from $TARBALL_URL" >&2
    echo "    Check your internet connection and retry:" >&2
    echo "      curl -fsSL https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$BRANCH/install.sh | bash" >&2
    exit 1
fi

cd "$TARGET_DIR"

# Write a marker file recording the SHA256 of INSTALL_FOR_AGENTS.md as it was
# extracted from GitHub. setup-mac.sh verifies this hash before handing off to
# claude with bypassPermissions -- if a third party tampers with the doc
# between extract and setup, the verify step trips and the handoff aborts.
# This is the trust anchor for the headless Phase 2 flow.
#
# Every install.sh run is a fresh extract from the official tarball (we
# always wipe + re-download above), so re-blessing here is correct: the doc
# is always exactly what GitHub just served, and the marker stays in lockstep
# with whatever INSTALL_FOR_AGENTS.md content the customer is about to run.
if [ -f "$TARGET_DIR/INSTALL_FOR_AGENTS.md" ]; then
    install_for_agents_sha=$(shasum -a 256 "$TARGET_DIR/INSTALL_FOR_AGENTS.md" | awk '{print $1}')
    cat > "$TARGET_DIR/.elnora-starter-kit-marker" <<EOF
version: 1
created: $(date -u +%Y-%m-%dT%H:%M:%SZ)
install_for_agents_sha256: $install_for_agents_sha
EOF
    echo "  Wrote integrity marker (.elnora-starter-kit-marker)."
fi

# Strip dev/CI scaffolding the customer can't use anyway. tests/handoff/ exists
# for our CI assertions; .github/ holds workflows + dependabot config that only
# fire on the official Elnora-AI/elnora-starter-kit repo. Both ride along in the
# tarball and would just clutter the customer's directory. rm -rf is idempotent
# so this is safe on both fresh and re-run installs.
echo "Stripping dev/CI scaffolding (tests/, .github/)..."
rm -rf "$TARGET_DIR/tests" "$TARGET_DIR/.github"
echo "  Done."

chmod +x setup-mac.sh
echo ""

# Redirect stdin from /dev/tty so the setup script's `read` prompts (git
# config name/email) still work when install.sh was invoked via
# `curl ... | bash` (curl's pipe leaves stdin closed). Fall back to the
# inherited stdin when /dev/tty isn't accessible - e.g. CI runners with no
# controlling terminal, where the redirect itself would fail with "no such
# device" and abort the script before setup-mac.sh ran.
if [ -c /dev/tty ] && (exec 3</dev/tty) 2>/dev/null; then
    exec ./setup-mac.sh < /dev/tty
else
    exec ./setup-mac.sh
fi

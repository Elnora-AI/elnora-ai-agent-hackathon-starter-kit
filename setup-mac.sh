#!/bin/bash
# ============================================================
# Claude Code Setup - macOS
# ============================================================
# Installs a complete Claude Code development environment:
# Claude Code CLI, Homebrew, Node.js, Git, Python,
# VS Code, GitHub CLI, and Obsidian.
#
# Run from Terminal (or VS Code terminal):
#   chmod +x setup-mac.sh && ./setup-mac.sh
#
# Error handling: the script CONTINUES on failure. Each step is
# isolated - if one install fails (network, permissions, broken
# formula, etc.), remaining steps still run. On any failure you
# get a structured FAILURE box with the exit code, last 10 lines
# of captured stderr, and a remediation hint. At the end of the
# run a recap block prints remediation for each failed step.
# ============================================================

# NOTE: deliberately NOT using `set -e` so one failure does not abort the rest.
set -u

# Self-defense: ensure user-local bin is on PATH from line 1.
# This makes the script work even when re-run from a terminal that was
# opened before any prior install (where ~/.local/bin isn't yet in the
# inherited PATH). Idempotent -- no harm if the dir doesn't exist yet.
export PATH="$HOME/.local/bin:$PATH"

# Default-on logging. Tee everything (stdout + stderr) to a log file in $HOME.
# Overwrites on each run - re-runs are idempotent, so keeping old logs around
# isn't useful. Users hitting problems can paste the file path in support chats.
LOG_FILE="$HOME/claude-starter-install.log"
# Pre-create the file with mode 600 BEFORE tee touches it. tee honors umask
# (typically 0644), so without this the log lands world-readable and any
# other user on a shared Mac can read it. Locking the file down keeps any
# sensitive output that scrolls through it private -- belt-and-suspenders.
( umask 077 && : > "$LOG_FILE" ) || true
chmod 600 "$LOG_FILE" 2>/dev/null || true
exec > >(tee "$LOG_FILE") 2>&1

FAILED_STEPS=()

# ------------------------------------------------------------
# Resume / checkpoint state
# ------------------------------------------------------------
# This script is safe to run as many times as you like - already-installed
# tools and existing logins are detected live and skipped, so a re-run never
# reinstalls or re-does what is already in place. The checkpoint file below
# records which one-time actions (Claude / Codex / GitHub sign-in) finished,
# so a re-run can announce "resuming" instead of feeling like starting over.
#
# Why this matters: the single most common place people stop is the Claude
# Code sign-in step. If that happens - or the script is interrupted anywhere
# else - just run it again. It picks up right where you left off.
#
#   Resume (default):   bash setup-mac.sh
#   Start over clean:   bash setup-mac.sh --fresh   (--restart is an alias)
#
# ELNORA_SETUP_STATE_FILE overrides the path (used by the test suite so a
# local re-run of the smoke test starts from a clean slate).
SETUP_STATE_FILE="${ELNORA_SETUP_STATE_FILE:-$HOME/.claude-starter-setup-state}"
# Accept --fresh / --restart in any argument position (matches setup-windows.ps1,
# which scans all of $args), not just as the first positional argument.
for _arg in "$@"; do
    case "$_arg" in
        --fresh|--restart)
            rm -f "$SETUP_STATE_FILE" 2>/dev/null || true
            echo "  (--fresh: cleared saved progress - starting from the beginning.)"
            break
            ;;
    esac
done
# Create the state file up front (mode 600, same as the log) so is_done/
# mark_done never have to special-case "file missing".
( umask 077 && : >> "$SETUP_STATE_FILE" ) 2>/dev/null || touch "$SETUP_STATE_FILE" 2>/dev/null || true

# is_done <name>   -> exit 0 if this checkpoint was reached on a previous run.
# mark_done <name> -> record a checkpoint (idempotent; one name per line).
is_done()   { grep -qxF "$1" "$SETUP_STATE_FILE" 2>/dev/null; }
mark_done() {
    is_done "$1" || printf '%s\n' "$1" >> "$SETUP_STATE_FILE" 2>/dev/null || \
        echo "  [WARN] Could not write checkpoint '$1' to $SETUP_STATE_FILE - a re-run will repeat this step instead of resuming past it." >&2
}

# ------------------------------------------------------------
# remediation_hint "<step label>"
# ------------------------------------------------------------
# Returns a multi-line, step-specific remediation message. Used by
# run_step (immediate failure context) AND by the end-of-run recap
# (so the user gets a full punch list of what to do next).
remediation_hint() {
    local label="$1"
    case "$label" in
        Homebrew*)
            cat <<'EOF'
Common causes:
  - Corporate firewall blocking github.com or raw.githubusercontent.com
  - Xcode Command Line Tools not fully installed (check: xcode-select -p)
  - Less than ~1 GB free disk space
  - Keychain prompt was dismissed during install
Manual install:
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
If the install finishes but 'brew' is not on PATH, add one of these lines
to ~/.zprofile based on your Mac:
  eval "$(/opt/homebrew/bin/brew shellenv)"       # Apple Silicon (M1/M2/M3/M4)
  eval "$(/usr/local/bin/brew shellenv)"          # Intel Macs
Then open a NEW terminal and re-run this script.
EOF
            ;;
        Node.js*)
            cat <<'EOF'
Try manually:
  brew install node@22
  brew link --force --overwrite node@22
Verify in a NEW terminal window:
  node --version       # should print v22.x.x
  npm --version
node@22 is keg-only on Homebrew - the `brew link --force --overwrite` step
is required for `node` to appear in /opt/homebrew/bin. If you prefer the
latest Node instead of the pinned LTS, run `brew install node` - but your
Node major may then differ from the Windows workshop script's pin.
If 'brew: command not found', brew itself isn't on PATH - fix that first
(see the Homebrew remediation above) and re-run this script.
EOF
            ;;
        Git*)
            cat <<'EOF'
Try manually:
  brew install git
Verify:
  git --version
  which git            # should be /opt/homebrew/bin/git or /usr/local/bin/git
macOS ships a system git at /usr/bin/git that may be older. If brew's git
isn't being used, your PATH has /usr/bin before Homebrew - fix the order
in ~/.zprofile (the brew shellenv line should come AFTER any PATH exports).
EOF
            ;;
        "Git config"*)
            cat <<'EOF'
Set the values manually:
  git config --global user.name  "Your Full Name"
  git config --global user.email "you@example.com"
  git config --global init.defaultBranch main
Verify all three at once:
  git config --global --list | grep -E 'user\.|init\.'
EOF
            ;;
        "Python 3"*)
            cat <<'EOF'
Try manually:
  brew install python@3.12
  brew link --force --overwrite python@3.12
Verify:
  python3 --version      # should print "Python 3.12.x"
  which python3          # should NOT be /usr/bin/python3 (that's the Xcode stub)
python@3.12 is keg-only on Homebrew - the `brew link --force --overwrite`
step is required for `python3` to appear in /opt/homebrew/bin.
If python3 still resolves to /usr/bin/python3 or a stale version after install:
  1. Open a NEW terminal (or: eval "$(/opt/homebrew/bin/brew shellenv)")
  2. Run `which python3` again
  3. If still wrong, your PATH has /usr/bin (or another prefix with an old
     python3) BEFORE /opt/homebrew/bin - fix the order in ~/.zprofile. The
     brew shellenv line should be the LAST PATH-modifying line in the file.
EOF
            ;;
        "VS Code"*)
            cat <<'EOF'
Try manually:
  brew install --cask visual-studio-code
Or download the installer directly:
  https://code.visualstudio.com/download
If the 'code' command doesn't work in terminal after install:
  1. Open VS Code
  2. Press Cmd+Shift+P
  3. Run: "Shell Command: Install 'code' command in PATH"
  4. Open a new terminal and try `code --version`
EOF
            ;;
        "Claude Code"*)
            cat <<'EOF'
Try manually:
  brew install --cask claude-code
If brew fails, use Anthropic's installer script:
  curl -fsSL https://claude.ai/install.sh | bash
Or install via npm (requires Node.js):
  npm install -g @anthropic-ai/claude-code
Docs: https://docs.claude.com/en/docs/claude-code/overview
Verify in a NEW terminal:
  claude --version
EOF
            ;;
        "GitHub CLI"*)
            cat <<'EOF'
Try manually:
  brew install gh
Verify:
  gh --version
Then authenticate:
  gh auth login       # choose GitHub.com, HTTPS, then browser login
EOF
            ;;
        Obsidian*)
            cat <<'EOF'
Try manually:
  brew install --cask obsidian
Or download the installer:
  https://obsidian.md/download
This step is OPTIONAL - you can skip it if you don't plan to use a
knowledge base. Nothing else in this setup depends on Obsidian.
EOF
            ;;
        "Projects folder"*)
            cat <<'EOF'
Try manually:
  mkdir -p "$HOME/Documents/Projects"
If mkdir fails, check your Documents folder:
  ls -ld "$HOME/Documents"
It should exist and be owned by your user. If ownership is wrong (e.g.,
after a Migration Assistant restore), repair it with:
  sudo chown -R "$(whoami)":staff "$HOME/Documents"
EOF
            ;;
        *)
            echo "No specific remediation available - scroll up to see the captured output."
            ;;
    esac
}

# ------------------------------------------------------------
# run_step "<label>" <command> [args...]
# ------------------------------------------------------------
# Runs a command with live output. On failure prints a structured FAILURE
# box with the exit code, the exact command, the last 10 lines of captured
# output, and a step-specific remediation hint.
#
# Stream handling: we merge stderr into stdout, then tee the merged stream
# both to the capture file AND to fd 3 (the original stdout, i.e. the
# terminal). That way the failure box quotes whatever the command actually
# printed -- important because brew, npm, curl, etc. emit their error
# messages on stdout, not stderr, so capturing stderr alone left the box
# empty for the most common failures. PIPESTATUS[0] preserves the command's
# exit code through the pipe (otherwise we'd get tee's exit code, always 0).
#
# WARNING for future maintainers: the FAILURE box echoes "$*" verbatim.
# Today no caller passes a secret as a positional arg (the API key path
# uses `read -rs` and stays in a local var). If you ever route a secret
# through here -- e.g. an OAuth token in argv -- the failure box will leak
# it to both the terminal and $LOG_FILE. Pre-redact or wrap such commands
# in a small helper that prints a sanitized command line instead.
run_step() {
    local label="$1"; shift
    local errfile code
    errfile="$(mktemp 2>/dev/null)" || errfile="/tmp/claude-setup-err.$$"
    { "$@" 2>&1 | tee "$errfile" >&3; code=${PIPESTATUS[0]}; } 3>&1
    if [ "$code" -eq 0 ]; then
        rm -f "$errfile"
        return 0
    fi
    echo "" >&2
    echo "  +- FAILURE: $label" >&2
    echo "  | Exit code: $code" >&2
    echo "  | Command:   $*" >&2
    if [ -s "$errfile" ]; then
        echo "  |" >&2
        echo "  | Captured output (last 10 lines):" >&2
        tail -n 10 "$errfile" 2>/dev/null | sed 's/^/  |   /' >&2
    fi
    echo "  |" >&2
    echo "  | What to do:" >&2
    remediation_hint "$label" | sed 's/^/  |   /' >&2
    echo "  +----------------------------------------------------------" >&2
    echo "" >&2
    FAILED_STEPS+=("$label (exit $code)")
    rm -f "$errfile"
    return "$code"
}

echo "==========================================="
echo "  Claude Code Setup for macOS"
echo "==========================================="
echo "  Log: $LOG_FILE"
echo ""

# If we have saved progress from an earlier run, say so up front - so the
# "already installed / Skipping" lines below clearly read as "resuming",
# not "starting over".
if [ -s "$SETUP_STATE_FILE" ]; then
    echo "  Resuming where a previous run left off - finished steps are skipped."
    echo "  (To start over from scratch instead:  bash setup-mac.sh --fresh)"
    echo ""
fi

# --- Prerequisite: Xcode Command Line Tools ---
# Homebrew depends on these. On a fresh Mac the first `brew install` triggers a
# blocking GUI dialog - we check upfront so the user isn't surprised mid-script.
if ! xcode-select -p &>/dev/null; then
    echo "[pre] Xcode Command Line Tools are REQUIRED but not installed."
    echo ""
    echo "  A system dialog should appear asking you to install them."
    echo "    - Click 'Install' (NOT 'Get Xcode' - the full Xcode is ~12 GB"
    echo "      and is not needed; we only want the Command Line Tools)"
    echo "    - Wait for the install to finish (~5-10 minutes on fast internet)"
    echo "    - Re-run this script AFTER the install completes"
    echo ""
    echo "  Triggering the install prompt now..."
    xcode-select --install 2>/dev/null || true
    echo ""
    echo "  TROUBLESHOOTING:"
    echo "    - No dialog appeared?  Run manually:  xcode-select --install"
    echo "    - Already have full Xcode.app? Confirm the CLT path exists:"
    echo "        xcode-select -p"
    echo "      It should return something like /Applications/Xcode.app/Contents/Developer"
    echo "      or /Library/Developer/CommandLineTools. If it does, re-run this script."
    echo "    - Corporate laptop blocking CLT install? Ask IT to install"
    echo "      \"Command Line Tools for Xcode\" from Apple's Developer Downloads:"
    echo "        https://developer.apple.com/download/all/?q=command%20line%20tools"
    echo ""
    # Exit non-zero so the curl | bash bootstrap (and any wrapping terminal)
    # surfaces this as a failure. Exiting 0 here made the one-liner appear
    # to succeed while no real setup had happened - the user would close the
    # terminal, open VS Code, and find nothing worked.
    exit 1
fi

# --- Coding agent selection (set by install.sh; default to claude) ---
# $ELNORA_AGENT is claude | codex | both. $ELNORA_HANDOFF_AGENT (claude | codex)
# is the one that finishes Phase 2. A direct `bash setup-mac.sh` run (no
# install.sh) defaults to claude so existing muscle memory still works.
ELNORA_AGENT="$(printf '%s' "${ELNORA_AGENT:-claude}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
case "$ELNORA_AGENT" in claude|codex|both) ;; *) ELNORA_AGENT="claude" ;; esac
if [ "$ELNORA_AGENT" = "both" ]; then
    ELNORA_HANDOFF_AGENT="$(printf '%s' "${ELNORA_HANDOFF_AGENT:-claude}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
    case "$ELNORA_HANDOFF_AGENT" in claude|codex) ;; *) ELNORA_HANDOFF_AGENT="claude" ;; esac
else
    ELNORA_HANDOFF_AGENT="$ELNORA_AGENT"
fi
# True when $1 (claude|codex) is among the installed agent(s).
agent_installed() { case "$ELNORA_AGENT" in "$1"|both) return 0 ;; *) return 1 ;; esac; }

# --- [1/9] AI coding agent(s) (installed FIRST - zero dependencies) ---
# Both Claude Code and Codex ship self-contained native installers that need
# no prerequisites (not even brew or node), so whichever the user picked is
# the very first thing on the machine, writing its binary under ~/.local/bin
# and auto-updating itself. Codex's native installer host can be unreachable
# from CI/datacenter IPs (HTTP 403); when that happens we transparently fall
# back to the npm package after Node lands (see the fallback below step 3).
if agent_installed claude; then
    if ! command -v claude &> /dev/null; then
        echo "[1/9] Installing Claude Code..."
        echo "  Using Anthropic's native installer (no prerequisites required)."
        # `set -o pipefail` - without it, a failed curl (404, DNS, network hiccup)
        # would send empty stdin to bash, which then exits 0 and the whole step
        # looks like a silent success. pipefail propagates curl's non-zero exit
        # through the pipe so run_step can catch and remediate it.
        if run_step "Claude Code" /bin/bash -c "set -o pipefail; curl -fsSL https://claude.ai/install.sh | bash"; then
            # Make `claude` visible in THIS shell without requiring a new terminal.
            # persist_local_bin_path below ensures future shells inherit the
            # PATH entry too (the installer's own profile update is unreliable
            # on re-runs).
            export PATH="$HOME/.local/bin:$PATH"
            echo "  Done. Version: $(claude --version 2>/dev/null || echo 'installed - restart terminal')"
        fi
    else
        echo "[1/9] Claude Code already installed: $(claude --version). Skipping."
    fi
fi
# Set when the native Codex installer can't run here, so the post-Node step
# below retries via npm (mirrors setup-windows.ps1, which installs Codex from
# npm after Node). chatgpt.com/codex/install.sh works for real users but is
# blocked (HTTP 403) from some CI/datacenter IPs, so a hard failure here would
# be wrong - we just defer to the reliable npm path.
_codex_needs_npm=0
if agent_installed codex; then
    if ! command -v codex &> /dev/null; then
        echo "[1/9] Installing Codex..."
        echo "  Trying OpenAI's native installer (no prerequisites required)."
        # Don't route this through run_step: a non-zero exit here is recoverable
        # (we fall back to npm after Node), so it must not land in FAILED_STEPS
        # or print a scary remediation box. set -o pipefail propagates a failed
        # curl through the pipe so we correctly detect the 403/network case.
        /bin/bash -c "set -o pipefail; curl -fsSL https://chatgpt.com/codex/install.sh | sh" >/dev/null 2>&1 || true
        export PATH="$HOME/.local/bin:$PATH"
        hash -r 2>/dev/null || true
        if command -v codex &> /dev/null; then
            echo "  Done. Version: $(codex --version 2>/dev/null || echo 'installed - restart terminal')"
        else
            echo "  Native installer unavailable here - will install Codex via npm after Node."
            _codex_needs_npm=1
        fi
    else
        echo "[1/9] Codex already installed: $(codex --version). Skipping."
    fi
fi

# --- [2/9] Homebrew ---
# Always try to load brew shellenv if a brew binary exists - VS Code's terminal
# can inherit a stale PATH that doesn't include brew's prefix, which would make
# `command -v brew` return false and send us down the wrong branch.
for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$candidate" ]; then
        eval "$("$candidate" shellenv)"
        break
    fi
done

# Helper: append `export PATH="$HOME/.local/bin:$PATH"` to the user's zsh
# login profile so new terminals pick up Claude Code automatically.
#
# Why this exists: Anthropic's native installer (claude.ai/install.sh) is
# inconsistent about persisting PATH on re-runs. When the binary already
# exists at ~/.local/bin/claude (e.g. customer is re-running setup after
# a partial install), the installer prints a "Native installation exists
# but ~/.local/bin is not in your PATH" notice and expects the user to
# manually run the echo command -- it does NOT update ~/.zshrc itself in
# that path. Customers ended up with claude installed but unreachable
# from VS Code's terminal. Mirrors persist_brew_path's belt-and-suspenders
# approach. Idempotent: skips writing if the line is already in the file.
persist_local_bin_path() {
    local shell_profile="$HOME/.zprofile"
    [ "$(basename "${SHELL:-}")" = "bash" ] && shell_profile="$HOME/.bash_profile"
    # shellcheck disable=SC2016  # literal $HOME -- zsh expands at shell start, not now
    local export_line='export PATH="$HOME/.local/bin:$PATH"'
    if ! grep -Fq "$export_line" "$shell_profile" 2>/dev/null; then
        {
            echo ""
            echo "# Added by Elnora AI Agent Hackathon Starter Kit setup-mac.sh"
            echo "$export_line"
        } >> "$shell_profile"
        echo "  Persisted ~/.local/bin to PATH in $shell_profile (open a fresh terminal to inherit it)."
    fi
}

# Run the helper once now that the Claude Code install step above is
# done. Idempotent if the line is already there. Catches both the fresh
# install case (where Anthropic's installer often skips this step on
# non-interactive `curl | bash` invocations) and the re-run case (where the
# installer skips its shell-profile update because the binary already exists).
persist_local_bin_path

# Helper: append brew shellenv to the user's shell profile so new terminals pick
# up brew automatically. Homebrew's own installer does NOT do this reliably -
# without it, every future terminal shows `claude: command not found` & friends.
persist_brew_path() {
    local brew_prefix="$1"
    local shell_profile="$HOME/.zprofile"
    [ "$(basename "${SHELL:-}")" = "bash" ] && shell_profile="$HOME/.bash_profile"
    local brew_eval="eval \"\$($brew_prefix/bin/brew shellenv)\""
    if ! grep -Fq "$brew_eval" "$shell_profile" 2>/dev/null; then
        {
            echo ""
            echo "# Added by Elnora AI Agent Hackathon Starter Kit setup-mac.sh"
            echo "$brew_eval"
        } >> "$shell_profile"
        echo "  Ensuring shell profile loads Homebrew (idempotent) -> $shell_profile."
    fi
}

if ! command -v brew &> /dev/null; then
    echo "[2/9] Installing Homebrew..."
    echo "  Heads-up: this takes 5-15 min and will prompt for your Mac login"
    echo "  password. Password characters won't show as you type - that's normal."
    # Fetch the installer first so we can detect curl failures explicitly.
    # The previous form `bash -c "$(curl -fsSL ...)"` silently no-op'd when
    # curl failed (DNS, 404, network) -- `$(curl ...)` expanded to empty,
    # `bash -c ""` exited 0, and we'd hit the success branch with no brew.
    # We don't pipe through a second `bash` (the Claude Code pattern) because
    # Homebrew's installer is interactive: it needs to prompt for a sudo
    # password and read the "Press RETURN to continue" key, and we want to
    # leave its stdin exactly the way it was.
    brew_installer_script=""
    if ! brew_installer_script="$(curl -fsSL --connect-timeout 30 --max-time 300 https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        brew_curl_code=$?
        echo "" >&2
        echo "  +- FAILURE: Homebrew (curl could not fetch install.sh, exit $brew_curl_code)" >&2
        echo "  | Could not download https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" >&2
        echo "  |" >&2
        echo "  | What to do:" >&2
        remediation_hint "Homebrew" | sed 's/^/  |   /' >&2
        echo "  +----------------------------------------------------------" >&2
        echo "" >&2
        FAILED_STEPS+=("Homebrew (curl exit $brew_curl_code)")
        brew_installer_script=""
    fi
    # Skip the installer run entirely if curl already failed above -- we
    # already printed a FAILURE box and recorded the step. Otherwise run
    # the installer and branch on its exit.
    brew_installer_ran=0
    brew_installer_ok=0
    if [ -n "$brew_installer_script" ]; then
        brew_installer_ran=1
        if /bin/bash -c "$brew_installer_script"; then
            brew_installer_ok=1
        else
            brew_code=$?
        fi
    fi
    if [ "$brew_installer_ok" = "1" ]; then
        if [ -x /opt/homebrew/bin/brew ]; then
            BREW_PREFIX="/opt/homebrew"
        elif [ -x /usr/local/bin/brew ]; then
            BREW_PREFIX="/usr/local"
        else
            echo "" >&2
            echo "  +- FAILURE: Homebrew (binary missing after install)" >&2
            echo "  | The installer reported success but no brew binary was found at" >&2
            echo "  | /opt/homebrew/bin/brew (Apple Silicon) or /usr/local/bin/brew (Intel)." >&2
            echo "  |" >&2
            echo "  | This usually means the installer exited early - e.g. a keychain" >&2
            echo "  | prompt was dismissed, a sudo password timed out, or the network" >&2
            echo "  | call to fetch the tap failed. Scroll up to see the installer output." >&2
            echo "  |" >&2
            echo "  | What to do:" >&2
            remediation_hint "Homebrew" | sed 's/^/  |   /' >&2
            echo "  +----------------------------------------------------------" >&2
            echo "" >&2
            FAILED_STEPS+=("Homebrew (binary missing after install)")
            BREW_PREFIX=""
        fi
        if [ -n "$BREW_PREFIX" ]; then
            eval "$("$BREW_PREFIX/bin/brew" shellenv)"
            persist_brew_path "$BREW_PREFIX"
            echo "  Done."
        fi
    elif [ "$brew_installer_ran" = "1" ]; then
        echo "" >&2
        echo "  +- FAILURE: Homebrew (installer exited $brew_code)" >&2
        echo "  | The Homebrew install script did not complete successfully." >&2
        echo "  | Scroll up - the installer's own error output above explains why." >&2
        echo "  |" >&2
        echo "  | Later brew-dependent steps (Node, Git, Python, VS Code, Claude Code," >&2
        echo "  | GitHub CLI, Obsidian) will also fail until Homebrew is installed." >&2
        echo "  |" >&2
        echo "  | What to do:" >&2
        remediation_hint "Homebrew" | sed 's/^/  |   /' >&2
        echo "  +----------------------------------------------------------" >&2
        echo "" >&2
        FAILED_STEPS+=("Homebrew (installer exit $brew_code)")
    fi
    # When brew_installer_ran=0 (curl failure above), we already printed and
    # recorded the failure, so fall through silently.
else
    echo "[2/9] Homebrew already installed. Skipping."
    # Persist the PATH even on skip - prior runs may have installed brew without
    # editing the shell profile.
    if [ -x /opt/homebrew/bin/brew ]; then
        persist_brew_path "/opt/homebrew"
    elif [ -x /usr/local/bin/brew ]; then
        persist_brew_path "/usr/local"
    fi
fi

# --- [3/9] Node.js 22 LTS (pinned for Mac/Windows parity) ---
# Pinned to the 22.x LTS line so Mac and Windows workshop attendees land on the
# same major. node@22 is keg-only on Homebrew - without `brew link --force
# --overwrite` no `node` symlink appears in /opt/homebrew/bin and the rest of
# this script's `command -v node` checks fail.
node_major_ok=false
if command -v node &> /dev/null; then
    node_major="$(node --version 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/')"
    if [ -n "$node_major" ] && [ "$node_major" -ge 22 ]; then
        node_major_ok=true
    fi
fi
if ! $node_major_ok; then
    echo "[3/9] Installing Node.js 22 LTS..."
    # Suppress brew's post-install hints (the "==> Caveats" wall and the
    # "node@22 was installed but not linked..." warning). The next line
    # always runs `brew link --force --overwrite node@22`, which resolves
    # the "not linked" condition - so those caveats are obsolete by the
    # time the user reads them, and they read like a scary failure to a
    # beginner. HOMEBREW_NO_ENV_HINTS=1 trims them down without hiding
    # genuine error output, so run_step's capture still has something
    # meaningful to quote in the FAILURE box if the install fails.
    #
    # CI-only: GitHub's macos runner image preinstalls and links node@20
    # (or whatever LTS the image baseline shipped). When `brew install
    # node@22` runs against an image that already has a different node@N
    # linked, brew emits a yellow `##[warning]node@22 was installed but
    # not linked because node@<other> is already linked` annotation that
    # the next `brew link --force --overwrite` resolves anyway -- but the
    # warning surfaces in the GH Actions UI as run-summary noise. Pre-
    # unlink whatever node is linked before installing so the warning
    # never fires. Real-user machines almost never hit this path
    # (Homebrew default doesn't ship a pre-linked node), so we gate on
    # CI/GITHUB_ACTIONS and don't touch user installs.
    if [ "${CI:-}" = "true" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
        brew unlink node &>/dev/null || true
        for kg in node@20 node@21 node@23 node@24; do
            brew unlink "$kg" &>/dev/null || true
        done
    fi
    if HOMEBREW_NO_ENV_HINTS=1 run_step "Node.js" brew install node@22; then
        brew link --force --overwrite node@22 &>/dev/null || true
        hash -r 2>/dev/null || true
        echo "  Done. Version: $(node --version 2>/dev/null || echo 'installed - restart terminal')"
    fi
else
    echo "[3/9] Node.js already installed: $(node --version). Skipping."
fi

# Codex npm fallback: if the native installer at step 1 couldn't run (CI/
# datacenter 403 on chatgpt.com, or no network yet), install it now that Node
# and npm exist - the same path setup-windows.ps1 uses for Codex.
if agent_installed codex && [ "${_codex_needs_npm:-0}" = "1" ] && ! command -v codex &> /dev/null; then
    if command -v npm &> /dev/null; then
        echo "[3/9] Installing Codex via npm (native installer was unreachable)..."
        if run_step "Codex (npm)" npm install -g @openai/codex; then
            hash -r 2>/dev/null || true
            echo "  Done. Version: $(codex --version 2>/dev/null || echo 'installed - restart terminal')"
        fi
    else
        echo "[3/9] Codex still not installed and npm is unavailable - install it"
        echo "      manually after setup:  npm install -g @openai/codex"
        FAILED_STEPS+=("Codex (no native installer, no npm)")
    fi
fi

# --- [4/9] Git + user config ---
if ! command -v git &> /dev/null; then
    echo "[4/9] Installing Git..."
    run_step "Git" brew install git && echo "  Done. Version: $(git --version)"
else
    echo "[4/9] Git already installed: $(git --version). Skipping."
    # Apple's Xcode CLT ships /usr/bin/git, which is typically a few minor
    # versions behind brew. Works fine for clone/commit/push - tell users how
    # to upgrade if they want the latest.
    if [[ "$(command -v git)" == "/usr/bin/git" ]]; then
        echo "  Note: using Apple's Xcode CLT git at /usr/bin/git (older)."
        echo "  To get the latest git:  brew install git"
        echo "  Then ensure brew's PATH comes before /usr/bin in ~/.zprofile."
    fi
fi

if command -v git &> /dev/null; then
    GIT_NAME="$(git config --global user.name 2>/dev/null || true)"
    GIT_EMAIL="$(git config --global user.email 2>/dev/null || true)"
    if [ -z "$GIT_NAME" ]; then
        read -r -p "  Enter your full name for git commits: " input_name || input_name=""
        if [ -n "$input_name" ]; then
            if ! git config --global user.name "$input_name" 2>/dev/null; then
                echo "  [!] 'git config --global user.name' failed - run it manually:" >&2
                echo "      git config --global user.name \"$input_name\"" >&2
                FAILED_STEPS+=("Git config (user.name)")
            fi
        fi
    fi
    if [ -z "$GIT_EMAIL" ]; then
        read -r -p "  Enter your email for git commits: " input_email || input_email=""
        if [ -n "$input_email" ]; then
            if ! git config --global user.email "$input_email" 2>/dev/null; then
                echo "  [!] 'git config --global user.email' failed - run it manually:" >&2
                echo "      git config --global user.email \"$input_email\"" >&2
                FAILED_STEPS+=("Git config (user.email)")
            fi
        fi
    fi
    echo "  git user: $(git config --global user.name 2>/dev/null || echo 'not set') <$(git config --global user.email 2>/dev/null || echo 'not set')>"

    if [ -z "$(git config --global init.defaultBranch 2>/dev/null || true)" ]; then
        git config --global init.defaultBranch main && echo "  git init.defaultBranch: main"
    fi
else
    echo "  [!] git not available - skipping git config." >&2
    echo "      See the Git remediation in the recap at the end of this run." >&2
fi

# --- [5/9] Python 3.12 (pinned for Mac/Windows parity) ---
# Pinned to match the Windows script's `Python.Python.3.12` winget package so
# workshop attendees on different OSes end up on the same minor. python@3.12 is
# keg-only on Homebrew, but `brew link --force --overwrite` creates the
# /opt/homebrew/bin/python3 symlink the rest of this script's `command -v`
# checks rely on. A version-floor probe (not just `command -v`) catches stale
# python3 binaries on PATH (old python.org installer, leftover 3.8, etc.).
python_version_ok=false
if command -v python3 &> /dev/null && [[ "$(command -v python3)" != "/usr/bin/python3" ]]; then
    if python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 12) else 1)' 2>/dev/null; then
        python_version_ok=true
    fi
fi
if ! $python_version_ok; then
    echo "[5/9] Installing Python 3.12..."
    if run_step "Python 3.12" brew install python@3.12; then
        brew link --force --overwrite python@3.12 &>/dev/null || true
        hash -r 2>/dev/null || true
        echo "  Done. Version: $(python3 --version 2>/dev/null || echo 'installed - restart terminal')"
    fi
else
    echo "[5/9] Python already installed: $(python3 --version). Skipping."
fi

# --- [6/9] VS Code ---
if [ "${ELNORA_SKIP_OPTIONAL_INSTALLS:-}" = "1" ]; then
    # CI/test escape hatch -- mirrors setup-windows.ps1. Used by
    # handoff-e2e.yml and bootstrap-e2e.yml so the test runner doesn't burn
    # ~14s/run installing optional editors that the test never exercises.
    echo "[6/9] VS Code: ELNORA_SKIP_OPTIONAL_INSTALLS=1 - skipping for non-interactive run."
elif ! command -v code &> /dev/null && [ ! -d "/Applications/Visual Studio Code.app" ]; then
    echo "[6/9] Installing VS Code..."
    run_step "VS Code" brew install --cask visual-studio-code && echo "  Done."
else
    echo "[6/9] VS Code already installed. Skipping."
fi

# Install the `code` CLI shim so `code .` works from terminal. The cask does not
# do this automatically - normally users have to run "Shell Command: Install
# 'code' command in PATH" from VS Code's command palette. We symlink directly.
VSCODE_SHIM="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
if [ -x "$VSCODE_SHIM" ] && ! command -v code &> /dev/null; then
    if command -v brew &> /dev/null && BREW_BIN="$(brew --prefix 2>/dev/null)/bin" && [ -d "$BREW_BIN" ] && [ -w "$BREW_BIN" ]; then
        if ln_err="$(ln -sf "$VSCODE_SHIM" "$BREW_BIN/code" 2>&1)"; then
            echo "  Linked 'code' CLI: $BREW_BIN/code -> $VSCODE_SHIM"
        else
            echo "  [!] Could not symlink 'code' into $BREW_BIN." >&2
            echo "      ln said: $ln_err" >&2
            echo "      Workaround: open VS Code, press Cmd+Shift+P, and run" >&2
            echo "        \"Shell Command: Install 'code' command in PATH\"" >&2
        fi
    else
        echo "  [!] brew bin directory not writable - skipping automatic 'code' CLI shim." >&2
        echo "      Workaround: open VS Code, press Cmd+Shift+P, and run" >&2
        echo "        \"Shell Command: Install 'code' command in PATH\"" >&2
    fi
fi

# --- [7/9] GitHub CLI ---
if ! command -v gh &> /dev/null; then
    echo "[7/9] Installing GitHub CLI..."
    run_step "GitHub CLI" brew install gh && echo "  Done. Version: $(gh --version 2>/dev/null | head -1)"
else
    echo "[7/9] GitHub CLI already installed: $(gh --version | head -1). Skipping."
fi

# --- [8/9] Obsidian (optional - knowledge base) ---
if [ "${ELNORA_SKIP_OPTIONAL_INSTALLS:-}" = "1" ]; then
    echo "[8/9] Obsidian: ELNORA_SKIP_OPTIONAL_INSTALLS=1 - skipping for non-interactive run."
elif [ ! -d "/Applications/Obsidian.app" ]; then
    echo "[8/9] Installing Obsidian (optional)..."
    run_step "Obsidian" brew install --cask obsidian && echo "  Done."
else
    echo "[8/9] Obsidian already installed. Skipping."
fi

# --- [9/9] Projects folder ---
PROJECTS_DIR="$HOME/Documents/Projects"
if [ ! -d "$PROJECTS_DIR" ]; then
    echo "[9/9] Creating Projects folder at $PROJECTS_DIR..."
    if mkdir_err="$(mkdir -p "$PROJECTS_DIR" 2>&1)"; then
        echo "  Done."
    else
        echo "" >&2
        echo "  +- FAILURE: Projects folder" >&2
        echo "  | Could not create $PROJECTS_DIR" >&2
        echo "  | mkdir said: ${mkdir_err:-(no output)}" >&2
        echo "  |" >&2
        echo "  | What to do:" >&2
        remediation_hint "Projects folder" | sed 's/^/  |   /' >&2
        echo "  +----------------------------------------------------------" >&2
        echo "" >&2
        FAILED_STEPS+=("Projects folder")
    fi
else
    echo "[9/9] Projects folder already exists. Skipping."
fi

echo ""
echo "==========================================="
echo "  Install summary"
echo "==========================================="
echo ""
# Refresh shell command lookup cache so newly-installed binaries are visible.
hash -r 2>/dev/null || true

# Color codes for the install summary. Use $'...' so the escape sequences are
# resolved at assignment time and printf prints the actual bytes. If stdout
# isn't a TTY (e.g. piped to a file), strip the colors so the log stays clean.
if [ -t 1 ]; then
    GREEN=$'\033[1;32m'
    RED=$'\033[1;31m'
    NC=$'\033[0m'
else
    GREEN=""
    RED=""
    NC=""
fi
CHECK="+"
CROSS="X"
DASH="-"
if [ -t 1 ]; then
    GRAY=$'\033[1;30m'
else
    GRAY=""
fi

# Sentinel for "this optional component was deliberately skipped via
# ELNORA_SKIP_OPTIONAL_INSTALLS=1 and isn't already on disk." Mirrors the
# __SKIPPED_OPTIONAL constant in setup-windows.ps1 so the install summary
# can render a neutral "skipped (optional, env flag)" row instead of a
# red NOT INSTALLED row that looks like a real failure to the user.
SKIPPED_OPTIONAL="__SKIPPED_OPTIONAL"

# print_status "<label>" "<version-or-empty>"
# Empty / "not found" version    => red X NOT INSTALLED
# Sentinel __SKIPPED_OPTIONAL    => gray - skipped (optional, env flag)
# Anything else                  => green + <version>
print_status() {
    local label="$1"
    local version="$2"
    if [ "$version" = "$SKIPPED_OPTIONAL" ]; then
        printf "  %s%s%s %-12s %sskipped (optional, env flag)%s\n" "$GRAY" "$DASH" "$NC" "$label:" "$GRAY" "$NC"
    elif [ -z "$version" ] || [ "$version" = "not found" ]; then
        printf "  %s%s%s %-12s %sNOT INSTALLED%s\n" "$RED" "$CROSS" "$NC" "$label:" "$RED" "$NC"
    else
        printf "  %s%s%s %-12s %s%s%s\n" "$GREEN" "$CHECK" "$NC" "$label:" "$GREEN" "$version" "$NC"
    fi
}

# VS Code: `code` may not be on PATH until the user runs
# "Shell Command: Install 'code' command in PATH" from VS Code's palette.
# Check for the .app bundle as a fallback so the summary isn't misleading.
# When ELNORA_SKIP_OPTIONAL_INSTALLS=1 (CI smoke test) caused us to skip the
# install AND the editor isn't already on disk, return the sentinel so the
# summary renders a neutral "skipped (optional, env flag)" row instead of a
# red NOT INSTALLED row.
vscode_version() {
    if command -v code &> /dev/null; then
        code --version 2>/dev/null | head -1
    elif [ -d "/Applications/Visual Studio Code.app" ]; then
        local plist="/Applications/Visual Studio Code.app/Contents/Info.plist"
        if [ -f "$plist" ]; then
            /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$plist" 2>/dev/null \
                | awk '{print "installed (" $0 ") - run \"Shell Command: Install code command in PATH\" from VS Code"}'
        else
            echo "installed - run \"Shell Command: Install code command in PATH\" from VS Code"
        fi
    elif [ "${ELNORA_SKIP_OPTIONAL_INSTALLS:-}" = "1" ]; then
        echo "$SKIPPED_OPTIONAL"
    else
        echo ""
    fi
}

obsidian_version() {
    if [ -d "/Applications/Obsidian.app" ]; then
        local plist="/Applications/Obsidian.app/Contents/Info.plist"
        if [ -f "$plist" ]; then
            /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$plist" 2>/dev/null \
                | awk '{print "installed (" $0 ")"}'
        else
            echo "installed"
        fi
    elif [ "${ELNORA_SKIP_OPTIONAL_INSTALLS:-}" = "1" ]; then
        echo "$SKIPPED_OPTIONAL"
    else
        echo ""
    fi
}

# Compute every tool's version up-front so the summary table AND the headline
# count use the same data. Storing in parallel arrays preserves output order
# and avoids re-running each version probe twice (once for the row, once for
# the counter).
# The coding-agent row(s) depend on what the user chose to install: Claude Code,
# Codex, or both. Build the arrays in two halves so a Codex-only run never shows
# a phantom "Claude Code NOT INSTALLED" line (and vice versa).
SUMMARY_LABELS=("Node.js" "Git" "Python" "VS Code")
SUMMARY_VALUES=(
    "$(node --version 2>/dev/null || true)"
    "$(git --version 2>/dev/null || true)"
    "$(python3 --version 2>/dev/null || true)"
    "$(vscode_version)"
)
if agent_installed claude; then
    SUMMARY_LABELS+=("Claude Code")
    SUMMARY_VALUES+=("$(claude --version 2>/dev/null || true)")
fi
if agent_installed codex; then
    SUMMARY_LABELS+=("Codex")
    SUMMARY_VALUES+=("$(codex --version 2>/dev/null || true)")
fi
SUMMARY_LABELS+=("GitHub CLI" "Obsidian")
SUMMARY_VALUES+=(
    "$(gh --version 2>/dev/null | head -1 || true)"
    "$(obsidian_version)"
)

for i in "${!SUMMARY_LABELS[@]}"; do
    print_status "${SUMMARY_LABELS[$i]}" "${SUMMARY_VALUES[$i]}"
done
echo ""

# A "skipped optional" entry is neither installed nor missing - it's a
# deliberate non-event in CI. Exclude it from both counters so the headline
# tells the truth ("All N installed" remains accurate when CI skipped the
# optional editor / vault).
MISSING_COUNT=0
SKIPPED_OPTIONAL_COUNT=0
for v in "${SUMMARY_VALUES[@]}"; do
    if [ "$v" = "$SKIPPED_OPTIONAL" ]; then
        SKIPPED_OPTIONAL_COUNT=$((SKIPPED_OPTIONAL_COUNT + 1))
    elif [ -z "$v" ]; then
        MISSING_COUNT=$((MISSING_COUNT + 1))
    fi
done
REQUIRED_TOTAL=$(( ${#SUMMARY_VALUES[@]} - SKIPPED_OPTIONAL_COUNT ))
if [ "$MISSING_COUNT" -eq 0 ]; then
    if [ "$SKIPPED_OPTIONAL_COUNT" -gt 0 ]; then
        printf "  %sAll %d required components installed (%d optional skipped).%s\n" "$GREEN" "$REQUIRED_TOTAL" "$SKIPPED_OPTIONAL_COUNT" "$NC"
    else
        printf "  %sAll %d components installed.%s\n" "$GREEN" "$REQUIRED_TOTAL" "$NC"
    fi
else
    printf "  %s%d component(s) NOT installed - see red X rows above and remediation below.%s\n" "$RED" "$MISSING_COUNT" "$NC"
fi
echo ""

if [ ${#FAILED_STEPS[@]} -gt 0 ]; then
    echo "==========================================="
    echo "  ${#FAILED_STEPS[@]} step(s) failed - remediation below"
    echo "==========================================="
    for step_entry in "${FAILED_STEPS[@]}"; do
        # Strip trailing "(exit N)" or "(...)" to recover the bare label for lookup.
        step_label="${step_entry% (*}"
        echo ""
        echo "-- $step_entry --"
        remediation_hint "$step_label"
    done
    echo ""
    echo "Once you've fixed the issue(s), re-run:  ./setup-mac.sh"
    echo "The script is idempotent - already-installed steps are skipped."
    echo "==========================================="
    echo ""
fi

# VS Code reminder banner. Bright yellow box with blank lines above and
# below so the "quit fully" rule reads as a separate section, not as
# another summary row. Real workshop attendees have walked past this in
# plain-text form and wondered why their newly-installed `claude`
# command wasn't visible in the VS Code integrated terminal - the answer
# is always that VS Code cached its PATH at launch time. Color is gated on
# `-t 1` (TTY) so log files stay clean.
if [ -t 1 ]; then
    YELLOW=$'\033[1;33m'
    Y_NC=$'\033[0m'
else
    YELLOW=""
    Y_NC=""
fi
echo ""
printf "%s  +============================================================+%s\n" "$YELLOW" "$Y_NC"
printf "%s  |                                                            |%s\n" "$YELLOW" "$Y_NC"
printf "%s  |   IMPORTANT - to see the new PATH in VS Code:              |%s\n" "$YELLOW" "$Y_NC"
printf "%s  |                                                            |%s\n" "$YELLOW" "$Y_NC"
printf "%s  |   Quit VS Code FULLY (Cmd+Q - not just closing the         |%s\n" "$YELLOW" "$Y_NC"
printf "%s  |   terminal) and reopen it. VS Code caches its PATH at      |%s\n" "$YELLOW" "$Y_NC"
printf "%s  |   app launch time.                                         |%s\n" "$YELLOW" "$Y_NC"
printf "%s  |                                                            |%s\n" "$YELLOW" "$Y_NC"
printf "%s  |   If you ran this in Terminal.app, just open a new window. |%s\n" "$YELLOW" "$Y_NC"
printf "%s  |                                                            |%s\n" "$YELLOW" "$Y_NC"
printf "%s  +============================================================+%s\n" "$YELLOW" "$Y_NC"
echo ""
echo ""

echo "==========================================="
echo "  Authenticating services"
echo "==========================================="
echo ""

# Bypass entire auth section in CI / non-interactive modes.
if [ "${ELNORA_SKIP_HANDOFF:-}" = "1" ] || [ "${ELNORA_HANDOFF_MODE:-}" = "headless" ]; then
    echo "  (Skipped - non-interactive run.)"
    echo ""
else
    # ---- Handoff-agent auth ----
    # Only the agent that finishes Phase 2 ($ELNORA_HANDOFF_AGENT) must be
    # signed in here. If both were installed, the other one signs in on its
    # own first launch.
    if [ "$ELNORA_HANDOFF_AGENT" = "codex" ]; then
    echo "[1/2] Codex"
    if [ -n "${OPENAI_API_KEY:-}${CODEX_API_KEY:-}" ] && [ ! -f "${CODEX_HOME:-$HOME/.codex}/auth.json" ]; then
        # Codex does not pick these env vars up implicitly (CODEX_API_KEY is
        # honored by `codex exec` only) — persist a real login so the
        # interactive session that follows actually authenticates.
        if printf '%s' "${OPENAI_API_KEY:-$CODEX_API_KEY}" | codex login --with-api-key >/dev/null 2>&1; then
            echo "      OPENAI_API_KEY/CODEX_API_KEY set - logged in with API key."
            mark_done "auth-codex"
        else
            echo "      [WARN] API-key login failed - Codex will prompt on first launch."
        fi
    elif [ -f "${CODEX_HOME:-$HOME/.codex}/auth.json" ]; then
        echo "      [OK] Already signed in."
        mark_done "auth-codex"
    else
        echo "      Not signed in. A browser will open so you can sign in to ChatGPT."
        echo "      [Y]es / [s]kip+continue without Codex / [q]uit script"
        printf "      > "
        read -r answer
        case "${answer:-Y}" in
            [Yy]*|"")
                if codex login; then
                    echo "      [OK] Signed in."
                    mark_done "auth-codex"
                else
                    echo "      [FAIL] Codex sign-in didn't complete."
                    echo ""
                    echo "         Nothing is lost. When you're ready, run again:"
                    echo ""
                    echo "             bash setup-mac.sh"
                    echo ""
                    echo "         It resumes right here at the sign-in step - every"
                    echo "         tool above is already installed and skipped instantly."
                    echo "         To try the login by hand first:  codex login"
                    exit 1
                fi
                ;;
            [Ss]*)
                echo "      [SKIP] Phase 2 needs a signed-in agent to finish setup."
                echo "             Re-run when ready:  bash setup-mac.sh"
                exit 0
                ;;
            [Qq]*)
                echo "      Quit. Re-run anytime:  bash setup-mac.sh"
                exit 0
                ;;
            *)
                echo "      Unrecognized response, treating as skip."
                exit 0
                ;;
        esac
    fi
    else
    # ---- Claude auth ----
    echo "[1/2] Claude Code"
    if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
        echo "      ANTHROPIC_API_KEY set - using API key, skipping OAuth."
    elif claude auth status --json 2>/dev/null | grep -q '"loggedIn"[[:space:]]*:[[:space:]]*true'; then
        email=$(claude auth status --json 2>/dev/null | grep -o '"email"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')
        echo "      [OK] Already logged in as ${email:-unknown}"
        mark_done "auth-claude"
    else
        echo "      Not logged in. A browser will open so you can sign in."
        echo "      [Y]es / [s]kip+continue without Claude / [q]uit script"
        printf "      > "
        read -r answer
        case "${answer:-Y}" in
            [Yy]*|"")
                if claude auth login --claudeai; then
                    if claude auth status --json 2>/dev/null | grep -q '"loggedIn"[[:space:]]*:[[:space:]]*true'; then
                        echo "      [OK] Logged in."
                        mark_done "auth-claude"
                    else
                        echo "      [FAIL] Login flow returned but you are still not signed in."
                        echo ""
                        echo "         This is the most common place setup stops. Nothing is lost."
                        echo "         When you're ready, run the SAME command again:"
                        echo ""
                        echo "             bash setup-mac.sh"
                        echo ""
                        echo "         It resumes right here at the Claude sign-in step - every"
                        echo "         tool above is already installed and is skipped instantly."
                        echo "         To try the login by hand first:  claude auth login --claudeai"
                        exit 1
                    fi
                else
                    echo "      [FAIL] Claude sign-in didn't complete."
                    echo ""
                    echo "         This is the most common place setup stops. Nothing is lost."
                    echo "         When you're ready, run the SAME command again:"
                    echo ""
                    echo "             bash setup-mac.sh"
                    echo ""
                    echo "         It resumes right here at the Claude sign-in step - every"
                    echo "         tool above is already installed and is skipped instantly."
                    exit 1
                fi
                ;;
            [Ss]*)
                # Use the live $PWD for the resume hint -- the user picked
                # their workspace name in install.sh, so the folder is no
                # longer guaranteed to be ~/Documents/elnora-ai-agent-hackathon-starter-kit.
                # setup-mac.sh has not `cd`'d anywhere by this point, so
                # $PWD == kit dir.
                kit_dir_display="$PWD"
                # Collapse $HOME into ~ for readability.
                case "$kit_dir_display" in
                    "$HOME"/*) kit_dir_display="~${kit_dir_display#"$HOME"}" ;;
                esac
                # The ASCII box is 60 chars wide; the cd line carries 8
                # chars of prefix ("  |     cd ") plus a 52-char field plus
                # the trailing "|". %-52s pads short strings but does NOT
                # truncate long ones, so a path > 52 chars would push the
                # right border off the row. Pre-truncate with an ellipsis
                # so the box stays aligned regardless of workspace name.
                if [ "${#kit_dir_display}" -gt 52 ]; then
                    kit_dir_display="${kit_dir_display:0:49}..."
                fi
                echo ""
                echo "  +============================================================+"
                echo "  |                                                            |"
                echo "  |   You skipped Claude Code login.                           |"
                echo "  |                                                            |"
                echo "  |   That's fine - but Phase 2 (where Claude finishes setup)  |"
                echo "  |   needs an authenticated session, so we can't continue     |"
                echo "  |   right now.                                               |"
                echo "  |                                                            |"
                echo "  |   When you're ready:                                       |"
                echo "  |                                                            |"
                printf '  |     cd %-52s|\n' "$kit_dir_display"
                echo "  |     bash setup-mac.sh                                      |"
                echo "  |                                                            |"
                echo "  |   Re-running is safe - installs are skipped if already     |"
                echo "  |   present, and the script picks up at the auth step.       |"
                echo "  |                                                            |"
                echo "  +============================================================+"
                echo ""
                exit 0
                ;;
            [Qq]*)
                echo "      Quit. Re-run anytime:  bash setup-mac.sh"
                exit 0
                ;;
            *)
                echo "      Unrecognized response, treating as skip."
                exit 0
                ;;
        esac
    fi
    fi  # end handoff-agent auth (codex / claude branch)

    # When both agents were installed, the non-handoff one is optional here -
    # it prompts for sign-in on its own first launch. Just remind the user.
    if [ "$ELNORA_AGENT" = "both" ]; then
        if [ "$ELNORA_HANDOFF_AGENT" = "claude" ]; then
            echo "      Note: Codex is installed too - sign in anytime with 'codex login'."
        else
            echo "      Note: Claude Code is installed too - sign in anytime with 'claude auth login --claudeai'."
        fi
    fi
    echo ""

    # ---- GitHub auth ----
    echo "[2/2] GitHub CLI"
    if [ -n "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ]; then
        echo "      GH_TOKEN/GITHUB_TOKEN set - skipping OAuth."
    elif gh auth status >/dev/null 2>&1; then
        gh_user=$(gh api user --jq .login 2>/dev/null || echo "unknown")
        echo "      [OK] Already logged in as $gh_user"
        mark_done "auth-github"
    else
        echo "      Not logged in. Phase 2 needs this to create your starter repo."
        echo "      [Y]es / [s]kip (Phase 2 will prompt you again later)"
        printf "      > "
        read -r answer
        case "${answer:-Y}" in
            [Yy]*|"")
                if gh auth login --web --hostname github.com --git-protocol https; then
                    echo "      [OK] Logged in."
                    mark_done "auth-github"
                else
                    echo "      [WARN] Login didn't complete. Phase 2 will prompt you."
                fi
                ;;
            *)
                echo "      [SKIP] To do later:  gh auth login --web"
                ;;
        esac
    fi
    echo ""
fi

echo "==========================================="
echo "  Quick PATH note"
echo "==========================================="
echo ""
echo "  The 'claude' command is at ~/.local/bin/."
echo "  - In any terminal opened AFTER this install: works automatically."
echo "  - In a terminal opened BEFORE this install (rare):"
echo "      export PATH=\"\$HOME/.local/bin:\$PATH\""
echo "    or just open a fresh terminal window."
echo ""

echo "==========================================="
echo "  Phase 1 complete - handing off to Claude"
echo "==========================================="
echo ""

# CI integration: propagate the script's accumulated PATH to $GITHUB_PATH so
# subsequent workflow steps (handoff-e2e assertions, install-smoke-test
# verifications, bootstrap-e2e checks) see every binary Phase 1 installed.
# Without this, a fresh shell in the next step inherits the runner's job-
# start PATH snapshot, which doesn't include ~/.local/bin (Claude Code),
# brew prefix, or anything brew added after job start. No-op outside GH
# Actions (variable unset).
if [ -n "${GITHUB_PATH:-}" ]; then
    IFS=':' read -r -a _path_dirs <<< "$PATH"
    for _dir in "${_path_dirs[@]}"; do
        [ -n "$_dir" ] && echo "$_dir" >> "$GITHUB_PATH"
    done
    unset _path_dirs _dir
    echo "  (CI: propagated PATH to \$GITHUB_PATH for downstream steps)"
fi

# The exact prompt handed to the agent. Defined once so the headless test mode
# below uses byte-for-byte the same string as the production handoff -
# divergence here is the bug headless mode is supposed to catch. Both agents
# read INSTALL_FOR_AGENTS.md (it carries an "Agent tooling adapter" section so
# Codex maps Claude tool names to its own equivalents).
HANDOFF_PROMPT="Phase 1 of the Elnora AI Agent Hackathon Starter Kit install just completed. Please read INSTALL_FOR_AGENTS.md in this directory and finish Phase 2 setup. The Phase 1 install log is at ~/claude-starter-install.log."

# Resolve the handoff agent's binary, display name, and first-run auth note.
case "$ELNORA_HANDOFF_AGENT" in
    codex)
        AGENT_BIN="codex"; AGENT_NAME="Codex"
        AUTH_NOTE="On first run, a browser may open so you can sign in to your ChatGPT (OpenAI) account."
        ;;
    *)
        AGENT_BIN="claude"; AGENT_NAME="Claude Code"
        AUTH_NOTE="On first run, your browser will open to log into your Claude Pro/Max account."
        ;;
esac

if command -v "$AGENT_BIN" >/dev/null 2>&1; then
    if [ "${ELNORA_SKIP_HANDOFF:-}" = "1" ]; then
        # CI/test escape hatch: print what would happen and exit cleanly. Used
        # by .github/workflows/install-smoke-test.yml so the smoke test doesn't
        # hang on the agent trying to open a browser for first-run auth.
        # Echo the prompt itself so the smoke test has something to grep on.
        echo "ELNORA_SKIP_HANDOFF=1 set - would hand off to $AGENT_NAME with the Phase 2 prompt. Skipping for non-interactive run."
        echo "  Phase 2 prompt: $HANDOFF_PROMPT"
        exit 0
    fi

    # Verify INSTALL_FOR_AGENTS.md hasn't been tampered with since install.sh
    # extracted the tarball. install.sh records the sha256 in
    # .elnora-ai-agent-hackathon-starter-kit-marker on fresh extract. If the file changed
    # post-extract, abort - the agent shouldn't be handed off to a doc we
    # didn't ship, especially when headless mode runs with bypassPermissions.
    #
    # Cases:
    #   1. Marker + matching hash -> proceed silently (the happy path).
    #   2. Marker + mismatched hash -> exit 3, point user at the recovery.
    #   3. No marker (pre-existing install from before integrity markers
    #      shipped, or marker manually deleted) -> soft warn for the
    #      interactive handoff; refuse for headless mode where claude
    #      would run with bypassPermissions (see headless branch below).

    # Resolve SCRIPT_DIR with a fallback. ${BASH_SOURCE[0]} is the right
    # answer when this file was sourced or executed by name. It's empty
    # when the script is read on stdin (`bash < setup-mac.sh`) and equals
    # `/dev/stdin` or `-` for some piped invocations. Fall back to $0,
    # then to $PWD, so the marker check still finds the right directory
    # for power users who run `bash ~/Documents/elnora-ai-agent-hackathon-starter-kit/setup-mac.sh`
    # from outside the kit dir.
    script_path="${BASH_SOURCE[0]:-$0}"
    if [ -z "$script_path" ] || [ "$script_path" = "/dev/stdin" ] || [ "$script_path" = "-" ]; then
        SCRIPT_DIR="$PWD"
    else
        SCRIPT_DIR="$(cd "$(dirname "$script_path")" 2>/dev/null && pwd)"
        [ -z "$SCRIPT_DIR" ] && SCRIPT_DIR="$PWD"
    fi

    # ---- VS Code workspace + window restore -------------------------------
    # Two fixes for "I closed VS Code and it forgot which folder this was":
    #   1. Open a NAMED <workspace>.code-workspace instead of a bare folder.
    #      A named workspace shows up as one clear entry in File > Open Recent
    #      and pins cleanly to the Dock, so the user can always get back here
    #      -- a bare folder is far easier to lose track of.
    #   2. Set window.restoreWindows:"all" in the user's GLOBAL VS Code (and
    #      Cursor) settings so relaunching the app reopens this workspace
    #      automatically. That's a user-level window setting, so it cannot live
    #      in the workspace file -- it has to go in User settings.json.
    # Both are best-effort: any failure here must never break the handoff.
    WORKSPACE_FILE="$SCRIPT_DIR/$(basename "$SCRIPT_DIR").code-workspace"
    ensure_vscode_workspace() {
        # 1. Named workspace file (idempotent: only write if missing, so we
        #    never stomp a workspace the user has since customized).
        if [ ! -f "$WORKSPACE_FILE" ]; then
            cat > "$WORKSPACE_FILE" <<'JSON'
{
  "folders": [
    { "path": "." }
  ],
  "settings": {}
}
JSON
        fi

        # 2. Merge restoreWindows into global settings, if python3 is around.
        #    (No hard dependency: if python3 is absent the workspace file +
        #    Open Recent still get the user back; they just don't get auto
        #    window restore.)
        command -v python3 >/dev/null 2>&1 || return 0
        local app_support="$HOME/Library/Application Support" d settings
        for d in "Code" "Code - Insiders" "Cursor"; do
            settings="$app_support/$d/User/settings.json"
            # Only touch apps the user has actually launched (User dir exists);
            # don't fabricate settings for an editor that isn't installed.
            [ -d "$app_support/$d/User" ] || continue
            python3 - "$settings" <<'PY' || true
import json, os, sys
f = sys.argv[1]
try:
    if os.path.exists(f):
        with open(f) as fh:
            txt = fh.read().strip()
        # VS Code settings are JSONC. If comments/trailing commas make this
        # unparseable, leave the file ALONE rather than risk clobbering the
        # user's real settings -- the workspace file already covers the
        # common case.
        data = json.loads(txt) if txt else {}
    else:
        data = {}
    if not isinstance(data, dict):
        sys.exit(0)
    if data.get("window.restoreWindows") == "all":
        sys.exit(0)
    data["window.restoreWindows"] = "all"
    os.makedirs(os.path.dirname(f), exist_ok=True)
    with open(f, "w") as fh:
        json.dump(data, fh, indent=2)
except Exception:
    # Never let a settings-merge hiccup abort setup.
    pass
PY
        done
    }

    MARKER_FILE="$SCRIPT_DIR/.elnora-ai-agent-hackathon-starter-kit-marker"
    DOC_FILE="$SCRIPT_DIR/INSTALL_FOR_AGENTS.md"
    marker_missing=0
    if [ -f "$DOC_FILE" ]; then
        if [ -f "$MARKER_FILE" ]; then
            expected_sha=$(awk -F': ' '/^install_for_agents_sha256:/ {print $2}' "$MARKER_FILE" | tr -d '[:space:]')
            actual_sha=$(shasum -a 256 "$DOC_FILE" | awk '{print $1}')
            if [ -n "$expected_sha" ] && [ "$expected_sha" != "$actual_sha" ]; then
                echo "[!] INSTALL_FOR_AGENTS.md has been modified since this starter kit was installed." >&2
                echo "    Expected sha256: $expected_sha" >&2
                echo "    Actual sha256:   $actual_sha" >&2
                echo "" >&2
                echo "    Refusing to hand off to claude. If you intentionally edited the doc," >&2
                echo "    delete $MARKER_FILE and re-run, or re-run the bootstrap one-liner for" >&2
                echo "    a clean copy:" >&2
                echo "      curl -fsSL https://raw.githubusercontent.com/Elnora-AI/elnora-ai-agent-hackathon-starter-kit/main/install.sh | bash" >&2
                exit 3
            fi
        else
            marker_missing=1
            echo "  (no integrity marker found at $MARKER_FILE - this is a pre-existing install."
            echo "   Continuing without doc-tamper verification for the interactive handoff.)"
        fi
    fi

    if [ "${ELNORA_HANDOFF_MODE:-}" = "headless" ]; then
        # Headless E2E test mode. Used by .github/workflows/handoff-e2e.yml so
        # we can verify what Claude actually does after the handoff, not just
        # that the handoff fired. Same prompt, same cwd as production - only
        # the I/O wrapper changes (one-shot print mode + bypassPermissions
        # because nobody's there to approve tool calls).
        #
        # Requires ANTHROPIC_API_KEY in env so claude skips browser OAuth.

        # Hard requirement for headless mode: the integrity marker MUST be
        # present. The marker is what proves the doc claude is about to
        # follow under bypassPermissions hasn't been swapped out. The
        # interactive handoff can fall back to "warn and proceed" because a
        # human is on the other end approving each tool call; headless
        # mode is not allowed that latitude.
        if [ "$marker_missing" = "1" ]; then
            echo "[!] ELNORA_HANDOFF_MODE=headless requires .elnora-ai-agent-hackathon-starter-kit-marker," >&2
            echo "    which is missing at $MARKER_FILE." >&2
            echo "" >&2
            echo "    The marker is the integrity gate that lets us run claude with" >&2
            echo "    --permission-mode bypassPermissions. Without it we cannot prove" >&2
            echo "    INSTALL_FOR_AGENTS.md is the doc we shipped." >&2
            echo "" >&2
            echo "    To recover, re-run the bootstrap one-liner (writes a fresh marker):" >&2
            echo "      curl -fsSL https://raw.githubusercontent.com/Elnora-AI/elnora-ai-agent-hackathon-starter-kit/main/install.sh | bash" >&2
            exit 4
        fi

        # bypassPermissions gate. Three states:
        #   1. Real CI (GITHUB_ACTIONS=true && CI=true) - proceed silently.
        #   2. Local opt-in (ELNORA_HANDOFF_LOCAL_BYPASS=1) - print a 5-second
        #      warning, then proceed. For local handoff testing by a maintainer.
        #   3. Anything else - refuse. Just having ELNORA_HANDOFF_MODE=headless
        #      isn't enough; that env var is too easy to flip from a shell
        #      profile or a stray script. We want bypassPermissions to require
        #      an explicit "yes I know what this is" gesture from a human.
        if [ "${GITHUB_ACTIONS:-}" = "true" ] && [ "${CI:-}" = "true" ]; then
            : # CI mode - proceed silently
        elif [ "${ELNORA_HANDOFF_LOCAL_BYPASS:-}" = "1" ]; then
            echo ""
            echo "  ============================================================"
            echo "  WARNING: about to run claude with --permission-mode bypassPermissions."
            echo "  This grants the agent full filesystem and shell access without prompts."
            echo "  Press Ctrl+C in the next 5 seconds to abort."
            echo "  ============================================================"
            for i in 5 4 3 2 1; do printf "  %s... " "$i"; sleep 1; done
            echo ""
        else
            echo "[!] ELNORA_HANDOFF_MODE=headless is set but no CI markers" >&2
            echo "    (GITHUB_ACTIONS=true && CI=true) and no explicit local opt-in" >&2
            echo "    (ELNORA_HANDOFF_LOCAL_BYPASS=1)." >&2
            echo "" >&2
            echo "    Refusing to run claude with --permission-mode bypassPermissions" >&2
            echo "    outside CI without an explicit acknowledgment. Either run this in" >&2
            echo "    CI, or export ELNORA_HANDOFF_LOCAL_BYPASS=1 to acknowledge that" >&2
            echo "    you are about to grant the agent unprompted shell + file access." >&2
            exit 2
        fi
        TRANSCRIPT="${ELNORA_HANDOFF_TRANSCRIPT:-$HOME/handoff-transcript.jsonl}"
        # The trailing `> /dev/null` on each branch is load-bearing: this entire
        # script is wrapped in `exec > >(tee "$LOG_FILE")` at the top, so anything
        # reaching the script's stdout also lands in ~/claude-starter-install.log.
        # Without /dev/null the agent's own conversation stream (including the
        # literal text "FAILED:" inside INSTALL_FOR_AGENTS.md) bloats the log and
        # poisons the next agent's `grep FAILED:`. Send the transcript to its
        # file only; the workflow has a separate "Show handoff transcript" step.
        if [ "$AGENT_BIN" = "codex" ]; then
            echo "ELNORA_HANDOFF_MODE=headless - running codex exec (transcript: $TRANSCRIPT)"
            # `codex exec` is the non-interactive analog of `claude -p`.
            # --dangerously-bypass-approvals-and-sandbox is Codex's equivalent
            # of --permission-mode bypassPermissions: nobody is there to approve
            # tool calls in headless mode. Gated by the same CI / local-opt-in
            # checks above.
            #
            # Auth: codex exec does NOT read OPENAI_API_KEY implicitly — it
            # only honors CODEX_API_KEY for a single non-interactive run
            # (developers.openai.com/codex/environment-variables). Map the
            # standard var so CI can keep providing OPENAI_API_KEY.
            if [ -z "${CODEX_API_KEY:-}" ] && [ -n "${OPENAI_API_KEY:-}" ]; then
                export CODEX_API_KEY="$OPENAI_API_KEY"
            fi
            codex exec "$HANDOFF_PROMPT" --dangerously-bypass-approvals-and-sandbox 2>&1 \
              | tee "$TRANSCRIPT" > /dev/null
            rc=${PIPESTATUS[0]}
        else
            echo "ELNORA_HANDOFF_MODE=headless - running claude -p (transcript: $TRANSCRIPT)"
            # --verbose is REQUIRED with -p --output-format=stream-json (Claude Code
            # rejects the combo otherwise). --max-turns 80 caps a runaway loop;
            # Phase 2 averages ~40-50 turns when GitHub bootstrap (gh auth + repo
            # create + push + verify) runs in full, so 80 leaves ~30-turn
            # headroom for transient retries (network, tool errors).
            claude -p "$HANDOFF_PROMPT" \
                --permission-mode bypassPermissions \
                --output-format stream-json \
                --verbose \
                --max-turns 80 \
              | tee "$TRANSCRIPT" > /dev/null
            rc=${PIPESTATUS[0]}
        fi
        echo ""
        # An empty/missing transcript means the agent died before emitting a
        # single event (auth failure, crash on startup) - that must read as a
        # FAILED: marker in the install log, not as a quiet success line.
        if [ -s "$TRANSCRIPT" ]; then
            echo "$AGENT_NAME handoff exited with code $rc (transcript saved to $TRANSCRIPT, $(wc -l < "$TRANSCRIPT" | tr -d ' ') events)"
        else
            echo "FAILED: $AGENT_NAME handoff produced no transcript at $TRANSCRIPT (exit $rc) - the agent likely crashed before emitting output; check the lines above for auth or network errors." >&2
            [ "$rc" -eq 0 ] && rc=1
        fi
        exit "$rc"
    fi

    # Interactive handoff. Three branches by environment:
    #
    #   1. Already inside VS Code's integrated terminal ($TERM_PROGRAM=vscode):
    #      the user has the IDE on screen already, so just exec claude in
    #      this shell. No window-launching dance needed.
    #
    #   2. `code` CLI on PATH and the user hasn't opted out: write a one-shot
    #      sentinel containing the handoff prompt, open VS Code at this repo,
    #      and exit. VS Code's runOn:folderOpen task picks up the sentinel and
    #      hands off to claude inside the integrated terminal -- so users get
    #      the file tree, source control panel, and IDE around their session
    #      instead of a bare Terminal.app. ELNORA_SKIP_VSCODE_HANDOFF=1 is
    #      the user-facing escape hatch.
    #
    #   3. Fallback: claude in this shell (today's behavior). Triggered when
    #      VS Code wasn't installed (ELNORA_SKIP_OPTIONAL_INSTALLS=1) or the
    #      `code` shim couldn't be created (brew bin not writable, Cursor
    #      instead of VS Code, etc.).
    if [ "${TERM_PROGRAM:-}" = "vscode" ]; then
        # Already in VS Code, so we don't launch a window -- but still drop the
        # named workspace file and set restoreWindows so the NEXT relaunch
        # reopens this project instead of an empty window.
        ensure_vscode_workspace || true
        echo "Already inside VS Code - starting $AGENT_NAME in this terminal."
        echo "$AUTH_NOTE"
        echo ""
        exec "$AGENT_BIN" "$HANDOFF_PROMPT"
    fi

    # The VS Code sentinel handoff drives `claude` specifically (run-handoff.sh
    # exec's claude), so it only applies when Claude is the handoff agent. Codex
    # falls through to the terminal exec below (still inside VS Code's integrated
    # terminal when launched from there).
    if [ "$AGENT_BIN" = "claude" ] && command -v code >/dev/null 2>&1 && [ "${ELNORA_SKIP_VSCODE_HANDOFF:-}" != "1" ]; then
        VSCODE_DIR="$SCRIPT_DIR/.vscode"
        SENTINEL="$VSCODE_DIR/.handoff-pending"
        if [ -d "$VSCODE_DIR" ] && [ -f "$VSCODE_DIR/run-handoff.sh" ]; then
            # The sentinel's content IS the prompt -- keeps a single source of
            # truth ($HANDOFF_PROMPT in this script). The helper reads, deletes,
            # then exec's claude. Pre-delete on the helper side guarantees the
            # task is one-shot even if claude crashes.
            printf '%s' "$HANDOFF_PROMPT" > "$SENTINEL"
            chmod +x "$VSCODE_DIR/run-handoff.sh" 2>/dev/null || true

            # Create the named workspace file + set restoreWindows BEFORE we
            # open, so we can open the workspace (not the bare folder) and the
            # window sticks across relaunches.
            ensure_vscode_workspace || true

            echo "Opening VS Code - Claude will continue Phase 2 setup there."
            echo ""
            echo "VS Code will show TWO one-time prompts before the handoff fires."
            echo "Click through both:"
            echo "  1. 'Do you trust the authors of the files in this folder?'"
            echo "       -> Click 'Yes, I trust the authors'"
            echo "  2. 'This workspace has tasks ... that can launch processes"
            echo "      automatically. Do you want to allow automatic tasks ...?'"
            echo "       -> Click 'Allow'  (VS Code remembers this globally)"
            echo ""
            echo "Once both are approved, an integrated terminal opens with Claude"
            echo "already on the Phase 2 prompt. On first run, your browser will"
            echo "open to log into your Claude Pro/Max account."
            echo ""
            echo "If you click Disallow on the second prompt, or Claude does not"
            echo "auto-start for any other reason, open a terminal in VS Code"
            echo "(Ctrl+\` or View > Terminal) and run:"
            echo "    bash .vscode/run-handoff.sh"
            echo ""
            echo "You can close this Terminal window once VS Code has loaded."
            echo ""

            # `code` returns immediately after asking the GUI to open the
            # workspace. We open the named .code-workspace (not the bare folder)
            # so it lands in Open Recent as one clear, re-openable entry. If it
            # fails (e.g. shim is stale and points at a removed app bundle),
            # fall through to the in-terminal fallback below.
            if code "$WORKSPACE_FILE" >/dev/null 2>&1; then
                exit 0
            fi
            echo "  [!] 'code' command failed - falling back to terminal handoff." >&2
            rm -f "$SENTINEL"
        fi
    fi

    echo "Starting $AGENT_NAME - it will read INSTALL_FOR_AGENTS.md and finish setup."
    echo "$AUTH_NOTE"
    echo ""
    # exec replaces this shell - the agent takes over with the initial prompt
    # loaded. If exec fails (no TTY, broken install), the lines below print as
    # a fallback.
    exec "$AGENT_BIN" "$HANDOFF_PROMPT"
fi

# Fallback: handoff agent not on PATH (its install failed) - show the manual
# continuation path so the user can recover after fixing the issue.
echo "  !  '$AGENT_BIN' command not found - $AGENT_NAME install may have failed."
echo ""
echo "  See the remediation hints above. Once you've fixed it, re-run:"
echo "      ./setup-mac.sh"
echo ""
echo "  Or continue manually:"
echo "      cd $(pwd)"
echo "      $AGENT_BIN"
echo "      Then say: 'Read INSTALL_FOR_AGENTS.md and finish setup.'"
echo ""

# Exit 0 even if some steps failed - the remediation recap tells the user exactly
# what to do, and a non-zero exit would trip callers (e.g. IDE terminals that
# highlight failures) in ways that can hide the remediation text above.
exit 0

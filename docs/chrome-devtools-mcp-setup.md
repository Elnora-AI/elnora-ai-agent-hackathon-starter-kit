# Chrome DevTools MCP — Setup & Usage

How to set up and use **chrome-devtools-mcp** so Claude Code can take
over your existing Chrome browser (with all your logins, cookies, and
tabs intact) — navigate, screenshot, run JS, read network/console,
and run Lighthouse / performance traces.

This is the Google-maintained MCP server (`chrome-devtools-mcp` on
npm). It is wired into this repo's `.mcp.json` and is available out of
the box after a normal `setup-mac.sh` / `setup-windows.ps1` run.

---

## TL;DR

1. `.mcp.json` registers `chrome-devtools` with `--autoConnect`.
2. Claude Code spawns the server on session start; `npx` downloads
   the package on first run and caches it under `~/.npm/_npx/`.
3. The server connects to a Chrome that's already running.
4. Chrome 144+ exposes the local debugging endpoint by default — no
   flags needed.
5. From Claude, calling `mcp__chrome-devtools__list_pages` returns
   your real tabs. You're in.

No browser is launched by Claude. No login is required. The MCP
attaches to your existing Chrome process.

---

## Prerequisites

| Requirement | Why | How to check |
|-------------|-----|--------------|
| **Node.js 22 LTS** (installed by Phase 1) | `npx` runs the MCP package | `node -v` |
| **Google Chrome 144+** | `--autoConnect` requires the new local debugging endpoint | `chrome://settings/help` |
| **Chrome must be running** when Claude Code starts | `--autoConnect` attaches; it does not launch | n/a |
| `chrome-devtools-mcp` reachable on npm | Pulled at runtime | `npm view chrome-devtools-mcp version` |

Node.js is installed by Phase 1 (`setup-mac.sh` / `setup-windows.ps1`).
Chrome is **not** installed by Phase 1 — install it manually if you
don't have it. macOS: `brew install --cask google-chrome`. Windows:
[google.com/chrome](https://www.google.com/chrome/).

---

## How it's configured here

### 1. `.mcp.json` (committed, repo root)

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "type": "stdio",
      "command": "npx",
      "args": ["chrome-devtools-mcp@latest", "--autoConnect"]
    }
  }
}
```

`@latest` means every Claude Code session picks up the newest version.
Pin a version if you want stability.

### 2. Windows user-level override (not committed)

The `.mcp.json` above uses bare `npx`, which doesn't resolve cleanly on
Windows when invoked by a stdio MCP host. `setup-windows.ps1` writes
this to `~/.claude/.mcp.json` so Windows users get a working setup
without touching the committed config:

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "type": "stdio",
      "command": "cmd",
      "args": ["/c", "npx", "chrome-devtools-mcp@latest", "--autoConnect"]
    }
  }
}
```

User-level config overrides project-level **for that user only** —
macOS / Linux users are unaffected.

### 3. Permissions

`.claude/settings.json` allows `mcp__chrome-devtools__*` so the tools
don't prompt on every call.

---

## Step-by-step: from a fresh machine

### macOS

```bash
# Phase 1 install (Node, git, Claude, etc.)
./setup-mac.sh

# Install Chrome if you don't have it
brew install --cask google-chrome

# Open Chrome normally, sign in, leave it running
open -a "Google Chrome"

# Start Claude in this repo
claude .

# Inside Claude — verify
#   "list my chrome tabs"
# Or call mcp__chrome-devtools__list_pages directly.
```

### Windows (PowerShell)

```powershell
# Phase 1 install
.\setup-windows.ps1
# (this also writes ~/.claude/.mcp.json with the cmd /c override)

# Install Chrome from https://www.google.com/chrome/ if missing

# Open Chrome normally, sign in, leave it running

# Start Claude in this repo
claude .
```

### When `--autoConnect` doesn't find Chrome

Chrome 144+ exposes the local debugging endpoint by default. **You
should not need to do anything in Chrome.** If the MCP can't find it:

1. Quit Chrome completely (Cmd+Q on macOS, close all windows on
   Windows).
2. Reopen with no special flags.
3. Try the tool call again.

If you've previously launched Chrome with `--remote-debugging-port=N`
for another tool, that disables the default endpoint until Chrome is
fully restarted.

To force-enable a known port (e.g. to share with another tool):

```bash
# macOS — close all Chrome windows first
open -a "Google Chrome" --args --remote-debugging-port=9222
```

…and switch the MCP config to:

```json
{
  "command": "npx",
  "args": ["chrome-devtools-mcp@latest", "--browserUrl", "http://127.0.0.1:9222"]
}
```

For the default starter-kit setup, **`--autoConnect` is what we use
and it just works on Chrome 144+**.

---

## How to use it

### Tool categories

| Category | Tools | When to use |
|----------|-------|-------------|
| **Pages** | `list_pages`, `select_page`, `new_page`, `navigate_page` | Switch tabs, open URLs |
| **Snapshot** | `take_snapshot` (a11y tree) | **Preferred** — text-based, fast, gives you `uid`s to click |
| **Screenshot** | `take_screenshot` | When you actually need pixels (visual review, design diff) |
| **JS** | `evaluate_script` | Read DOM, call APIs, get cookies, anything |
| **Input** | `click`, `drag`, `fill`, `fill_form`, `hover`, `press_key`, `type_text`, `upload_file` | Drive the page |
| **Network** | `list_network_requests`, `get_network_request` | API debugging, request inspection |
| **Console** | `list_console_messages`, `get_console_message` | JS error hunting |
| **Performance** | `performance_start_trace`, `performance_stop_trace`, `performance_analyze_insight` | Lighthouse-style perf profiling |
| **Audit** | `lighthouse_audit` | Full Lighthouse run |
| **Device emulation** | `emulate`, `resize_page` | Mobile / network throttling |
| **Memory** | `take_memory_snapshot` | Leak hunting |
| **Dialogs** | `handle_dialog` | Confirm/dismiss alerts |
| **Wait** | `wait_for` | Pause until selector / text appears |

### Recipes

**Take over the browser and read the current tab:**

```text
list_pages          # find which tab is selected
take_snapshot       # get a11y tree (cheap, text-based)
```

**Switch to a different tab:**

```text
list_pages
select_page { pageId: 2 }
take_snapshot
```

**Read your real cookies for a site:**

```text
new_page { url: "https://app.example.com" }
evaluate_script { function: "() => document.cookie" }
```

**Run Lighthouse on a page:**

```text
navigate_page { url: "https://elnora.ai" }
lighthouse_audit
```

### Best practice: snapshot before screenshot

`take_snapshot` returns the accessibility tree as text — fast, cheap,
and gives you stable `uid`s to pass to `click` / `fill`. Only use
`take_screenshot` when you actually need to *see* the page.

### What NOT to do

- **Never click bank or financial-action buttons.** Read-only is
  fine; never execute trades, send money, or initiate transfers.
- **Never click suspicious links from emails or messages without
  verifying the URL.** Inspect `href` first via `evaluate_script`.
- **Don't trigger `alert()` / `confirm()` dialogs unintentionally** —
  they block subsequent tool calls until dismissed. Use
  `handle_dialog` to clear them.

---

## Verification

In a Claude Code session inside this repo:

```bash
# Package resolves on npm
npm view chrome-devtools-mcp version

# MCP server registered
claude mcp list | grep chrome-devtools

# Watchdog process (after first tool call)
ps -ef | grep chrome-devtools-mcp | grep -v grep
```

Inside Claude:

- "list my chrome tabs" → should return your real tabs.
- "take a snapshot of the current tab" → should return an
  accessibility tree.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `list_pages` returns empty | Chrome not running, or running with `--remote-debugging-port` set to a non-default value | Quit Chrome fully, reopen normally, retry |
| `list_pages` errors with "no browser" | Chrome version <144 | Upgrade Chrome via `chrome://settings/help` |
| MCP server not in `claude mcp list` | Stale Claude Code cache | Restart Claude Code (`claude .`) |
| `npx` errors on Windows | Bare `npx` without `cmd /c` | Confirm `~/.claude/.mcp.json` has the Windows override (re-run `setup-windows.ps1`) |
| Tool calls hang | A modal dialog (`alert`/`confirm`) is open | Dismiss it manually in Chrome, or call `handle_dialog` |
| First call is slow | `npx` downloading the package | One-time; subsequent sessions reuse `~/.npm/_npx/` cache |
| `take_snapshot` returns garbled text | Page is mid-render | Call `wait_for` first, or re-snapshot |
| Screenshot is blank | Tab is backgrounded | `select_page { pageId, bringToFront: true }` first |

### Stuck? Reset everything

```bash
# Kill the MCP watchdog
pkill -f chrome-devtools-mcp

# Quit Chrome completely (macOS)
osascript -e 'tell application "Google Chrome" to quit'

# Reopen Chrome normally, then start Claude
open -a "Google Chrome"
claude .
```

---

## Architecture

```
┌─────────────────┐     stdio      ┌─────────────────────────────┐
│  Claude Code    │ ─────────────▶ │  npx chrome-devtools-mcp     │
│  (this session) │ ◀───────────── │  (watchdog process)          │
└─────────────────┘   MCP protocol └────────────┬─────────────────┘
                                                │
                                                │ Chrome DevTools Protocol
                                                │ (local CDP endpoint, Chrome 144+)
                                                ▼
                                   ┌─────────────────────────────┐
                                   │  Your real Google Chrome     │
                                   │  All your logins, tabs,      │
                                   │  cookies, extensions         │
                                   └─────────────────────────────┘
```

- The MCP is a **stdio Node process** spawned by Claude Code.
- It talks to your real Chrome via the **Chrome DevTools Protocol**
  (CDP) over a localhost socket.
- `--autoConnect` discovers the running Chrome via the user-data-dir.
- No data leaves your machine. Google's MCP sends anonymous usage
  statistics by default — disable with `--no-usage-statistics` or
  env `CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS=1` if you care.

---

## Reference

- npm: [npmjs.com/package/chrome-devtools-mcp](https://www.npmjs.com/package/chrome-devtools-mcp)
- Source: [github.com/ChromeDevTools/chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp)
- CDP docs: [chromedevtools.github.io/devtools-protocol](https://chromedevtools.github.io/devtools-protocol/)
- Repo files:
  - `.mcp.json` — server registration (cross-platform default)
  - `setup-windows.ps1` — Windows user-level override block
  - `.claude/settings.json` — `mcp__chrome-devtools__*` permission
  - `TOOLS.md` — short summary entry pointing here

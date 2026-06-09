# TOOLS.md — Tool & Extension Catalog

Single source of truth for what's available in this repo. If it isn't listed
here, it isn't wired in by default.

> Update this file whenever you add/remove an MCP server, plugin, marketplace,
> hook, or local command. Keep entries tight — agents read this top-to-bottom.

---

## Quick map (where things live)

| Surface | File / Path | Purpose |
|---------|-------------|---------|
| Claude Code settings | `.claude/settings.json` | Enabled plugins, marketplaces, permissions, env vars |
| User overrides | `.claude/settings.local.json` (gitignored) | Per-user local settings |
| MCP servers | `.mcp.json` | Project-scoped MCP wiring |
| Knowledge base | `.claude/knowledge-base.local.md` (gitignored) | Vault path config — read, never hardcode |
| Project rules | `CLAUDE.md` | Always-loaded context + conventions |
| Recovery / handoff | `INSTALL_FOR_AGENTS.md`, `RECOVERY.md` | Phase 2 setup + repair flows |
| CI | `.github/workflows/*.yml` | bootstrap-e2e, handoff-e2e, install-smoke-test, codeql |

No local `hooks/`, `commands/`, `agents/`, or `skills/` directories exist in
`.claude/`. All slash commands and skills come from plugins.

---

## Enabled plugins (loaded on launch)

From `.claude/settings.json` `enabledPlugins`. Everything else is opt-in via
`/plugins`.

| Plugin | Marketplace | Provides |
|--------|-------------|----------|
| **commit-commands** | claude-code-plugins | `/commit`, `/commit-push-pr`, `/clean_gone` |
| **context7** | claude-plugins-official | Up-to-date library/framework docs via MCP (same tools as the standalone `context7` MCP server) |
| **claude-md-management** | claude-plugins-official | `/revise-claude-md` — audit + improve `CLAUDE.md` files |

---

## MCP servers (`.mcp.json`)

Project-scoped, loaded for every session in this repo.

| Server | Transport | Endpoint | What it provides |
|--------|-----------|----------|------------------|
| **context7** | http | `https://mcp.context7.com/mcp` | `query-docs`, `resolve-library-id` — current library/framework docs |
| **grep** | http | `https://mcp.grep.app` | `searchGitHub` — semantic code search across **public** GitHub repos. **Privacy:** queries are sent to a third-party service; never search proprietary code or secrets. |
| **chrome-devtools** | stdio (`npx chrome-devtools-mcp@latest --autoConnect`) | local | Take over your real Chrome via CDP — list/create tabs, navigate, screenshot, run JS, read network/console, Lighthouse. Requires Chrome 144+ running. Setup + recipes: [`docs/chrome-devtools-mcp-setup.md`](docs/chrome-devtools-mcp-setup.md). Windows: `setup-windows.ps1` writes a user-level override wrapping `npx` in `cmd /c`. |

Other plugins (e.g. `playwright`) ship their own MCP servers and only load
when you enable that plugin via `/plugins`.

---

## Configured marketplaces

From `extraKnownMarketplaces` in `.claude/settings.json`. Browse with
`/plugins`.

| Marketplace | Source | autoUpdate | Default-enabled plugins |
|-------------|--------|------------|-------------------------|
| **claude-code-plugins** | `anthropics/claude-code` | yes | `commit-commands` |
| **claude-plugins-official** | `anthropics/claude-plugins-official` | yes | `context7`, `claude-md-management` |
| **anthropic-agent-skills** | `anthropics/skills` | yes | none (recommended: `document-skills`) |
| **knowledge-work-plugins** | `anthropics/knowledge-work-plugins` | yes | none — sales, finance, legal, HR, marketing, product, support, data, design, bio-research, etc. |
| **claude-code-workflows** | `wshobson/agents` | yes | none — community workflows (security, docs, analytics, HR/legal) |

See `marketplace-plugins.md` for the full per-marketplace plugin catalog.

---

## Permissions (`.claude/settings.json`)

Reminder from `CLAUDE.md`: the `deny` list is a **speed-bump, not a security
boundary**. It pattern-matches surface form only.

**Allow** (auto-approved, no prompt):
- Built-ins: `Read`, `Edit`, `Write`, `Glob`, `Grep`, `WebFetch`, `WebSearch`, `Agent`, `NotebookEdit`, `Monitor`, `Bash`
- MCP: `mcp__context7__*`, `mcp__grep__*`, `mcp__chrome-devtools__*`

**Deny** (blocked outright):
- Force pushes: `git push --force[ *]`, `git push -f[ *]`
- Destructive git: `git reset --hard*`, `git clean -f*`, `git clean -fd*`
- `rm -rf *`, `rm -fr *`, `rm -rf /*`, `rm -rf ~/*`, `rm -rf $HOME*`
- `sudo *`
- `shutdown*`, `reboot*`, `halt*`

---

## Env vars (`.claude/settings.json`)

| Var | Value | Effect |
|-----|-------|--------|
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `1` | Enables agent teams (TeamCreate / TeamDelete) |
| `CLAUDE_CODE_NO_FLICKER` | `1` | Reduces terminal redraw flicker |

Other settings: `autoUpdatesChannel: latest`, `remoteControlAtStartup: true`,
`hooks: {}` (no hooks configured).

---

## Slash commands

All come from enabled plugins — no project-local commands.

| Command | Source | What it does |
|---------|--------|--------------|
| `/commit` | commit-commands | Conventional commit |
| `/commit-push-pr` | commit-commands | Commit, push, open PR |
| `/clean_gone` | commit-commands | Prune branches deleted on remote (incl. worktrees) |
| `/revise-claude-md` | claude-md-management | Audit + update `CLAUDE.md` |
| `/plugins` | built-in | Browse / install / remove plugins |
| `/help`, `/clear`, `/config` | built-in | Standard CLI |

---

## Skills (auto-triggered)

Trigger phrases are listed in each plugin's `SKILL.md`; the harness invokes
them when a user message matches.

`claude-md-management` exposes a `claude-md-improver` skill alongside its
slash command.

---

## Built-in tools (always available)

| Tool | What it does |
|------|--------------|
| `Read`, `Write`, `Edit` | File I/O (text, images, PDFs, notebooks) |
| `Glob`, `Grep` | File pattern + content search |
| `Bash` | Shell commands |
| `WebFetch`, `WebSearch` | Web fetch + search |
| `Agent` | Spawn sub-agents |
| `Monitor` | Stream events from background processes |
| `NotebookEdit` | Edit Jupyter cells |
| `Task*` | TaskCreate, TaskUpdate, TaskList, TaskGet, TaskStop, TaskOutput |
| `ScheduleWakeup`, `Cron*` | Self-paced loops + scheduled runs |
| `Skill`, `ToolSearch` | Invoke skills, fetch deferred tool schemas |

---

## Local CI / scripts (informational)

Not invokable from chat, but agents may need to know they exist.

| Path | Purpose |
|------|---------|
| `install.sh` / `install.ps1` | Phase 1 — clone + extract starter kit |
| `setup-mac.sh` / `setup-windows.ps1` | Phase 2 — install Claude Code, wire MCP |
| `.vscode/run-handoff.{sh,ps1}` | One-shot Phase 1→2 handoff prompt opener |
| `.github/workflows/bootstrap-e2e.yml` | E2E bootstrap test |
| `.github/workflows/handoff-e2e.yml` | Handoff flow E2E test |
| `.github/workflows/install-smoke-test.yml` | Cross-platform install smoke test |
| `.github/workflows/codeql.yml` | CodeQL static analysis |
| `.github/scripts/lint-ascii.py` | Enforce ASCII-only in shipped scripts |
| `tests/handoff/` | Handoff flow fixtures |
| `cache/` | Runtime scratch (gitignored except `README.md`) |

---

## Useful keyboard shortcuts

| Shortcut | What it does |
|----------|--------------|
| `Shift+Tab` x2 | Toggle Plan Mode |
| `Escape` | Cancel current generation |
| `! <cmd>` | Run a command in the user's shell, output lands in chat |
| `/help` | All commands |
| `/plugins` | Browse + install plugins |
| `/clear` | Clear conversation |

---

_Last updated: 2026-04-28_

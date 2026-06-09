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
| Bundled plugins | `plugins/` (catalog: `plugins/.claude-plugin/marketplace.json`) | Local plugin marketplace shipped in the repo (currently `vercel`, incl. v0) |
| Vertex examples | `examples/vertex/` | Runnable image (nano-banana), video (Veo 3) + voiceover (TTS) scripts |
| Knowledge base | `.claude/knowledge-base.local.md` (gitignored) | Vault path config — read, never hardcode |
| Project rules | `CLAUDE.md` | Always-loaded context + conventions |
| Recovery / handoff | `INSTALL_FOR_AGENTS.md`, `RECOVERY.md` | Phase 2 setup + repair flows |
| CI | `.github/workflows/*.yml` | bootstrap-e2e, handoff-e2e, install-smoke-test, codeql |

No local `hooks/`, `commands/`, `agents/`, or `skills/` directories exist in
`.claude/`. Slash commands and skills come from plugins — including the
repo-bundled `vercel` plugin under `plugins/`.

---

## Enabled plugins (loaded on launch)

From `.claude/settings.json` `enabledPlugins`. Everything else is opt-in via
`/plugins`.

| Plugin | Marketplace | Provides |
|--------|-------------|----------|
| **commit-commands** | claude-code-plugins | `/commit`, `/commit-push-pr`, `/clean_gone` |
| **context7** | claude-plugins-official | Up-to-date library/framework docs via MCP (same tools as the standalone `context7` MCP server) |
| **claude-md-management** | claude-plugins-official | `/revise-claude-md` — audit + improve `CLAUDE.md` files |
| **vercel** | elnora-starter-plugins (local) | Vercel deploy/setup/integration skills + **v0** (AI app builder); `/vercel:deploy`, `/vercel:setup`, `/vercel:logs`, `/vercel:integration`, `/vercel:v0`. Needs the `vercel` CLI + (for v0) a `V0_API_KEY` — see `INSTALL_FOR_AGENTS.md`. |

---

## MCP servers (`.mcp.json`)

Project-scoped, loaded for every session in this repo. All four are
auto-approved on first launch via `enableAllProjectMcpServers: true` in
`.claude/settings.json` — no per-server approval prompt. Verify with
`claude mcp list` (each should read `Connected`). For Codex, port these into
`~/.codex/config.toml` (Codex does not read `.mcp.json`).

| Server | Transport | Endpoint | What it provides |
|--------|-----------|----------|------------------|
| **context7** | http | `https://mcp.context7.com/mcp` | `query-docs`, `resolve-library-id` — current library/framework docs |
| **grep** | http | `https://mcp.grep.app` | `searchGitHub` — semantic code search across **public** GitHub repos. **Privacy:** queries are sent to a third-party service; never search proprietary code or secrets. |
| **chrome-devtools** | stdio (`npx chrome-devtools-mcp@latest --autoConnect`) | local | Take over your real Chrome via CDP — list/create tabs, navigate, screenshot, run JS, read network/console, Lighthouse. Requires Chrome 144+ running. Setup + recipes: [`docs/chrome-devtools-mcp-setup.md`](docs/chrome-devtools-mcp-setup.md). Windows: `setup-windows.ps1` writes a user-level override wrapping `npx` in `cmd /c`. |
| **estonian** | http | `https://estonian-mcp.fly.dev/mcp` | Estonian language tools — spell check, morphology, synonyms, register. Use for any Estonian writing/proofreading instead of guessing case forms. |

Other plugins (e.g. `playwright`) ship their own MCP servers and only load
when you enable that plugin via `/plugins`.

---

## Configured marketplaces

From `extraKnownMarketplaces` in `.claude/settings.json`. Browse with
`/plugins`.

| Marketplace | Source | autoUpdate | Default-enabled plugins |
|-------------|--------|------------|-------------------------|
| **elnora-starter-plugins** | local `directory: ./plugins` | n/a | `vercel` — bundled in the repo; auto-registers when you trust the folder, no clone needed |
| **claude-code-plugins** | `anthropics/claude-code` | yes | `commit-commands` |
| **claude-plugins-official** | `anthropics/claude-plugins-official` | yes | `context7`, `claude-md-management` |
| **anthropic-agent-skills** | `anthropics/skills` | yes | none (recommended: `document-skills`) |
| **knowledge-work-plugins** | `anthropics/knowledge-work-plugins` | yes | none — sales, finance, legal, HR, marketing, product, support, data, design, bio-research, etc. |
| **claude-code-workflows** | `wshobson/agents` | yes | none — community workflows (security, docs, analytics, HR/legal) |
| **claude-for-legal** | `anthropics/claude-for-legal` | yes | none — commercial, privacy, product, corporate, employment, IP legal agents (contracts, NDAs, DPAs) |
| **claude-for-financial-services** | `anthropics/financial-services` | yes | none — IB, equity research, PE, wealth mgmt, comps/DCF/LBO, earnings, GL reconciliation |
| **superpowers-marketplace** | `obra/superpowers-marketplace` | yes | none — brainstorming, writing plans, parallel agents, TDD, systematic debugging, git worktrees |
| **addy-agent-skills** | `addyosmani/agent-skills` | yes | none — a focused set of high-quality agent skills |

All four above are **registered only** — browse and install via `/plugins`. See
`marketplace-plugins.md` for the full per-marketplace plugin catalog.

---

## Permissions (`.claude/settings.json`)

Reminder from `CLAUDE.md`: the `deny` list is a **speed-bump, not a security
boundary**. It pattern-matches surface form only.

**Allow** (auto-approved, no prompt):
- Built-ins: `Read`, `Edit`, `Write`, `Glob`, `Grep`, `WebFetch`, `WebSearch`, `Agent`, `NotebookEdit`, `Monitor`, `Bash`
- MCP: `mcp__context7__*`, `mcp__grep__*`, `mcp__chrome-devtools__*`, `mcp__estonian__*`

**Deny** (blocked outright):
- Force pushes: `git push --force[ *]`, `git push -f[ *]`
- Destructive git: `git reset --hard*`, `git clean -f*`, `git clean -fd*`
- `rm -rf *`, `rm -fr *`, `rm -rf /*`, `rm -rf ~/*`, `rm -rf $HOME*`
- `sudo *`
- `shutdown*`, `reboot*`, `halt*`
- Destructive/irreversible Vercel ops: `vercel remove/rm`, `vercel project rm`,
  `vercel domains rm/buy/move/transfer-in`, `vercel env add/update/rm`,
  `vercel alias/certs/blob/cache/integration/flags/redirects` removals,
  `vercel promote/rollback`, and `vercel api` calls with a mutating method
  (`-X POST/PUT/PATCH/DELETE`). Read-only `vercel` commands are not denied.

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

All come from plugins (the bundled `vercel` plugin plus the marketplace ones) —
no `.claude/`-local commands.

| Command | Source | What it does |
|---------|--------|--------------|
| `/commit` | commit-commands | Conventional commit |
| `/commit-push-pr` | commit-commands | Commit, push, open PR |
| `/clean_gone` | commit-commands | Prune branches deleted on remote (incl. worktrees) |
| `/revise-claude-md` | claude-md-management | Audit + update `CLAUDE.md` |
| `/vercel:deploy` | vercel | Deploy the current project |
| `/vercel:setup` | vercel | Install Vercel CLI + link project |
| `/vercel:logs` | vercel | View deployment logs |
| `/vercel:integration` | vercel | Manage Vercel Marketplace integrations |
| `/vercel:v0` | vercel | Generate/iterate a UI or app with v0 |
| `/plugins` | built-in | Browse / install / remove plugins |
| `/help`, `/clear`, `/config` | built-in | Standard CLI |

---

## Skills (auto-triggered)

Trigger phrases are listed in each plugin's `SKILL.md`; the harness invokes
them when a user message matches.

`claude-md-management` exposes a `claude-md-improver` skill alongside its
slash command.

The bundled `vercel` plugin adds: `vercel` (CLI reference + decision tree),
`deploy`, `setup`, `integration`, and `v0` (build/iterate UIs via the v0
Platform API). These fire on Vercel/v0-specific phrasing, not generic words.

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
| `plugins/vercel/` | Bundled Vercel + v0 plugin (skills, commands, references) |
| `examples/vertex/` | Runnable image + video + voiceover scripts (`out/` gitignored) |

---

## External CLIs / cloud (agent-assisted setup)

Not wired in by default — the binary/credentials are installed per-user via
`INSTALL_FOR_AGENTS.md` (optional steps). Once set up, the bundled plugin and
example scripts use them.

| Tool | What it's for | Setup |
|------|---------------|-------|
| **Vercel CLI** (`vercel`) | Deploy/manage projects | `npm i -g vercel` + `vercel login`; `INSTALL_FOR_AGENTS.md` step 6 |
| **v0** (Vercel AI app builder) | Generate UIs/apps; hackathon **credits** | `V0_API_KEY` in `.env`; `v0` skill / `INSTALL_FOR_AGENTS.md` step 6 |
| **gcloud + Vertex AI** | Image (nano-banana), video (Veo 3), voiceover (TTS) — and any Google Cloud AI API via the ADC-token recipe | [`docs/google-cloud-vertex-setup.md`](docs/google-cloud-vertex-setup.md); `INSTALL_FOR_AGENTS.md` step 7. Uses the user's **own** GCP project — no committed credentials. |

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

_Last updated: 2026-06-10_

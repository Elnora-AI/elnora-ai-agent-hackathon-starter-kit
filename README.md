# Elnora AI Agent Hackathon Starter Kit

One-command setup that installs and wires together Claude Code and the
supporting dev tools (Python, Node.js, Git, GitHub CLI, VS Code, Obsidian) you
need to build AI agents from the terminal.

Built for the **Elnora & EFS AI hackathon workshop**: run one command and you're
at a working agent environment in 15–25 minutes, no setup rabbit holes — so you
spend the workshop building your agent, not fighting installers.

## Who this is for

**Hackathon participants** who want the fastest path from a fresh laptop to a
working Claude Code environment, without chasing installers or learning what
`brew` is on day one.

Also a useful starting point for anyone bootstrapping a Claude Code project,
validating an existing setup, or using this as a template to build their own
agents and plugins.

## Requirements

- macOS or Windows 10/11 with admin rights (Homebrew or WinGet need them).
- Active [Claude Pro or Max](https://claude.com/upgrade) subscription.
- [GitHub account](https://github.com/signup), used in Phase 2 to create your private repo.

## Install

**macOS:** open Terminal (`Cmd+Space`, type `Terminal`):

```bash
curl -fsSL https://raw.githubusercontent.com/Elnora-AI/elnora-ai-agent-hackathon-starter-kit/main/install.sh | bash
```

**Windows:** open **PowerShell** (Start key, type `PowerShell`). Not Command Prompt or cmd.

```powershell
irm https://raw.githubusercontent.com/Elnora-AI/elnora-ai-agent-hackathon-starter-kit/main/install.ps1 | iex
```

Runtime is 15–25 minutes on a fresh machine, faster on re-runs.

A few things to expect:

- macOS will prompt for your Mac login password (Homebrew). No characters appear as you type. Normal.
- A browser opens to sign into Claude Pro/Max. Sign in, then return to the terminal.
- Claude takes over and finishes Phase 2 setup.

The script downloads installers from `raw.githubusercontent.com` and
`claude.ai` over HTTPS without separate checksum verification. Running it
means trusting those sources.

## If it stops, just run it again

The script stopped, you closed the terminal, or sign-in didn't go through?
**Just run it again** with the command below. It resumes right where it left
off — already-installed tools are skipped in seconds and you land back at the
step that stopped you. Nothing is lost or repeated.

```bash
# macOS
bash setup-mac.sh
```

```powershell
# Windows
.\setup-windows.ps1
```

When it restarts you'll see `Resuming where a previous run left off` at the
top, so you know it's continuing — not starting over.

The most common stopping point is the **Claude sign-in** step. If that's where
you are, make sure you have an active [Claude Pro/Max](https://claude.com/upgrade)
account, then re-run and complete the login when the browser opens.

Want a completely clean run instead? Add `--fresh` to start from scratch:
`bash setup-mac.sh --fresh` (macOS) or `.\setup-windows.ps1 --fresh` (Windows).

## What happens

1. **Phase 1 install (~5–10 min):** prompts for a name for your workspace
   (used for both the local folder and the GitHub repo we'll create later),
   clones the repo to `~/Documents/<your-name>/`, and installs Claude Code,
   Node.js, Git, Python, VS Code, GitHub CLI, and Obsidian. Existing installs
   are skipped. Output goes to `~/claude-starter-install.log`.
2. **Auth:** Claude Pro/Max (required), GitHub CLI (skippable).
3. **Phase 2 handoff (~3–5 min):** Claude verifies versions, creates your
   **private GitHub repo**, pushes the kit to it, runs a smoke test, and
   optionally configures a knowledge base.

## What gets installed

| Tool | Role |
|------|------|
| Claude Code | Orchestrating agent. Your interface. |
| Python 3, Node.js | Runtimes for plugins, MCP servers, scripts. |
| Git, GitHub CLI | Version control and Phase 2 repo creation. |
| VS Code | Editor for files Claude produces. |
| Obsidian | Markdown knowledge-base viewer. |

## Repository layout

```
<your-workspace>/                          # e.g. carmen-agents, set during install
├── README.md                              # This file
├── INSTALL_FOR_AGENTS.md                  # Phase 2 sequence executed by Claude
├── RECOVERY.md                            # Failure modes and remediation steps
├── CLAUDE.md                              # Project instructions loaded by Claude
├── TOOLS.md                               # Installed tools, plugins, and integrations
├── marketplace-plugins.md                 # Recommended plugin marketplaces
├── install.sh / install.ps1               # Bootstrap entry points
├── setup-mac.sh / setup-windows.ps1       # Phase 1 setup scripts
├── .env.template                          # Environment variable placeholders
├── .mcp.json                              # MCP server configuration
├── .gitignore
├── LICENSE                                # MIT
├── .claude/
│   ├── settings.json                      # Plugins, permissions, env defaults
│   └── knowledge-base.local.md.template   # Per-user knowledge-base config
└── docs/
    └── getting-started.md                 # Daily-workflow guide + manual fallback
```

## Post-install

You'll have a **private** GitHub repo on your account. The `origin` remote
points at it (verify with `git remote -v`). From here it's yours: commit,
push, branch, rename. Keep this one private; spin up a separate public repo
if you want to share something later.

## Knowledge base (optional)

The kit can connect Claude to a local Obsidian vault or any directory.
Phase 2 auto-detects vaults in iCloud, Google Drive, OneDrive, Dropbox, and
`~/Documents`. Config lives in `.claude/knowledge-base.local.md`
(gitignored). See `CLAUDE.md` → "Knowledge Base".

## Troubleshooting

See [`RECOVERY.md`](RECOVERY.md). For unresolved issues, attach
`~/claude-starter-install.log`.

## Manual setup

No Claude Pro/Max, or the install failed? `docs/getting-started.md` walks
through the equivalent manual steps.

## Configuration

Defaults in `.claude/settings.json`:

- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` enables [multi-agent teams](https://code.claude.com/docs/en/agent-teams).
- `CLAUDE_CODE_NO_FLICKER=1` opts into the [full-screen alt-buffer renderer](https://code.claude.com/docs/en/fullscreen).
- `autoUpdatesChannel: "latest"` opts into [auto-updates](https://code.claude.com/docs/en/setup#auto-updates) on the `latest` channel. Use `"stable"` for ~1-week-old builds. Ignored for package-manager installs.
- `remoteControlAtStartup: true` auto-enables [Remote Control](https://code.claude.com/docs/en/remote-control). Sessions are reachable from any device signed into your Claude account; review before enabling on machines that handle proprietary data.

Set values to `false` or `"0"` to disable.

## Need custom integrations?

This kit is the foundation: Claude Code set up and ready to build agents. It
does not ship with integrations to your specific instruments, LIMS, ELN, or
internal systems.

We're forward-deployed engineers who build those for biotech, pharma, and
techbio teams. If you want your agents connected to the tools you actually use
(instrument data, sample tracking, inventory, internal databases, anything
else), we'll scope it, build it on top of this repo, and get your first
agents running in production.

Email [carmen.kivisild@elnora.ai](mailto:carmen.kivisild@elnora.ai) to start
a conversation.

## License

MIT.

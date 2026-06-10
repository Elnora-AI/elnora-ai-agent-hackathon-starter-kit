# Elnora AI Agent Hackathon Starter Kit

One command sets up everything you need to build AI agents on your laptop — your
coding agent (**Claude Code or Codex**, your choice) plus the dev tools that go
with it: Python, Node.js, Git, VS Code, and Obsidian.

Built for the **Elnora AI agent hackathon**: run one command, follow the
instructions, and get your first agents up and running.

## Who this is for

Anyone who wants the fastest path from a fresh laptop to a working Claude Code or
Codex setup. It also works as a clean starting template for any agent project.

## Requirements

- macOS or Windows 10/11 with admin rights (Homebrew or WinGet need them).
- A plan or API key for the agent you pick:
  - **Claude Code** — an active [Claude Pro or Max](https://claude.com/upgrade)
    subscription (or an Anthropic API key).
  - **Codex** — an active [ChatGPT Plus/Pro](https://chatgpt.com) plan (or an
    OpenAI API key).
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

A few things to expect:

- **Before you start, sign into your accounts in a browser and leave the tabs
  open** — your coding agent (Claude or ChatGPT for Codex) and GitHub. This
  confirms the accounts exist and makes the sign-in steps go through smoothly.
- It first asks which agent you want: **Claude Code, Codex, or both.** (Pick
  "both" and it installs both, then asks which one finishes setup right now.)
- macOS will prompt for your Mac login password (Homebrew). No characters appear as you type. Normal.
- A browser opens to sign into your agent (Claude Pro/Max, or ChatGPT for Codex). Sign in, then return to the terminal.
- Your agent takes over and finishes Phase 2 setup.

The script downloads installers from `raw.githubusercontent.com`, `claude.ai`,
and `chatgpt.com` over HTTPS without separate checksum verification. Running it
means trusting those sources.

## If it stops, just run it again

Stopped, closed the terminal, or sign-in didn't go through? **Run the same
install one-liner again** (from [Install](#install) above). It remembers the
workspace you already started and offers to resume it — already-installed
tools are skipped, and your `.env` / local config files are preserved. You'll
see `Resuming where a previous run left off`, so you know it's continuing,
not starting over.

The most common stopping point is the **sign-in** step — make sure your agent
account is active, then re-run and complete the login when the browser opens.

You can also run the setup script inside your workspace folder directly.
These commands work from any directory in a fresh terminal — replace
`<your-workspace>` with the workspace name you chose:

```bash
# macOS
bash ~/Documents/<your-workspace>/setup-mac.sh
```

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\Documents\<your-workspace>\setup-windows.ps1"
```

Want a completely clean run instead? Add `--fresh` to the end of either
command.

### Script "not recognized" / not found? Setup already finished

If the setup script is missing from your workspace folder, that's not an
error — it means **setup completed**. The final cleanup step removes the
install scripts once everything is done, so there is nothing left to re-run.
To continue working with your agent, open a terminal and start it in your
workspace:

```bash
# macOS
cd ~/Documents/<your-workspace>
claude        # or codex
```

```powershell
# Windows
cd $env:USERPROFILE\Documents\<your-workspace>
claude        # or codex
```

## What happens

1. **Phase 1 install:** asks which agent you want (Claude Code / Codex / both)
   and a name for your workspace (used for both the local folder and the GitHub
   repo we'll create later), clones the repo to `~/Documents/<your-name>/`, and
   installs your chosen agent(s) plus Homebrew/WinGet, Node.js, Git, Python, VS
   Code, GitHub CLI, and Obsidian. Existing installs are skipped. Output goes to
   `~/claude-starter-install.log`.
2. **Auth:** your agent (required), GitHub CLI (skippable).
3. **Phase 2 handoff:** your agent verifies versions, creates your **private
   GitHub repo**, pushes the kit to it, runs a smoke test, and optionally sets up
   a knowledge base and the Vercel / Google Cloud integrations.

## What gets installed

Phase 1 installs these on every run (skipping anything you already have):

| Tool | Role |
|------|------|
| Claude Code and/or Codex | Your coding agent. Your interface. (You pick at install time.) |
| Homebrew (macOS) / WinGet (Windows) | Package manager used to install everything below. |
| Node.js | Runtime for plugins, MCP servers, and the agent CLIs. |
| Python 3 | Runtime for scripts and examples. |
| Git | Version control. |
| GitHub CLI (`gh`) | Creates and pushes your private repo in Phase 2. |
| VS Code | Editor for files your agent produces. |
| Obsidian | Markdown knowledge-base viewer. |

In Phase 2, your agent offers to help you set up the following — it only
installs each one **if you say yes**:

| Tool | Role |
|------|------|
| Vercel CLI (`vercel`) | Deploy apps and use v0 to generate UIs. |
| Google Cloud CLI (`gcloud`) | Run the Vertex AI image, video, and voiceover examples. |

Your agent can also set up a knowledge base (Obsidian vault — see the section
below) and finish enabling Chrome DevTools browser control in Phase 2 (the MCP
server is pre-connected; Phase 2 turns on Chrome's remote debugging — see
[`docs/chrome-devtools-mcp-setup.md`](docs/chrome-devtools-mcp-setup.md)).

## What's already wired up

The kit comes pre-connected so these work on first launch:

- **MCP servers:** Chrome DevTools (control a browser), Context7 (live docs),
  grep (search public GitHub), Estonian (language tools).
- **Vercel + v0 plugin:** deploy and generate UIs with `/vercel:deploy`,
  `/vercel:v0`, and more.
- **Vertex AI examples** in `examples/vertex/`: generate images, video, and
  voiceover using your own Google Cloud project.

## Repository layout

```
<your-workspace>/                          # e.g. carmen-agents, set during install
├── README.md                              # This file
├── INSTALL_FOR_AGENTS.md                  # Phase 2 sequence executed by your agent
├── RECOVERY.md                            # Failure modes and remediation steps
├── CLAUDE.md                              # Project instructions (Claude Code reads this)
├── AGENTS.md                              # Project instructions (Codex reads this)
├── TOOLS.md                               # Installed tools, plugins, and integrations
├── marketplace-plugins.md                 # Recommended plugin marketplaces
├── install.sh / install.ps1               # Bootstrap entry points
├── setup-mac.sh / setup-windows.ps1       # Phase 1 setup scripts
├── .env.template                          # API-key placeholders — copy to .env, never edit in place
├── .mcp.json                              # MCP servers (Chrome DevTools, Context7, grep, Estonian)
├── .gitignore
├── LICENSE                                # MIT
├── .claude/
│   ├── settings.json                      # Plugins, permissions, env defaults
│   └── knowledge-base.local.md.template   # Per-user knowledge-base config
├── plugins/                               # Bundled local plugins (vercel + v0)
│   └── vercel/
├── examples/
│   └── vertex/                            # Runnable image (nano-banana), video (Veo 3) + voiceover scripts
└── docs/
    ├── getting-started.md                 # Daily-workflow guide + manual fallback
    └── google-cloud-vertex-setup.md       # gcloud + Vertex AI: image, video, voiceover + more
```

## Post-install

You'll have a **private** GitHub repo on your account. The `origin` remote
points at it (verify with `git remote -v`). From here it's yours: commit,
push, branch, rename. Keep this one private; spin up a separate public repo
if you want to share something later.

**Reopening the project in VS Code:** setup leaves a
`<your-workspace>.code-workspace` file in the folder and opens that (not the
bare folder), so your project shows up as one clear entry under
**File → Open Recent** and can be pinned to the Dock/taskbar. Setup also turns
on VS Code's "reopen windows on launch" so quitting and relaunching brings the
project back automatically — no hunting for the folder.

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
- `enableAllProjectMcpServers: true` auto-approves every MCP server in [`.mcp.json`](.mcp.json) (Chrome DevTools, Context7, grep, Estonian) so they're connected and usable on first launch — no per-server approval prompt. Remove this key if you'd rather approve each server manually.

Set values to `false` or `"0"` to disable.

## License

MIT.

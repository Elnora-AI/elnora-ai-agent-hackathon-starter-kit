# Getting Started — First Steps After Install

You've got Claude Code installed and running. Here's how to make the most of it.

---

## Daily workflow

1. **Open your project** in VS Code
2. **Open the terminal** (`` Ctrl+` `` or View > Terminal)
3. **Start Claude** by typing `claude` and pressing Enter
4. **Ask Claude to help** with whatever you're working on

Claude remembers context within a conversation. When you start a new conversation (`/clear` or close the terminal), Claude reads `CLAUDE.md` again for project context but doesn't remember what you discussed before.

---

## Things to try this week

### Talk to Claude like a colleague

You don't need special syntax. Just describe what you want in plain English:

- "Read the file `report.docx` and summarize the key findings"
- "Create a new markdown file with meeting notes from today"
- "Search all files in this project for mentions of 'budget'"
- "Help me write an email to the team about the Q2 timeline"

### Use your knowledge base

Point Claude at your own markdown notes — an Obsidian vault synced via
Dropbox/Google Drive/OneDrive/iCloud, or just a plain folder of `.md` files.
The vault path lives in `.claude/knowledge-base.local.md` (gitignored, one per
machine). If that file doesn't exist yet, just ask Claude something like
"search my knowledge base for X" — it runs the first-run setup, auto-detects
candidate vaults, and writes the config for you.

Once configured, try:

- "What's in my knowledge base about [topic]?"
- "Search the knowledge base for [keyword]"
- "Read the meeting notes from April 14"

The more files you have in the vault, the more useful this becomes.

### Try the plugins you installed

If you installed `document-skills`:
- "Read this PDF and summarize it" (drag a PDF into VS Code or give Claude the file path)
- "Create a Word document with [content]"
- "Create an Excel spreadsheet tracking [data]"
- "Make a PowerPoint presentation about [topic]"

### Use Plan Mode for bigger tasks

Press `Shift+Tab` twice to toggle Plan Mode. In this mode, Claude plans out the steps before doing anything. Good for:
- Multi-file changes
- Tasks you want to review before executing
- Complex projects where you want to see the approach first

### Customize your CLAUDE.md

The more context you give Claude in `CLAUDE.md`, the better it performs. Add:
- Your project's specific terminology
- Folder structure explanations
- Preferred coding style or formatting
- Links to documentation
- Team conventions

---

## Useful commands

| Command | What it does |
|---------|-------------|
| `claude` | Start a new Claude Code conversation |
| `/help` | Show all available commands |
| `/plugins` | Browse and install plugins |
| `/commit` | Commit your changes (if commit-commands plugin is installed) |
| `/clear` | Clear conversation and start fresh |
| `Shift+Tab` (x2) | Toggle Plan Mode |
| `Escape` | Stop Claude's current response |

---

## Keeping your setup up to date

Claude Code updates automatically. For plugins:

1. Run `/plugins`
2. Check for updates in your installed plugins
3. Update as needed

Marketplaces registered in this starter kit have `autoUpdate: true`, so Claude
Code pulls the latest definitions at session start. The Elnora CLI nags you
in its own output when a new version ships — re-running the setup script is
idempotent and upgrades in place.

---

## Set up your GitHub repo manually (fallback)

Phase 2 normally creates your private GitHub repo for you. If the automated
flow didn't run (no Claude Pro/Max, install failure, or you ran setup
without launching Claude after), here's the equivalent by hand. Run these
in the starter-kit directory:

```bash
# 1. Authenticate the GitHub CLI (browser flow):
gh auth login --hostname github.com --git-protocol https --web

# 2. Verify auth:
gh auth status

# 3. Initialize the local repo on main, commit everything:
git init -q
git symbolic-ref HEAD refs/heads/main
git add .
git commit -q -m "Initial commit"

# 4. Create your private repo and push the starter kit to it.
#    The default name is <your-github-username>-agents (e.g. carmen-agents):
gh repo create "$(gh api user --jq .login)-agents" --private --source=. --push

# 5. Verify it landed on main:
git fetch origin
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] && echo OK
```

If any step fails, see [`../RECOVERY.md`](../RECOVERY.md) → "GitHub auth
fails" or "GitHub repo creation fails."

---

## Authenticate Elnora AI

The setup script installs the Elnora CLI and pre-wires the hosted MCP server at
`https://mcp.elnora.ai/mcp`. The CLI authenticates with an **API key** (not
browser OAuth):

1. Open <https://platform.elnora.ai/settings> and click the **API Keys** tab.
2. Click **Create key** and copy the value (it starts with `elnora_live_`).
3. Run:

   ```bash
   elnora auth login --api-key <paste-your-key-here>
   ```

The CLI writes the key to `~/.elnora/profiles.toml` (mode 600), and every new
terminal stays authenticated. Switch profiles later with `elnora auth profiles`.

If Claude Code calls an Elnora MCP tool before you've run the CLI login, the
hosted MCP server itself prompts for the key on first use — but doing the CLI
login once is the easiest way to authenticate every surface at once.

---

## Getting help

- **Claude Code documentation**: https://docs.anthropic.com/en/docs/claude-code
- **Report issues**: https://github.com/anthropics/claude-code/issues
- **Anthropic support**: https://support.anthropic.com
- **Community**: https://github.com/anthropics/claude-code/discussions

---

## Keep going

The best way to learn is to use Claude Code for your daily work. As you get comfortable, explore more plugins, MCP servers, and custom workflows.

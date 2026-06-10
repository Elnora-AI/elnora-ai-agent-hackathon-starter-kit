# Getting Started — First Steps After Install

You've got your coding agent — **Claude Code or Codex** (whichever you picked at
install, or both) — installed and running. Here's how to make the most of it.
The commands and shortcuts below are Claude Code's; if you chose Codex, start it
with `codex` and see its own `/help` for the equivalents.

---

## Daily workflow

1. **Open your project** in VS Code. Setup already opened it as a named
   workspace, so the fastest way back is **File → Open Recent** (your project
   is the entry ending in `.code-workspace`) — or just relaunch VS Code, which
   reopens it automatically. Tip: right-click its Dock/taskbar icon while it's
   open and pin it for one-click access.
2. **Open the terminal** (`` Ctrl+` `` or View > Terminal)
3. **Start Claude** by typing `claude` and pressing Enter
4. **Ask Claude to help** with whatever you're working on

Claude remembers context within a conversation. When you start a new conversation (`/clear` or close the terminal), Claude reads `CLAUDE.md` again for project context but doesn't remember what you discussed before.

---

## Things to try this week

### Talk to Claude like a colleague

You don't need special syntax. Just describe what you want in plain English.
A few business cases to get you started (these are the kinds of things the
agents do day to day):

- "Read my recent inbox, decide who needs a reply, and draft each one"
- "Find the right decision-maker to email at [company] and draft an intro"
- "Turn this call transcript into a draft contract and save it as a PDF"
- "Research the top 10 companies in [industry] into a spreadsheet"
- "Review this contract and tell me where we're most exposed"
- "Turn this Markdown file into a polished slide deck or Google Doc"

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

### Use the tools the kit ships with

A few capabilities are wired up out of the box:

- **Live docs (Context7) and code search (grep):** "Look up the latest Next.js
  app-router docs" or "find real-world examples of [pattern] on GitHub."
- **Browser control (Chrome DevTools):** "Open this page and take a screenshot"
  or "read the console errors on localhost:3000."
- **Estonian language tools:** spell-check, word forms, and synonyms for any
  Estonian text.
- **Deploy and build UIs (Vercel + v0):** `/vercel:v0` to generate a UI,
  `/vercel:deploy` to put it online. (Needs the Vercel integration from Phase 2.)
- **Image, video, and voiceover (Vertex AI):** runnable scripts in
  `examples/vertex/`. (Needs the Google Cloud integration from Phase 2 — see
  `docs/google-cloud-vertex-setup.md`.)

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
| `codex` | Start a new Codex conversation (if you installed Codex) |
| `/help` | Show all available commands |
| `/plugins` | Browse and install plugins |
| `/commit` | Commit your changes (commit-commands plugin) |
| `/vercel:v0` | Generate a UI with v0 (Vercel plugin) |
| `/vercel:deploy` | Deploy your project to Vercel (Vercel plugin) |
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
Code pulls the latest definitions at session start. Re-running the setup script
is idempotent and upgrades installed tools in place.

---

## Set up your GitHub repo manually (fallback)

Phase 2 normally creates your private GitHub repo for you. If the automated
flow didn't run (no agent plan/key, install failure, or you ran setup
without launching the agent after), here's the equivalent by hand. Run these
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

## Getting help

- **Claude Code documentation**: https://code.claude.com/docs/en/overview
- **Claude Code issues**: https://github.com/anthropics/claude-code/issues
- **Anthropic support**: https://support.anthropic.com
- **Codex documentation & issues**: https://github.com/openai/codex
- **Community**: https://github.com/anthropics/claude-code/discussions

---

## Keep going

The best way to learn is to use Claude Code for your daily work. As you get comfortable, explore more plugins, MCP servers, and custom workflows.

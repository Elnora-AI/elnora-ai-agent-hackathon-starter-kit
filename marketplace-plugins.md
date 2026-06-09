# Plugin Marketplaces & Recommended Plugins

This guide shows you how to find, install, and manage Claude Code plugins.

---

## How to install plugins

1. Open Claude Code (in VS Code terminal or standalone)
2. Type `/plugins` and press Enter
3. You'll see the list of configured marketplaces
4. Browse a marketplace and select a plugin to install
5. Claude will download and activate it

That's it. Plugins add new skills, agents, and commands to Claude.

---

## Configured Marketplaces

These marketplaces are already configured in your `.claude/settings.json`:

### 1. Anthropic Official (`claude-code-plugins`)

**Source**: github.com/anthropics/claude-code
**Trust level**: Highest — maintained by Anthropic (the company that makes Claude)

| Plugin | What it gives you | Best for |
|--------|-------------------|----------|
| **commit-commands** ⭐ | `/commit` and `/commit-push-pr` commands | Everyone — makes Git easier |
| **feature-dev** | Guided feature development workflow | Developers building features |
| **plugin-dev** | Tools for creating your own plugins | Plugin developers |
| **security-guidance** | Security best practices and vulnerability checks | Everyone |
| **pr-review-toolkit** | PR review with multiple specialized reviewers | Teams doing code reviews |
| **code-review** | Code review command | Reviewing pull requests |
| **hookify** | Create rules to prevent unwanted behaviors | Advanced users |

⭐ = enabled by default in this starter kit (see `.claude/settings.json`).
The rest are available in this marketplace — install via `/plugins`.

### 2. Anthropic Skills (`anthropic-agent-skills`)

**Source**: github.com/anthropics/skills
**Trust level**: High — official Anthropic skills collection

| Plugin | What it gives you | Best for |
|--------|-------------------|----------|
| **document-skills** | Read/create PDFs, Word docs, Excel, PowerPoint, and more | Recommended first install — not enabled by default, install via `/plugins` |

What `document-skills` adds:
- `/pdf` — Extract text from PDFs, create new PDFs, merge/split documents
- `/docx` — Create and edit Word documents
- `/xlsx` — Create and edit Excel spreadsheets with formulas and charts
- `/pptx` — Create and edit PowerPoint presentations

### 3. Official Extras (`claude-plugins-official`)

**Source**: github.com/anthropics/claude-plugins-official
**Trust level**: High — official Anthropic extras

| Plugin | What it gives you | Best for |
|--------|-------------------|----------|
| **claude-md-management** ⭐ | Audit and improve CLAUDE.md files | Everyone |
| **context7** ⭐ | MCP-backed library/framework docs fetcher | Developers |
| **superpowers** | Planning, brainstorming, TDD, systematic debugging skills | Power users |
| **playwright** | Browser automation and web testing | Anyone testing web apps |
| **claude-code-setup** | Analyze a codebase and recommend automations | New projects |
| **stripe** | Stripe payment integration helpers | Finance / billing teams |
| **frontend-design** | Production-quality UI/web design | Designers and frontend devs |

⭐ = enabled by default in this starter kit.
The rest are available in this marketplace — install via `/plugins`.

### 4. Knowledge Work (`knowledge-work-plugins`)

**Source**: github.com/anthropics/knowledge-work-plugins
**Trust level**: High — official Anthropic knowledge-work marketplace
**Status**: Registered, **no plugins enabled by default** — browse and install what you need via `/plugins`.

Curated plugins for non-engineering knowledge work: sales, finance, legal, HR, marketing, product, customer support, data, design, operations, bio-research. Also includes partner-built integrations (Slack, Apollo, Zapier, Intercom, Figma, Prisma, CockroachDB, PlanetScale, Cloudinary, Sanity, Zoom, ZoomInfo, and more).

A few standouts:

| Plugin | What it gives you | Best for |
|--------|-------------------|----------|
| **productivity** | Task management, daily planning, memory of recurring context | Everyone |
| **enterprise-search** | One-stop search across email, chat, docs, wikis | Anyone juggling multiple tools |
| **sales** | Prospecting, outreach drafting, deal strategy, call prep | Sales / GTM |
| **finance** | Journal entries, reconciliation, variance analysis, audit prep | Finance / accounting |
| **legal** | Contract review, NDA triage, compliance workflows | In-house legal |
| **marketing** | Content creation, campaign planning, performance analysis | Marketing |
| **product-management** | Feature specs, roadmaps, user research synthesis | PMs |
| **customer-support** | Ticket triage, response drafting, escalation, KB building | Support teams |
| **bio-research** | Literature search, genomics, preclinical research tooling | Life sciences |
| **cowork-plugin-management** | Create and customize plugins tailored to your org | Plugin authors |

See the full list of 40+ plugins on [github.com/anthropics/knowledge-work-plugins](https://github.com/anthropics/knowledge-work-plugins).

### 5. Elnora AI (`elnora-plugins`)

**Source**: github.com/Elnora-AI/elnora-plugins
**Trust level**: High — maintained by Elnora AI (the platform that powers this starter kit)
**Status**: Registered with `autoUpdate: true`. The `elnora` plugin is **enabled by default** in `.claude/settings.json`, so the 8 bioprotocol skills load automatically on first launch and stay on the latest release as the marketplace publishes updates.

| Plugin | What it gives you | Best for |
|--------|-------------------|----------|
| **elnora** ⭐ | 8 bioprotocol skills (`elnora-platform`, `-orgs`, `-projects`, `-tasks`, `-files`, `-folders`, `-search`, `-admin`) wired to the Elnora MCP server | Generating, versioning, and managing wet-lab protocols from Claude Code |

⭐ = enabled by default in this starter kit.

Three independent pieces — all stay current automatically:

- **Elnora CLI** — installed by `setup-mac.sh` / `setup-windows.ps1` from `cli.elnora.ai`. Always pulls the **latest** release; re-running setup refreshes the binary in place. Set `ELNORA_CLI_VERSION` (e.g. `v1.5.0`) only if you need to pin behind a corporate NAT that hits GitHub rate limits.
- **Elnora MCP server** — pre-wired in `.mcp.json` as a remote HTTP endpoint (`https://mcp.elnora.ai/mcp`). Nothing to install locally; server-side updates apply immediately. OAuth on first call.
- **Elnora skills/agents/commands** — bundled inside the `elnora` plugin. Because the marketplace has `autoUpdate: true`, Claude Code refreshes the plugin from `Elnora-AI/elnora-plugins` automatically.

If new plugins are added to the `elnora-plugins` marketplace later, enable them by adding `"<plugin-name>@elnora-plugins": true` to the `enabledPlugins` block of `.claude/settings.json`.

### 6. Community Workflows (`claude-code-workflows`)

**Source**: github.com/wshobson/agents
**Trust level**: Medium — community-maintained, not Anthropic-verified
**Status**: Configured. **No plugins enabled by default** — browse and install what you need via `/plugins`.

| Plugin | What it gives you | Best for |
|--------|-------------------|----------|
| **security-compliance** | Security compliance auditing | Regulated environments |
| **security-scanning** | SAST, threat modeling, security hardening | Everyone |
| **code-documentation** | Technical documentation and tutorial generation | Developers |
| **business-analytics** | KPI dashboards and data storytelling | Ops / analytics |
| **hr-legal-compliance** | HR, legal docs, and GDPR compliance | HR / legal |

The marketplace has 15+ plugins total; browse the rest via `/plugins`.

---

## Other Marketplaces (add later)

These are community-maintained. Quality is generally good but not Anthropic-verified.
You can add them via `/plugins` > "Add marketplace" when you're ready.

### Superpowers — alternate source (`superpowers-marketplace`)

**Source**: github.com/obra/superpowers-marketplace
**What's in it**: Advanced workflow skills — brainstorming, TDD, systematic debugging, parallel agent dispatch. Best for power users.

> **Note**: `superpowers` is **not** enabled by default in `.claude/settings.json`
> — only `elnora`, `commit-commands`, `context7`, and `claude-md-management` are.
> Two ways to add it: install from the Anthropic-maintained
> `claude-plugins-official` marketplace (already registered in
> `extraKnownMarketplaces`, just enable via `/plugins`), or add the
> community-maintained `obra/superpowers-marketplace` source for obra's variant.

---

## What's enabled out of the box

The kit ships with four plugins already turned on in `.claude/settings.json`:

- **elnora** (from `elnora-plugins`) — bioprotocol generation, task/file/project management
- **commit-commands** (from `claude-code-plugins`) — `/commit`, `/commit-push-pr`
- **context7** (from `claude-plugins-official`) — current library docs via MCP
- **claude-md-management** (from `claude-plugins-official`) — keeps `CLAUDE.md` tidy

Open `/plugins` to see them listed as installed. You don't need to install
these — they're ready immediately.

## Recommended next installs

The most common addition for most people:

1. **document-skills** (from `anthropic-agent-skills`) — lets Claude work with PDFs, Word, Excel, PowerPoint

Then explore based on your role:

| Your role | Also consider |
|-----------|---------------|
| **Operations / Project Management** | code-review |
| **Research / Science** | document-skills covers most needs |
| **Business / Strategy** | document-skills, frontend-design |
| **Engineering / Development** | feature-dev, pr-review-toolkit, code-review |

---

## How to remove a plugin

```
/plugins
```

Select the plugin you want to remove and choose "Uninstall."

---

## How to add a new marketplace

1. Open `/plugins`
2. Select "Add marketplace"
3. Enter the marketplace name and GitHub URL
4. The marketplace will appear in your list

You can also edit `.claude/settings.json` directly — add an entry to the `extraKnownMarketplaces` object, keyed by marketplace name. Example:

```json
"extraKnownMarketplaces": {
  "my-marketplace": {
    "source": {
      "source": "git",
      "url": "https://github.com/owner/repo.git"
    },
    "autoUpdate": true
  }
}
```

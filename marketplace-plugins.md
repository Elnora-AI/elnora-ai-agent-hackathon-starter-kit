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

### Bundled: Elnora Starter Plugins (`elnora-starter-plugins`)

**Source**: local `directory: ./plugins` — shipped inside this repo, no clone needed
**Trust level**: Highest — bundled with the starter kit; auto-registers when you trust the folder

| Plugin | What it gives you | Best for |
|--------|-------------------|----------|
| **vercel** ⭐ | `/vercel:deploy`, `/vercel:setup`, `/vercel:logs`, `/vercel:integration`, plus **v0** (`/vercel:v0`, AI app builder) | Deploying apps and generating UIs |

⭐ = enabled by default in this starter kit (see `.claude/settings.json`).

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

### 5. Community Workflows (`claude-code-workflows`)

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

### 6. Claude for Legal (`claude-for-legal`)

**Source**: github.com/anthropics/claude-for-legal
**Trust level**: High — official Anthropic legal marketplace
**Status**: Registered, **no plugins enabled by default** — browse and install what you need via `/plugins`.

In-house legal agents for contracts, NDAs, and DPAs.

| Plugin | What it gives you | Best for |
|--------|-------------------|----------|
| **commercial-legal** | Vendor/MSA/SaaS review, NDA triage, playbook deviations, renewals | Commercial contracts |
| **privacy-legal** | DPA review, PIAs, DSAR responses, reg gap analysis | Privacy / data protection |
| **product-legal** | Launch review, marketing-claims review, feature risk | Product counsel |
| **corporate-legal** | M&A diligence, board minutes, written consents, entity compliance | Corporate / secretary |
| **employment-legal** | Offer/termination review, leave tracking, investigations | Employment / HR legal |
| **ip-legal** | IP-focused agents and skills | Patents / IP |

The marketplace has more (regulatory, AI governance, litigation, legal clinic, etc.); browse via `/plugins`.

### 7. Claude for Financial Services (`claude-for-financial-services`)

**Source**: github.com/anthropics/financial-services
**Trust level**: High — official Anthropic financial-services marketplace
**Status**: Registered, **no plugins enabled by default** — browse and install what you need via `/plugins`.

Reference agents and skills for IB, equity research, PE, and wealth management — comps, DCF, LBO, earnings, GL reconciliation.

| Plugin | What it gives you | Best for |
|--------|-------------------|----------|
| **investment-banking** | Comps, DCF, LBO, pitch support | IB / M&A advisory |
| **equity-research** | Earnings reviews, model building, valuation | Research analysts |
| **private-equity** | Deal screening, diligence, valuation review | PE / buyside |
| **wealth-management** | Client prep, portfolio workflows | Wealth / advisory |
| **gl-reconciler** | GL reconciliation, month-end close, statement audit | Finance / accounting |
| **fund-admin** | Fund administration workflows | Fund ops |

20+ plugins total (plus partner data connectors like LSEG and S&P Global); browse via `/plugins`.

### 8. Superpowers (`superpowers-marketplace`)

**Source**: github.com/obra/superpowers-marketplace
**Trust level**: Medium — community-maintained (Jesse Vincent / obra), not Anthropic-verified
**Status**: Registered, **no plugins enabled by default** — browse and install what you need via `/plugins`.

Advanced workflow skills for power users — brainstorming, writing plans, parallel agent dispatch, TDD, systematic debugging, git worktrees.

> A related `superpowers` plugin is also available in the Anthropic-maintained
> `claude-plugins-official` marketplace — either source works; enable via `/plugins`.

### 9. Addy Osmani Agent Skills (`addy-agent-skills`)

**Source**: github.com/addyosmani/agent-skills
**Trust level**: Medium — community-maintained (Addy Osmani), not Anthropic-verified
**Status**: Registered, **no plugins enabled by default** — browse and install what you need via `/plugins`.

A focused set of high-quality agent skills.

| Plugin | What it gives you | Best for |
|--------|-------------------|----------|
| **agent-skills** | Addy Osmani's curated agent-skill collection | Anyone wanting a small, high-signal skill set |

---

## What's enabled out of the box

The kit ships with four plugins already turned on in `.claude/settings.json`:

- **vercel** (from `elnora-starter-plugins`, bundled) — `/vercel:deploy`, `/vercel:v0`, and more
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

---
name: integration
description: Discover, install, and configure Vercel Marketplace integrations (databases, auth, logging, etc.). Use when adding third-party services to a Vercel project.
allowed-tools: [Bash]
user_invocable: true
---

# Vercel Integrations

Discover, install, and get setup guides for Vercel Marketplace integrations. Integrations provision third-party services (databases, auth, logging, etc.) and automatically inject environment variables into your project.

## Prerequisites

1. **Check Vercel CLI is installed** (needs latest for integration commands):
   ```bash
   vercel --version
   ```
   If missing or outdated: `pnpm i -g vercel@latest`

2. **Check project is linked**:
   ```bash
   ls .vercel/project.json 2>/dev/null || ls .vercel/repo.json 2>/dev/null || echo "NOT LINKED"
   ```
   If not linked, run the setup skill first.

3. **Check correct team**:
   ```bash
   vercel whoami
   ```

## Discover Available Integrations

```bash
vercel integration discover --format=json
```

Use `--format=json` for agent-parseable output. Categories include: AI, Analytics, Authentication, CMS, Databases, Logging, Monitoring, Storage, and more.

## Install an Integration

```bash
# Basic install — provisions resource and injects env vars
vercel integration add <slug> --format=json

# Specific product (multi-product integrations like Upstash)
vercel integration add <slug>/<product> --format=json

# With metadata (e.g., region selection)
vercel integration add <slug> -m primaryRegion=iad1 --format=json

# Custom resource name
vercel integration add <slug> --name my-db --format=json

# Specific environment(s)
vercel integration add <slug> -e production -e preview --format=json

# Specific billing plan
vercel integration add <slug> --plan <plan-id> --format=json
```

**Browser fallback:** The CLI may open a browser for first-time terms acceptance. It polls and resumes automatically — do not kill the process. Inform the user if this happens.

## Get Setup Guide

```bash
# General setup guide (returns agent-friendly markdown)
vercel integration guide <slug>

# Framework-specific guide
vercel integration guide <slug> --framework nextjs
```

The guide contains code snippets and configuration steps. Use this after installing to configure the project.

## List Installed Resources

```bash
vercel integration list --format=json                     # current project
vercel integration list --all --format=json               # all team resources
vercel integration list -i <slug> --format=json           # filter by integration
```

## Workflow: Add and Configure an Integration

1. **Discover** what's available:
   ```bash
   vercel integration discover --format=json
   ```

2. **Install** the integration:
   ```bash
   vercel integration add <slug> --format=json
   ```

3. **Get the setup guide**:
   ```bash
   vercel integration guide <slug>
   ```

4. **Verify env vars were injected**:
   ```bash
   vercel env pull
   cat .env.local | head -20
   ```

5. **Follow the guide** to wire up the SDK/client in the project code.

## Common Integrations

| Slug | Service | Use Case |
|------|---------|----------|
| `neon` | Neon Postgres | Serverless PostgreSQL |
| `upstash/upstash-redis` | Upstash Redis | Serverless Redis/KV |
| `upstash/upstash-qstash` | Upstash QStash | Message queue |
| `supabase` | Supabase | Postgres + Auth + Storage |
| `clerk` | Clerk | Authentication |
| `sentry` | Sentry | Error monitoring |
| `axiom` | Axiom | Logging/observability |

When unsure about available integrations, always run `vercel integration discover` first.

## Disconnect and Remove

```bash
# Disconnect resource from project (keeps resource alive)
vercel ir disconnect <resource> --yes

# Delete resource permanently (must disconnect first, or use --disconnect-all)
vercel ir remove <resource> --disconnect-all --yes

# Uninstall integration entirely (all resources must be deleted first)
vercel integration remove <slug> --yes
```

**Destructive commands require `--yes` when using `--format=json`.**

## Anti-Patterns

- **Manually setting env vars for Marketplace services** — use `vercel integration add` instead; it handles provisioning and env var injection.
- **Killing the CLI during browser-based terms acceptance** — it polls and resumes automatically.
- **Forgetting `--format=json` in automation** — without it, commands expect interactive TTY input.
- **Not specifying `/<product>` for multi-product integrations** — errors in non-TTY mode.

For the complete integration reference, see `references/integrations.md`.

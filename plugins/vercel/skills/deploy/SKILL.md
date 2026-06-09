---
name: deploy
description: Deploy applications to Vercel. Use when deploying to preview or production.
allowed-tools: [Bash]
user_invocable: true
---

# Vercel Deploy

Deploy the current project to Vercel (preview or production).

## Prerequisites

1. **Check Vercel CLI is installed**:
   ```bash
   vercel --version
   ```
   If missing: `npm i -g vercel`

2. **Check project is linked**:
   ```bash
   ls .vercel/project.json 2>/dev/null || ls .vercel/repo.json 2>/dev/null || echo "NOT LINKED"
   ```
   If not linked, run the setup skill first.

3. **Check correct team**:
   ```bash
   vercel whoami
   ```

## Deploy

### Preview deployment (default)
```bash
vercel deploy
```

### Production deployment

Production deploys overwrite what users see — confirm with the user before
running. In a monorepo, `cd` into the specific project directory first so the
right project is targeted.

```bash
vercel --prod                 # single-project repo
# OR
cd apps/web && vercel --prod  # monorepo: deploy one project
```

### Deploy with prebuilt output
If `vercel build` was run first:
```bash
vercel deploy --prebuilt
```

### Deploy with environment overrides
```bash
vercel deploy --env KEY=value
```

## Post-Deploy

1. **Display the deployment URL** from the command output.
2. If errors occur, suggest checking logs with `/vercel:logs`.
3. For domain configuration, load `references/domains-and-dns.md`.

## Anti-Patterns

- Never use `vercel deploy` after `vercel build` without `--prebuilt` — the build output is ignored.
- Never hardcode tokens in flags — use `VERCEL_TOKEN` env var.
- Never use `--yes` to skip Vercel confirmation prompts — let them run.

For full deployment reference, see `references/deployment.md`.

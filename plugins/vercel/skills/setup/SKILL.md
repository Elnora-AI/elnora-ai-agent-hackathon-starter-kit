---
name: setup
description: Set up Vercel CLI and configure project linking. Use when first connecting a project to Vercel.
allowed-tools: [Bash]
user_invocable: true
---

# Vercel Setup

First-time setup: install CLI, authenticate, link project, pull environment variables.

## Steps

### 1. Install Vercel CLI
```bash
vercel --version 2>/dev/null || npm i -g vercel
```

### 2. Authenticate
```bash
vercel login
```
Follow the browser prompt to complete authentication.

### 3. Link project

**Single project (most cases)**:
```bash
vercel link
```

**Monorepo with multiple Vercel projects**:
```bash
vercel link --repo
```

Monorepo decision: if the repo has multiple apps each deployed separately (e.g., `apps/web`, `apps/api`), use `--repo`. Otherwise, `vercel link` is fine.

### 4. Verify linking
```bash
cat .vercel/project.json 2>/dev/null || cat .vercel/repo.json 2>/dev/null
```

### 5. Pull environment variables
```bash
vercel pull
```
This creates `.vercel/.env.development.local` with your project's env vars.

### 6. Verify setup
```bash
vercel whoami && vercel project ls
```

## Post-Setup

- Run `vercel dev` to start local development with Vercel's serverless functions.
- Run `vercel deploy` for a preview deployment.
- See `references/getting-started.md` and `references/environment-variables.md` for details.

## Anti-Patterns

- Don't let commands auto-link in monorepos — always run `vercel link` (or `--repo`) explicitly first.
- Don't link while on the wrong team — check with `vercel whoami`, switch with `vercel teams switch`.

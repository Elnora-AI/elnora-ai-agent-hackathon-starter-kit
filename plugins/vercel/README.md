# Vercel Plugin

Vercel platform management — deploy, configure, monitor, and debug projects
from the CLI, plus **v0** (Vercel's AI app builder) via its Platform API.

## Skills

| Skill | Trigger | Description |
|-------|---------|-------------|
| `vercel` | vercel, CLI reference, domains, env vars | Main routing skill with decision tree and full CLI reference |
| `deploy` | deploy, preview, production | Deploy workflow with prerequisites check |
| `setup` | setup, link, install vercel | First-time project setup and linking |
| `integration` | marketplace integrations, databases, auth | Discover/install/configure Vercel Marketplace integrations |
| `v0` | v0, generate UI, v0 API/SDK, v0 credits | Build/iterate UIs and apps with the v0 Platform API |

## Commands

| Command | Description |
|---------|-------------|
| `/vercel:deploy` | Deploy the current project |
| `/vercel:setup` | Set up Vercel CLI and link project |
| `/vercel:logs` | View deployment logs |
| `/vercel:integration` | Manage Vercel Marketplace integrations |
| `/vercel:v0` | Generate or iterate on a UI/app with v0 |

## References

The `skills/vercel/references/` directory contains 17 detailed reference files
covering all Vercel CLI topics. The main skill's decision tree routes to the
appropriate reference based on the task.

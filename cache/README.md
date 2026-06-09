# cache/

Runtime scratch folder for local state, logs, and downloaded artifacts.

This folder is **gitignored** — nothing inside is committed except this README
and `.gitkeep` (so the folder exists after a fresh clone).

## What goes here

Anything that is:

- **Regenerable** — sync state JSON, cache indexes, crawl results
- **Transient** — log files from scripts, scratch images/screenshots
- **Local-only** — per-machine state that shouldn't be shared via Git

Examples:

- `*.log` — rolling logs from scripts you run locally
- `*-state.json` — last-run state for recurring jobs
- `*-cache.json` — cached API lookups to avoid rate limits
- downloaded images, generated thumbnails, scratch screenshots

## What does NOT go here

- Source code (goes in `src/`)
- Knowledge base notes (live in your vault — see `.claude/knowledge-base.local.md`)
- Documentation (goes in `docs/`)
- Config or secrets (use `.env` or `.claude/`)

## Gitignore rules

The root `.gitignore` already excludes everything inside `cache/` (with
`cache/*`, which keeps the directory tracked but ignores its contents). If
you need to commit a specific file from this folder, add a negation rule
in the **same form** the existing rules use:

```
cache/*
!cache/README.md
!cache/.gitkeep
!cache/your-file-to-commit.json
```

Don't switch to plain `cache/` — that would ignore the whole directory and
the negations wouldn't bring files back.

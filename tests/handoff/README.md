# Handoff E2E test

End-to-end test of the **Phase 1 → Phase 2 handoff** in the starter kit:
the moment when `setup-mac.sh` / `setup-windows.ps1` finishes installing
tools and hands control to Claude, who then reads `INSTALL_FOR_AGENTS.md`
and finishes setup.

This test runs the real setup script, lets it fire `claude -p` with the
production handoff prompt (in headless print mode so CI doesn't hang on
an interactive REPL), then asserts on disk that Claude actually did the
Phase 2 work.

## What it tests

After the headless handoff completes, `assert.sh` / `assert.ps1` verifies:

1. `.git/` exists with at least one commit on `main`, and `git remote` is
   empty (headless mode skips the GitHub bootstrap on purpose — no
   credentials, no browser).
2. `.claude/knowledge-base.local.md` was created and the placeholder is gone.
3. The `### First-run setup` block in `CLAUDE.md` was self-deleted.
4. The transcript contains the `HANDOFF_COMPLETE` marker.

## How to run it (manual only)

The test is opt-in — `workflow_dispatch` only, no schedule, no on-push trigger.

### 1. Set up secrets (one time)

You need an API key. Paste it into GitHub repo secrets:

> **GitHub repo → Settings → Secrets and variables → Actions → New repository secret**

| Secret name | Where to get it | Notes |
|---|---|---|
| `ANTHROPIC_API_KEY` | https://console.anthropic.com/settings/keys | Set a low monthly budget cap on the key in the Anthropic console so a runaway test can't spike the bill (measured at ~$0.45-0.55 per OS on current Sonnet pricing — but cap the key anyway). |

**For local testing** (running the headless mode on your own Mac), paste
the same values into `.env` at the repo root — that file is gitignored.

### 2. Trigger the workflow

```bash
gh workflow run handoff-e2e.yml -f os=both
```

Or use the GitHub UI: Actions → handoff-e2e → Run workflow.

`os` accepts `both` (default), `macos`, or `windows` if you only want one
platform.

### 3. Read the result

- The workflow prints the install log tail and transcript tail in the
  step output — usually enough to debug a failure.
- The full transcript is uploaded as an artifact
  (`handoff-transcript-macos` / `handoff-transcript-windows`) — download
  it from the workflow run page if you need to inspect every Claude turn.
- Assertion failures are listed at the bottom of the assertions step.

## Running headless mode locally (no CI)

Useful for debugging when the GitHub workflow is failing and you want a
faster loop. Paste your keys into `.env`, then:

```bash
# Mac:
ELNORA_HANDOFF_MODE=headless \
ELNORA_HANDOFF_LOCAL_BYPASS=1 \
ELNORA_HANDOFF_TRANSCRIPT="$PWD/handoff-transcript.jsonl" \
ANTHROPIC_API_KEY="$(grep ^ANTHROPIC_API_KEY= .env | cut -d= -f2-)" \
bash setup-mac.sh

tests/handoff/assert.sh "$PWD" "$PWD/handoff-transcript.jsonl"
```

```powershell
# Windows:
$env:ELNORA_HANDOFF_MODE = "headless"
$env:ELNORA_HANDOFF_LOCAL_BYPASS = "1"
$env:ELNORA_HANDOFF_TRANSCRIPT = "$PWD\handoff-transcript.jsonl"
# Source ANTHROPIC_API_KEY from .env or paste it
.\setup-windows.ps1
.\tests\handoff\assert.ps1 -RepoDir $PWD -Transcript "$PWD\handoff-transcript.jsonl"
```

> ⚠️ Running locally re-runs the full Phase 1 install path too. If you've
> already got everything installed it's a no-op; otherwise it'll install
> tools on your machine.
>
> `ELNORA_HANDOFF_LOCAL_BYPASS=1` is required outside CI: headless mode hands
> off to the agent with `bypassPermissions`, so the setup scripts refuse to run
> it without this explicit opt-in (they print a 5-second abort warning, then
> proceed). Without it — and without CI markers — the script exits 2.

## How the handoff knows it's in test mode

The contract is two env vars:

- `ELNORA_HANDOFF_MODE=headless` — switches `setup-mac.sh` / `setup-windows.ps1`
  from `exec claude "<prompt>"` (interactive REPL) to `claude -p "<same
  prompt>" --permission-mode bypassPermissions --output-format stream-json
  --verbose --max-turns 80` (one-shot, captured to transcript). For the Codex
  agent the equivalent one-shot path is `codex exec` instead of `claude -p`.
- `ANTHROPIC_API_KEY` — required for Claude Code to skip browser OAuth.

The handoff prompt is the same string between production and headless mode —
defined once in each setup script. Divergence there is the bug this test is
supposed to catch. (Nothing currently diffs the two prompt strings in an
assertion, so keep them in sync by hand when editing either path.)

`INSTALL_FOR_AGENTS.md` has a "Non-interactive / test mode" section that
tells Claude what to do when `ELNORA_HANDOFF_MODE=headless` is set: pull
the API key from env instead of asking, use the staged Obsidian vault,
skip the optional sample-protocol step, and print `HANDOFF_COMPLETE` at
the end.

## Cost & frequency

- ~20-30 Claude turns per run, mostly Sonnet-class work (file reads, edits,
  bash commands). Cache hit rate is consistently >93%.
- Measured at **~$0.45-0.55 per run per OS** on current Sonnet pricing
  (handoff-e2e + bootstrap-e2e together: ~$2 per full both-OS audit).
  This is a floor, not a guarantee — if `INSTALL_FOR_AGENTS.md` grows or
  the agent's flow has to recover from new errors, expect drift upward.
- Total agent wall time: ~2-3 min per OS (so a both-OS run finishes in
  ~5 min total, parallel). The job-level "15-25 min" timeout is a
  generous ceiling, not the expected runtime.
- No schedule, no auto-trigger. Run it when:
  - You changed `setup-mac.sh`, `setup-windows.ps1`, or `INSTALL_FOR_AGENTS.md`.
  - You want a confidence check before a release.
  - Something feels off and you want ground truth on what Claude does.

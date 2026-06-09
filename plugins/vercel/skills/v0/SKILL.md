---
name: v0
description: Generate and iterate on UIs/apps with Vercel v0 via the v0 Platform API. Use when building a frontend with v0, calling the v0 API/SDK, or spending v0 credits.
allowed-tools: [Bash, Read, Write, Edit]
user_invocable: true
---

# Vercel v0

[v0](https://v0.app) is Vercel's AI app builder. Beyond the web UI at
`v0.app`, it exposes a **Platform API** (and an OpenAI-compatible model API) so
you can generate UIs, components, and full apps from code.

> **Hackathon note:** participants receive **v0 credits**. The API bills
> against those credits, so you can drive v0 from the CLI without a paid
> upgrade as long as credits remain. Check usage at
> [v0.app/chat/settings/billing](https://v0.app/chat/settings/billing).

There are two distinct surfaces — pick the right one:

| Surface | Package / endpoint | Use it for |
|---------|--------------------|------------|
| **Platform API** | `v0-sdk` (npm), `https://api.v0.dev/v1` | Create/iterate **chats** that return generated files, demos, and deployable projects. This is the real "v0 builds my app" surface. |
| **Model API** | AI SDK `@ai-sdk/vercel`, `https://api.v0.dev/v1` (OpenAI-compatible) | Use v0's models (`v0-1.5-md`, etc.) as a chat/completions model inside your own app. |

## Setup (do this first)

1. **Get an API key** — [v0.app/chat/settings/keys](https://v0.app/chat/settings/keys).
   The key grants full access to the v0 account — treat it as a secret.
2. **Store it as an env var**, never in code or flags. Add to `.env` (gitignored):
   ```bash
   echo 'V0_API_KEY=your-v0-api-key' >> .env
   ```
   The SDK and CLI read `V0_API_KEY` automatically.
3. **Verify access:**
   ```bash
   curl -s https://api.v0.dev/v1/user \
     -H "Authorization: Bearer $V0_API_KEY" | head
   ```
   A JSON user object means the key works. `401` means the key is wrong or
   credits/billing aren't enabled on the account.

## Fastest path: scaffold a v0-powered app

```bash
# Spins up a Next.js app pre-wired to the v0 Platform API
pnpm create v0-sdk-app@latest my-v0-app
# or: npx create-v0-sdk-app@latest my-v0-app
```

## Platform API via the SDK (generate UI from a prompt)

```bash
pnpm add v0-sdk        # or: npm install v0-sdk
```

```ts
import { v0 } from 'v0-sdk' // reads V0_API_KEY from the environment

// Create a chat — v0 generates the app and returns a live demo + files
const chat = await v0.chats.create({
  message: 'Build a landing page for a biotech hackathon with a hero and signup form',
})

console.log('Preview:', chat.demo)        // hosted preview URL
console.log('Chat:', chat.url)            // open/iterate in the v0 web UI
// chat.files[] holds the generated source files

// Iterate on the same chat
const next = await v0.chats.sendMessage({
  chatId: chat.id,
  message: 'Make the hero dark mode and add a pricing section',
})
```

## Model API (use v0 as a model in your own app)

```bash
pnpm add ai @ai-sdk/vercel
```

```ts
import { generateText } from 'ai'
import { vercel } from '@ai-sdk/vercel' // reads V0_API_KEY

const { text } = await generateText({
  model: vercel('v0-1.5-md'),
  prompt: 'Generate a React component for a file-upload dropzone with Tailwind',
})
```

Or hit it directly — it's OpenAI-compatible:

```bash
curl https://api.v0.dev/v1/chat/completions \
  -H "Authorization: Bearer $V0_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"v0-1.5-md","messages":[{"role":"user","content":"a pricing table component"}]}'
```

## Ship what v0 builds

v0 projects deploy to Vercel. After pulling the generated files into a repo,
use the `deploy` skill (`/vercel:deploy`) or link the v0 project to Vercel from
the v0 UI. Production deploys overwrite live URLs — confirm with the user first.

## Anti-Patterns

- Never put `V0_API_KEY` in code, flags, or commits — env var only.
- Don't confuse the two surfaces: `v0-sdk` (build apps) vs `@ai-sdk/vercel`
  (use v0 as a model). They share the key and base URL but solve different jobs.
- The API spends credits/usage on every call — don't loop generations blindly;
  check remaining credits if calls start failing.

## Reference

- Platform API overview: <https://v0.app/docs/api/platform/overview>
- `v0-sdk` package docs: <https://v0.app/docs/api/platform/packages/v0-sdk>
- Quickstart: <https://v0.app/docs/api/platform/quickstart>

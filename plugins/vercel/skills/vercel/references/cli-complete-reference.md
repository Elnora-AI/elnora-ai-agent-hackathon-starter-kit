# Vercel CLI Complete Command Reference

Install: `npm i -g vercel`

## Global Options (apply to all commands)

| Flag | Short | Description |
|------|-------|-------------|
| `--cwd <path>` | | Working directory |
| `--debug` | `-d` | Verbose output |
| `--global-config <dir>` | `-Q` | Path to global `.vercel` directory |
| `--help` | `-h` | Show help |
| `--local-config <file>` | `-A` | Path to local `vercel.json` |
| `--no-color` | | Disable colored output (respects `NO_COLOR`) |
| `--scope <team>` | `-S` | Execute as different scope |
| `--team <slug|id>` | `-T` | Specify team |
| `--token <token>` | `-t` | Auth token (for CI/CD) |
| `--project <name|id>` | | Specify project |
| `--version` | `-v` | Show CLI version |

Environment variables for CI/CD:
- `VERCEL_TOKEN` — auth token
- `VERCEL_ORG_ID` — team/org ID
- `VERCEL_PROJECT_ID` — project ID
- `VERCEL_AUTOMATION_BYPASS_SECRET` — deployment protection bypass

---

## deploy (default command)

Deploy projects. Can be invoked as just `vercel` without subcommand.

```bash
vercel [path]
vercel deploy [path]
vercel --prod
vercel deploy --prebuilt
vercel deploy --prebuilt --archive=tgz
```

| Flag | Short | Description |
|------|-------|-------------|
| `--prod` | | Production deployment |
| `--prebuilt` | | Deploy pre-built output from `vercel build` |
| `--archive <tgz>` | | Compress prebuilt output for upload |
| `--env KEY=val` | `-e` | Runtime env var (repeatable) |
| `--build-env KEY=val` | `-b` | Build-time env var (repeatable) |
| `--meta KEY=val` | `-m` | Deployment metadata (repeatable) |
| `--regions <list>` | | Serverless function regions (e.g., `sfo1,iad1`) |
| `--target <env>` | | Custom deployment environment |
| `--force` | `-f` | Force fresh build (bypass cache) |
| `--with-cache` | | Retain build cache when using `--force` |
| `--no-wait` | | Return immediately without waiting |
| `--skip-domain` | | Skip auto-assigning production domains (use with `--prod`) |
| `--name <name>` | `-n` | Project name (deprecated, use `vercel link`) |
| `--public` | `-p` | Make `/_src` publicly accessible |
| `--no-clipboard` | `-C` | Don't copy URL to clipboard |
| `--yes` | `-y` | Skip confirmation prompts |
| `--guidance` | | Show suggested next steps |

## dev

Local development server replicating Vercel environment.

```bash
vercel dev
vercel dev --listen 5005
```

| Flag | Short | Description |
|------|-------|-------------|
| `--listen <port>` | `-l` | Port to listen on |
| `--yes` | `-y` | Skip setup questions |

## build

Build project locally for later deployment with `--prebuilt`.

```bash
vercel build
vercel build --prod
```

| Flag | Description |
|------|-------------|
| `--prod` | Use production env vars |
| `--yes` | Auto-pull env vars if missing |
| `--target <env>` | Build against specific environment |
| `--output <dir>` | Custom output directory (default: `.vercel/output`) |

## env

Manage environment variables.

```bash
vercel env ls
vercel env add <name> [environment] [gitbranch]
vercel env add <name> <environment> < file.txt
vercel env update <name> [environment]
vercel env rm <name> [environment]
vercel env pull [file]
vercel env run -- <command>
vercel env run -e production -- npm test
```

| Flag | Short | Description |
|------|-------|-------------|
| `--environment <env>` | `-e` | Target environment |
| `--git-branch <branch>` | | Branch-specific variable |

## pull

Download env vars and project settings to local cache.

```bash
vercel pull
vercel pull --environment=production
vercel pull --git-branch=feature-x
```

| Flag | Description |
|------|-------------|
| `--environment <env>` | Which environment to pull |
| `--git-branch <branch>` | Pull branch-specific vars |
| `--yes` | Skip questions |

## link

Associate local directory with Vercel project.

```bash
vercel link
vercel link [path]
vercel link --repo
```

| Flag | Description |
|------|-------------|
| `--repo` | Link entire repository (for monorepos, alpha) |
| `--yes` | Skip questions |
| `--project <name|id>` | Non-interactive project selection |

## login / logout / whoami

```bash
vercel login [email]
vercel logout
vercel whoami
```

## teams

```bash
vercel teams list
vercel teams add
vercel teams invite <email>
```

Alias: `vercel switch [team-name]` to change active scope.

## project

```bash
vercel project ls [--json] [--update-required]
vercel project add <name>
vercel project rm <name>
vercel project inspect [name]
```

## list (ls)

List recent deployments.

```bash
vercel list [project-name]
vercel ls
```

## inspect

Get deployment details.

```bash
vercel inspect <deployment-url|id>
vercel inspect <url> --logs
vercel inspect <url> --wait --timeout 5m
```

| Flag | Short | Description |
|------|-------|-------------|
| `--logs` | `-l` | Print build logs |
| `--wait` | | Wait for deployment to finish |
| `--timeout <duration>` | | Max wait time |

## logs

View request and runtime logs.

```bash
vercel logs
vercel logs --follow
vercel logs --environment production --status-code 5xx --since 30m
```

| Flag | Short | Description |
|------|-------|-------------|
| `--follow` | `-f` | Stream live logs |
| `--project <id|name>` | | Filter by project |
| `--deployment <id|url>` | | Filter by deployment |
| `--environment <env>` | | Filter: `production` or `preview` |
| `--level <level>` | | `error`, `warning`, `info`, `fatal` (repeatable) |
| `--status-code <code>` | | HTTP status, supports `4xx`, `5xx` wildcards |
| `--source <src>` | | `serverless`, `edge-function`, `edge-middleware`, `static` |
| `--branch <branch>` | | Filter by git branch |
| `--json` | | JSON Lines output (pipe to `jq`) |
| `--expand` | | Full message details |
| `--query <text>` | | Search logs for text |
| `--since <duration>` | | Time filter: `1h`, `30m`, `5d` |

## domains

```bash
vercel domains ls [--limit N] [--next <timestamp>]
vercel domains inspect <domain>
vercel domains add <domain> [project]
vercel domains rm <domain> [--yes]
vercel domains buy <domain>
vercel domains move <domain> <scope>
vercel domains transfer-in <domain>
```

| Flag | Description |
|------|-------------|
| `--force` | Force domain onto project (removes from existing) |
| `--limit <N>` | Max results (default 20, max 100) |
| `--next <ts>` | Pagination cursor |
| `--yes` | Skip confirmation |

## dns

```bash
vercel dns ls [domain] [--limit N]
vercel dns add <domain> <name> <type> <value> [mxPriority|srvData]
vercel dns rm <record-id>
vercel dns import <domain> <zonefile>
```

Supported record types: `A`, `AAAA`, `ALIAS`, `CNAME`, `TXT`, `MX`, `SRV`, `CAA`.

## certs

```bash
vercel certs ls [--limit N]
vercel certs issue <domain> [domain2...]
vercel certs rm <certificate-id>
```

| Flag | Description |
|------|-------------|
| `--challenge-only` | Show challenges without completing |
| `--limit <N>` | Max results |

## alias

```bash
vercel alias set <deployment-url> <custom-domain>
vercel alias rm <custom-domain>
vercel alias ls
```

## remove (rm)

```bash
vercel remove <deployment-url>
vercel remove <project-name>
```

## redeploy

```bash
vercel redeploy [deployment-id-or-url]
```

| Flag | Description |
|------|-------------|
| `--no-wait` | Return immediately |
| `--target <env>` | Target environment |

## rollback

```bash
vercel rollback [deployment-url-or-id]
vercel rollback status
```

| Flag | Description |
|------|-------------|
| `--timeout <duration>` | Max wait time |

Hobby: only previous deployment. Pro/Enterprise: any previous deployment.

## promote

```bash
vercel promote <deployment-url-or-id>
vercel promote status
```

| Flag | Description |
|------|-------------|
| `--yes` | Skip confirmation (preview to prod) |
| `--timeout <duration>` | Max wait time |

## bisect

Binary search across deployments to find when bugs were introduced.

```bash
vercel bisect
vercel bisect --good <url> --bad <url>
vercel bisect --good <url> --bad <url> --run ./test.sh
```

| Flag | Description |
|------|-------------|
| `--good <url>` | Known good deployment |
| `--bad <url>` | Known bad deployment |
| `--path <subpath>` | Subpath where issue occurs |
| `--open` | Auto-open URLs in browser |
| `--run <script>` | Automated test (exit 0=good, non-zero=bad, 125=skip) |

## cache

```bash
vercel cache purge [--type cdn|data]
vercel cache invalidate --tag <tags>
vercel cache invalidate --srcimg <path>
vercel cache dangerously-delete --tag <tags>
```

| Flag | Description |
|------|-------------|
| `--tag <tags>` | Cache tags (comma-separated) |
| `--srcimg <path>` | Source image path (image optimization) |
| `--revalidation-deadline-seconds <N>` | Time window for deletion |
| `--yes` | Skip confirmation |

## flags

Feature flag management.

```bash
vercel flags list [--state active|archived]
vercel flags add <name> [--kind boolean|string|number] [-d "desc"] [-e production]
vercel flags inspect <name>
vercel flags enable <name> -e <environment>
vercel flags disable <name> [-e <env>] [--variant <v>]
vercel flags archive <name>
vercel flags rm <name> [--yes]
```

SDK keys:
```bash
vercel flags sdk-keys ls
vercel flags sdk-keys add --type server|client --environment <env> [--label "desc"]
vercel flags sdk-keys rm <key-id>
```

## redirects

Manage project-level redirects at scale (no redeployment needed).

```bash
vercel redirects list [--page N] [--per-page N] [--search <text>] [--staged] [--version <id>]
vercel redirects add /old /new --status 301 [--case-sensitive] [--preserve-query-params] [--name <version-name>]
vercel redirects upload <file.csv|file.json> [--overwrite] [--name <version-name>]
vercel redirects list-versions
vercel redirects promote <version-id>
vercel redirects restore <version-id>
vercel redirects remove <redirect-id> [--yes]
```

## rolling-release

Gradual production rollout.

```bash
vercel rolling-release configure --cfg '<json>'
vercel rolling-release start --dpl <deployment-url>
vercel rolling-release approve --dpl <url> --currentStageIndex <N>
vercel rolling-release complete --dpl <url>
vercel rolling-release abort --dpl <url>
```

## git

```bash
vercel git ls
vercel git connect [--yes]
vercel git disconnect [--yes]
```

## blob

Vercel Blob storage.

```bash
vercel blob list
vercel blob put <path-to-file>
vercel blob get <url-or-pathname>
vercel blob del <url-or-pathname>
vercel blob copy <source> <destination>
```

## integration

```bash
vercel integration add <name>
vercel integration list [project]
vercel integration discover
vercel integration guide <name>
vercel integration balance <name>
vercel integration open <name>
vercel integration remove <name>
```

## integration-resource

```bash
vercel integration-resource remove <resource-name>
vercel integration-resource disconnect <resource-name> [project-name]
vercel integration-resource create-threshold <resource-name> <minimum> <spend> <limit>
```

## target

Custom environment management.

```bash
vercel target list
vercel target ls
```

## microfrontends (mf)

```bash
vercel microfrontends pull [--dpl <deployment-id-or-url>]
vercel mf pull
```

## curl / httpstat

Access deployments with automatic protection bypass.

```bash
vercel curl [path]
vercel curl /api/hello --deployment <url>
vercel httpstat [path]
vercel httpstat /api/data --deployment <url>
```

| Flag | Description |
|------|-------------|
| `--deployment <url>` | Target deployment URL |
| `--protection-bypass <secret>` | Custom bypass secret |

## telemetry

```bash
vercel telemetry status
vercel telemetry enable
vercel telemetry disable
```

## open

```bash
vercel open
```

Opens current project in Vercel Dashboard.

## init

```bash
vercel init [example-name]
```

Initialize from example repository.

## help

```bash
vercel help
vercel help <command>
```

---

## vercel.json Configuration Reference

Place in project root. Schema: `https://openapi.vercel.sh/vercel.json`

| Property | Type | Description |
|----------|------|-------------|
| `buildCommand` | `string \| null` | Override build command |
| `cleanUrls` | `boolean` | Remove extensions from URLs (default: false) |
| `crons` | `array` | Cron job definitions (`path` + `schedule`) |
| `devCommand` | `string \| null` | Override dev command |
| `framework` | `string \| null` | Framework preset (`nextjs`, `vite`, etc.; `null` for "Other") |
| `functions` | `object` | Serverless function config by glob pattern |
| `headers` | `array` | Custom response headers |
| `ignoreCommand` | `string` | Command to decide if build should be skipped |
| `images` | `object` | Image optimization config |
| `installCommand` | `string \| null` | Override install command |
| `outputDirectory` | `string` | Build output directory |
| `public` | `boolean` | Expose source view and logs |
| `redirects` | `array` | Redirect rules |
| `regions` | `array` | Serverless function regions |
| `functionFailoverRegion` | `string` | Failover region |
| `rewrites` | `array` | Rewrite rules |
| `trailingSlash` | `boolean` | Redirect to trailing-slash or non-trailing-slash |
| `git.deploymentEnabled` | `boolean` | Enable/disable auto-deploy on push |

### functions

```json
{
  "functions": {
    "api/heavy.js": { "memory": 3009, "maxDuration": 30 },
    "api/*.js": { "memory": 1024, "maxDuration": 10 }
  }
}
```

Properties: `memory` (128-3009 MB), `maxDuration` (seconds), `runtime` (npm package).

### crons

```json
{
  "crons": [
    { "path": "/api/cron/daily", "schedule": "0 8 * * *" }
  ]
}
```

Max path: 512 chars. Max schedule: 256 chars. Max per project: 100 (Hobby/Pro).

### redirects

```json
{
  "redirects": [
    { "source": "/old", "destination": "/new", "permanent": true },
    { "source": "/temp", "destination": "/new", "statusCode": 307 }
  ]
}
```

Properties: `source`, `destination`, `permanent` (308/307), `statusCode` (301/302/307/308), `has` (conditional), `missing`.

### rewrites

```json
{
  "rewrites": [
    { "source": "/api/:path*", "destination": "https://backend.example.com/:path*" }
  ]
}
```

### headers

```json
{
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        { "key": "X-Frame-Options", "value": "SAMEORIGIN" },
        { "key": "X-Content-Type-Options", "value": "nosniff" }
      ]
    }
  ]
}
```

### images

```json
{
  "images": {
    "sizes": [640, 750, 828, 1080, 1200],
    "domains": ["example.com"],
    "remotePatterns": [{ "protocol": "https", "hostname": "**.example.com" }],
    "minimumCacheTTL": 60,
    "formats": ["image/avif", "image/webp"]
  }
}
```

### Conditional matching (has/missing)

Available in redirects, rewrites, and headers:

```json
{
  "has": [
    { "type": "host", "value": "www.example.com" },
    { "type": "header", "key": "x-custom" },
    { "type": "query", "key": "page", "value": "(?P<page>.*)" },
    { "type": "cookie", "key": "session" }
  ]
}
```

Types: `host`, `header`, `query`, `cookie`.

---

## System Environment Variables

Automatically available when enabled in project settings:

| Variable | Available At | Description |
|----------|-------------|-------------|
| `VERCEL` | Build + Runtime | Always `1` |
| `CI` | Build | Always `1` |
| `VERCEL_ENV` | Build + Runtime | `production`, `preview`, or `development` |
| `VERCEL_TARGET_ENV` | Build + Runtime | Same as above, or custom env name |
| `VERCEL_URL` | Build + Runtime | Deployment URL (no `https://`) |
| `VERCEL_BRANCH_URL` | Build + Runtime | Git branch URL |
| `VERCEL_PROJECT_PRODUCTION_URL` | Build + Runtime | Shortest production domain |
| `VERCEL_REGION` | Runtime | Region ID (e.g., `cdg1`) |
| `VERCEL_DEPLOYMENT_ID` | Build + Runtime | Deployment ID |
| `VERCEL_GIT_PROVIDER` | Build + Runtime | `github`, `gitlab`, `bitbucket` |
| `VERCEL_GIT_REPO_SLUG` | Build + Runtime | Repository name |
| `VERCEL_GIT_REPO_OWNER` | Build + Runtime | Repository owner |
| `VERCEL_GIT_REPO_ID` | Build + Runtime | Repository ID |
| `VERCEL_GIT_COMMIT_REF` | Build + Runtime | Git branch |
| `VERCEL_GIT_COMMIT_SHA` | Build + Runtime | Commit SHA |
| `VERCEL_GIT_COMMIT_MESSAGE` | Build + Runtime | Commit message |
| `VERCEL_GIT_COMMIT_AUTHOR_LOGIN` | Build + Runtime | Commit author |
| `VERCEL_GIT_COMMIT_AUTHOR_NAME` | Build + Runtime | Commit author name |
| `VERCEL_GIT_PULL_REQUEST_ID` | Build + Runtime | PR number |

---

## Platform Limits (Key Numbers)

| Limit | Hobby | Pro | Enterprise |
|-------|-------|-----|-----------|
| Projects | 200 | Unlimited | Unlimited |
| Deploys/day | 100 | 6,000 | Custom |
| CLI deploys/week | 2,000 | 2,000 | 2,000 |
| Build timeout | 45 min | 45 min | 45 min |
| Static file upload | 100 MB | 1 GB | Custom |
| Concurrent builds | 1 | 12 | Custom |
| Disk size | 23 GB | 23-64 GB | Custom |
| Cron jobs/project | 100 | 100 | 100 |
| Routes/deployment | 2,048 | 2,048 | 2,048 |
| Function memory | 128-3,009 MB | 128-3,009 MB | Custom |
| Proxy request timeout | 120s | 120s | 120s |

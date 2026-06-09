# Vercel REST API Reference

Base URL: `https://api.vercel.com`

## Authentication

All requests require a Bearer token in the `Authorization` header:

```
Authorization: Bearer <TOKEN>
```

Create tokens at account settings > Tokens. Tokens have configurable expiration (1 day to 1 year) and team scope.

For team resources, append `?teamId=<TEAM_ID>` or `?slug=<TEAM_SLUG>` to any endpoint.

## Rate Limits

Communicated via response headers:

| Header | Description |
|--------|-------------|
| `X-RateLimit-Limit` | Max requests allowed in current window |
| `X-RateLimit-Remaining` | Requests remaining in current window |
| `X-RateLimit-Reset` | UTC epoch seconds when window resets |

Exceeding limits returns `429 Too Many Requests` with `{"error":{"code":"too_many_requests"}}`.

## Pagination

Responses with arrays use cursor-based pagination:

```json
{
  "pagination": {
    "count": 20,
    "next": 1555072968396,
    "prev": 1555413045188
  }
}
```

- Default limit: 20, max: 100. Set via `?limit=N`.
- Use `?until=<next>` for next page.

---

## Endpoint Categories (31 categories, 250+ endpoints)

| Category | Count | Description |
|----------|-------|-------------|
| Access-groups | 11 | Team/project access control groups |
| Aliases | 6 | Deployment URL aliases |
| Artifacts | 6 | Remote caching (Turborepo) artifacts |
| Authentication | 5 | Auth providers, OIDC |
| Billing | 2 | FOCUS billing charges and commitments |
| Bulk-redirects | 7 | Large-scale redirect management |
| Certs | 4 | SSL/TLS certificate management |
| Checks | 5 | Pre-deployment checks (v1) |
| Checks-v2 | 10 | Pre-deployment checks (v2) |
| Connect | 6 | OAuth integration |
| Deployments | 10 | Create, list, manage deployments |
| DNS | 4 | DNS record management |
| Domains | 6 | Domain assignment and management |
| Domains-registrar | 16 | Domain registration and transfer |
| Drains | 6 | Log drains to external services |
| Edge-cache | 4 | CDN/edge cache invalidation |
| Edge-config | 17 | Edge Config key-value store |
| Environment | 11 | Environment variable management |
| Feature-flags | 19 | Feature flag management |
| Integrations | 10 | Marketplace integration management |
| Logs | 1 | Runtime log retrieval |
| Marketplace | 23 | Marketplace app management |
| Project-members | 3 | Project-level member management |
| Projects | 27 | Project CRUD, settings, promotion |
| Rolling-release | 7 | Gradual deployment rollout |
| Sandboxes | 18 | Sandboxed dev environments |
| Security | 9 | Firewall rules, IP blocking, WAF |
| Static-ips | 1 | Static IP configuration |
| Teams | 14 | Team management and membership |
| User | 4 | User account management |
| Webhooks | 4 | Webhook subscriptions |

---

## Access Groups (11 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/v1/access-groups` | List access groups |
| POST | `/v1/access-groups` | Create access group |
| GET | `/v1/access-groups/{idOrName}` | Read access group |
| POST | `/v1/access-groups/{idOrName}` | Update access group |
| DELETE | `/v1/access-groups/{idOrName}` | Delete access group |
| GET | `/v1/access-groups/{idOrName}/members` | List members |
| GET | `/v1/access-groups/{idOrName}/projects` | List projects |
| POST | `/v1/access-groups/{id}/projects` | Add project |
| GET | `/v1/access-groups/{id}/projects/{projectId}` | Read project assignment |
| PATCH | `/v1/access-groups/{id}/projects/{projectId}` | Update project assignment |
| DELETE | `/v1/access-groups/{id}/projects/{projectId}` | Remove project |

## Aliases (6 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/v4/aliases` | List aliases |
| GET | `/v4/aliases/{idOrAlias}` | Get alias |
| DELETE | `/v2/aliases/{aliasId}` | Delete alias |
| POST | `/v2/deployments/{id}/aliases` | Assign alias to deployment |
| GET | `/v2/deployments/{id}/aliases` | List deployment aliases |
| PATCH | `/v4/aliases/{id}` | Update alias |

## Artifacts (6 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/v8/artifacts/status` | Get Remote Caching status |
| POST | `/v8/artifacts/events` | Record cache usage event |
| GET | `/v8/artifacts/{hash}` | Download cache artifact |
| PUT | `/v8/artifacts/{hash}` | Upload cache artifact |
| HEAD | `/v8/artifacts/{hash}` | Check artifact existence |
| POST | `/v8/artifacts` | Query artifact info |

## Authentication (5 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/v1/auth` | List auth providers |
| POST | `/v1/auth/login` | Login |
| POST | `/v1/auth/verify` | Verify login |
| GET | `/v1/auth/oidc/token` | Get OIDC token |
| GET | `/v1/auth/tokens` | List auth tokens |

## Billing (2 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/v1/billing/charges` | List FOCUS billing charges |
| GET | `/v1/billing/contract-commitments` | List contract commitments |

## Bulk Redirects (7 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| PUT | `/v1/bulk-redirects` | Stage new redirects |
| GET | `/v1/bulk-redirects` | List active redirects |
| GET | `/v1/bulk-redirects/versions` | List redirect versions |
| POST | `/v1/bulk-redirects/promote` | Promote staged version |
| POST | `/v1/bulk-redirects/restore` | Restore previous version |
| DELETE | `/v1/bulk-redirects/{id}` | Delete a redirect |
| GET | `/v1/bulk-redirects/staged` | List staged redirects |

## Certs (4 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/v4/certs` | List certificates |
| GET | `/v7/certs/{id}` | Get certificate |
| PUT | `/v7/certs` | Upload certificate |
| DELETE | `/v7/certs/{id}` | Remove certificate |

## Checks (5 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/v1/deployments/{deploymentId}/checks` | Create check |
| GET | `/v1/deployments/{deploymentId}/checks` | List checks |
| GET | `/v1/deployments/{deploymentId}/checks/{checkId}` | Get check |
| PATCH | `/v1/deployments/{deploymentId}/checks/{checkId}` | Update check |
| POST | `/v1/deployments/{deploymentId}/checks/{checkId}/rerequest` | Rerequest check |

## Checks-v2 (10 endpoints)

Enhanced checks with richer reporting and integration options. Endpoints follow similar patterns to v1 with additional configuration and result management.

## Connect (6 endpoints)

OAuth integration for connecting external services:

| Method | Path | Description |
|--------|------|-------------|
| GET | `/v1/connect/authorize` | Start OAuth flow |
| POST | `/v1/connect/token` | Exchange code for token |
| POST | `/v1/connect/refresh` | Refresh token |
| POST | `/v1/connect/revoke` | Revoke token |
| GET | `/v1/connect/userinfo` | Get user info |
| GET | `/v1/connect/.well-known/openid-configuration` | OIDC discovery |

## Deployments (10 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/v13/deployments` | Create deployment |
| GET | `/v6/deployments` | List deployments |
| GET | `/v13/deployments/{idOrUrl}` | Get deployment |
| DELETE | `/v13/deployments/{id}` | Delete deployment |
| POST | `/v2/deployments/{id}/files` | Upload deployment files |
| GET | `/v7/deployments/{id}/files` | List deployment files |
| GET | `/v7/deployments/{id}/files/{fileId}` | Get file content |
| GET | `/v3/deployments/{id}/events` | Get deployment events |
| POST | `/v10/deployments/{id}/cancel` | Cancel deployment |
| PATCH | `/v12/deployments/{id}` | Update deployment (promote) |

## DNS (4 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/v4/domains/{domain}/records` | List DNS records |
| POST | `/v2/domains/{domain}/records` | Create DNS record |
| PATCH | `/v1/domains/records/{recordId}` | Update DNS record |
| DELETE | `/v2/domains/{domain}/records/{recordId}` | Delete DNS record |

## Domains (6 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/v5/domains` | List domains |
| GET | `/v6/domains/{domain}` | Get domain info |
| POST | `/v5/domains` | Add domain |
| PATCH | `/v3/domains/{domain}` | Update domain |
| DELETE | `/v6/domains/{domain}` | Remove domain |
| POST | `/v4/domains/{domain}/verify` | Verify domain |

## Domains Registrar (16 endpoints)

Domain registration, transfer, and registrar operations. Includes:
- Domain availability check
- Domain purchase
- Transfer initiation and status
- Registrar configuration (nameservers, WHOIS)
- Domain renewal
- Contact management
- Auth code retrieval

## Drains (6 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/v1/log-drains` | Create configurable log drain |
| GET | `/v1/log-drains` | List log drains |
| GET | `/v1/log-drains/{id}` | Get log drain |
| DELETE | `/v1/log-drains/{id}` | Delete log drain |
| POST | `/v2/integrations/log-drains` | Create integration log drain |
| DELETE | `/v1/integrations/log-drains/{id}` | Delete integration log drain |

Log drain delivery formats: `json`, `ndjson`, `syslog`.
Sources: `build`, `edge`, `lambda`, `static`, `external`, `firewall`, `redirect`.

## Edge Cache (4 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/v1/edge-cache/purge` | Purge cache |
| POST | `/v1/edge-cache/invalidate` | Invalidate (stale revalidation) |
| POST | `/v1/edge-cache/delete` | Delete cache entries |
| GET | `/v1/edge-cache/status` | Get cache status |

## Edge Config (17 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/v1/edge-config` | List all Edge Configs |
| POST | `/v1/edge-config` | Create Edge Config |
| GET | `/v1/edge-config/{id}` | Get Edge Config |
| PUT | `/v1/edge-config/{id}` | Update Edge Config |
| DELETE | `/v1/edge-config/{id}` | Delete Edge Config |
| GET | `/v1/edge-config/{id}/items` | Get all items |
| PATCH | `/v1/edge-config/{id}/items` | Update items (upsert/delete) |
| GET | `/v1/edge-config/{id}/item/{key}` | Get single item |
| GET | `/v1/edge-config/{id}/schema` | Get schema |
| PUT | `/v1/edge-config/{id}/schema` | Set schema |
| PATCH | `/v1/edge-config/{id}/schema` | Update schema |
| DELETE | `/v1/edge-config/{id}/schema` | Delete schema |
| GET | `/v1/edge-config/{id}/tokens` | List tokens |
| POST | `/v1/edge-config/{id}/tokens` | Create token |
| DELETE | `/v1/edge-config/{id}/tokens` | Delete tokens |
| GET | `/v1/edge-config/{id}/tokens/{token}` | Get token metadata |
| GET | `/v1/edge-config/{id}/backups` | List backups |

## Environment Variables (11 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/v10/projects/{idOrName}/env` | List env vars |
| POST | `/v10/projects/{idOrName}/env` | Create env var |
| GET | `/v1/projects/{idOrName}/env/{envId}` | Get env var |
| PATCH | `/v10/projects/{idOrName}/env/{envId}` | Update env var |
| DELETE | `/v10/projects/{idOrName}/env/{envId}` | Delete env var |
| GET | `/v9/projects/{idOrName}/env` | Filter env vars |
| POST | `/v10/projects/{idOrName}/env/bulk` | Bulk create env vars |
| POST | `/v9/projects/{idOrName}/custom-environments` | Create custom environment |
| GET | `/v9/projects/{idOrName}/custom-environments` | List custom environments |
| PATCH | `/v9/projects/{idOrName}/custom-environments/{slug}` | Update custom environment |
| DELETE | `/v9/projects/{idOrName}/custom-environments/{slug}` | Delete custom environment |

Env var types: `plain`, `encrypted`, `sensitive`, `secret`.
Targets: `production`, `preview`, `development`, or custom environment slugs.

## Feature Flags (19 endpoints)

Comprehensive feature flag management including:
- CRUD operations for flags
- Flag state management (enable/disable/archive)
- Flag variants and overrides
- SDK key management (server/client keys per environment)
- Flag evaluation configuration
- Flag audit/history

## Integrations (10 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/v1/integrations` | List integrations |
| GET | `/v1/integrations/{id}` | Get integration |
| POST | `/v1/integrations/install` | Install integration |
| DELETE | `/v1/integrations/{id}` | Uninstall integration |
| GET | `/v1/integrations/{id}/configuration` | Get configuration |
| PUT | `/v1/integrations/{id}/configuration` | Update configuration |
| GET | `/v1/integrations/{id}/resources` | List resources |
| POST | `/v1/integrations/{id}/resources` | Create resource |
| DELETE | `/v1/integrations/{id}/resources/{resourceId}` | Delete resource |
| PATCH | `/v1/integrations/{id}/resources/{resourceId}` | Update resource |

## Logs (1 endpoint)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/v1/logs` | Query runtime logs |

Supports filtering by project, deployment, environment, level, status code, source, branch, and time range.

## Marketplace (23 endpoints)

Marketplace management for integration developers:
- App lifecycle (create, update, publish, unpublish)
- Billing and metering
- Provisioning callbacks
- Resource management
- Plan management
- Usage reporting

## Project Members (3 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/v1/projects/{idOrName}/members` | List project members |
| POST | `/v1/projects/{idOrName}/members` | Add member |
| DELETE | `/v1/projects/{idOrName}/members/{uid}` | Remove member |

## Projects (27 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/v9/projects` | List projects |
| POST | `/v10/projects` | Create project |
| GET | `/v9/projects/{idOrName}` | Get project |
| PATCH | `/v9/projects/{idOrName}` | Update project |
| DELETE | `/v9/projects/{idOrName}` | Delete project |
| POST | `/v9/projects/{idOrName}/link` | Link Git repo |
| DELETE | `/v9/projects/{idOrName}/link` | Unlink Git repo |
| PATCH | `/v9/projects/{idOrName}/promote/{deploymentId}` | Promote deployment |
| GET | `/v9/projects/{idOrName}/promote/aliases` | Get promotion aliases |
| POST | `/v9/projects/{idOrName}/domains` | Add domain to project |
| GET | `/v9/projects/{idOrName}/domains` | List project domains |
| DELETE | `/v9/projects/{idOrName}/domains/{domain}` | Remove domain |
| GET | `/v9/projects/{idOrName}/domains/{domain}` | Get domain config |
| PATCH | `/v9/projects/{idOrName}/domains/{domain}` | Update domain config |
| POST | `/v9/projects/{idOrName}/domains/{domain}/verify` | Verify domain |
| GET | `/v1/projects/{idOrName}/rolling-release/config` | Get rolling release config |
| PUT | `/v1/projects/{idOrName}/rolling-release/config` | Update rolling release config |
| GET | `/v6/projects/{idOrName}/system-env-values` | Get system env vars |
| POST | `/v1/projects` | Create project (v1) |
| GET | `/v1/projects/{idOrName}/pause` | Pause project |
| POST | `/v1/projects/{idOrName}/unpause` | Unpause project |

Plus additional endpoints for project settings, transfer, and inspection.

## Rolling Release (7 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/v1/projects/{id}/rolling-release/config` | Get config |
| PUT | `/v1/projects/{id}/rolling-release/config` | Update config |
| POST | `/v1/projects/{id}/rolling-release/start` | Start rolling release |
| POST | `/v1/projects/{id}/rolling-release/approve` | Approve stage |
| POST | `/v1/projects/{id}/rolling-release/complete` | Complete rollout |
| POST | `/v1/projects/{id}/rolling-release/abort` | Abort rollout |
| GET | `/v1/projects/{id}/rolling-release/status` | Get status |

Config structure:
```json
{
  "enabled": true,
  "advancementType": "automatic|manual-approval",
  "stages": [
    { "targetPercentage": 10, "duration": 300 },
    { "targetPercentage": 50, "duration": 600 },
    { "targetPercentage": 100 }
  ]
}
```

## Sandboxes (18 endpoints)

Isolated preview development environments. Supports:
- Sandbox lifecycle (create, start, stop, delete)
- Sandbox configuration
- Port forwarding
- File operations
- Terminal sessions
- Resource management

## Security / Firewall (9 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/v1/security/firewall/config` | Get firewall config |
| PUT | `/v1/security/firewall/config` | Update firewall config |
| GET | `/v1/security/firewall/rules` | List firewall rules |
| POST | `/v1/security/firewall/rules` | Create rule |
| PATCH | `/v1/security/firewall/rules/{id}` | Update rule |
| DELETE | `/v1/security/firewall/rules/{id}` | Delete rule |
| GET | `/v1/security/firewall/bypass` | List bypass rules |
| POST | `/v1/security/attack-challenge-mode` | Configure challenge mode |
| GET | `/v1/security/attack-challenge-mode` | Get challenge mode status |

WAF rule actions: `log`, `block`, `challenge`, `rate_limit`.
Managed rulesets include OWASP Top 10 protection.

## Static IPs (1 endpoint)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/v1/static-ips` | Get static IP configuration |

## Teams (14 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/v2/teams` | List teams |
| POST | `/v1/teams` | Create team |
| GET | `/v2/teams/{teamId}` | Get team |
| PATCH | `/v2/teams/{teamId}` | Update team |
| DELETE | `/v1/teams/{teamId}` | Delete team |
| GET | `/v2/teams/{teamId}/members` | List members |
| POST | `/v1/teams/{teamId}/members` | Invite member |
| PATCH | `/v2/teams/{teamId}/members/{uid}` | Update member role |
| DELETE | `/v1/teams/{teamId}/members/{uid}` | Remove member |
| POST | `/v1/teams/{teamId}/request` | Request to join |
| GET | `/v1/teams/{teamId}/request/{userId}` | Get join request |
| PATCH | `/v1/teams/{teamId}/request/{userId}` | Respond to request |
| GET | `/v2/teams/{teamId}/audit-log` | Get audit log |
| GET | `/v1/teams/{teamId}/members/{uid}/access-requests` | Get access requests |

Member roles: `ADMIN`, `USER`, `VIEWER`, `DEVELOPER`, `BILLING`, `NONE` (remove).

## User (4 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/v2/user` | Get authenticated user |
| PATCH | `/v2/user` | Update user |
| GET | `/v2/user/tokens` | List user tokens |
| DELETE | `/v2/user/tokens/{tokenId}` | Delete user token |

## Webhooks (4 endpoints)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/v1/webhooks` | List webhooks |
| POST | `/v1/webhooks` | Create webhook |
| GET | `/v1/webhooks/{id}` | Get webhook |
| DELETE | `/v1/webhooks/{id}` | Delete webhook |

Supported events:
- **Deployment**: `deployment.created`, `deployment.succeeded`, `deployment.ready`, `deployment.error`, `deployment.canceled`
- **Project**: `project.created`, `project.removed`, `project.domain-moved`
- **Environment**: `project.env.created`, `project.env.updated`, `project.env.deleted`
- **Alerts**: `anomaly.detected`, `alert.triggered`
- **Integration**: `integration-configuration.permission-upgraded`, `integration-configuration.scope-change-confirmed`
- **Member**: `project.member.role-change`

---

## Vercel SDK (@vercel/sdk)

Type-safe TypeScript SDK wrapping the REST API:

```bash
npm install @vercel/sdk
```

```typescript
import { Vercel } from '@vercel/sdk';

const vercel = new Vercel({
  bearerToken: process.env.VERCEL_TOKEN,
});

// Examples
const projects = await vercel.projects.getProjects({});
const deployment = await vercel.deployments.getDeployment({ idOrUrl: 'dpl_xxx' });
const envVars = await vercel.projects.filterProjectEnvs({ idOrName: 'my-project' });
await vercel.edgeConfig.createEdgeConfig({ requestBody: { slug: 'my-config' } });
```

SDK modules mirror API categories: `vercel.deployments`, `vercel.projects`, `vercel.edgeConfig`, `vercel.domains`, `vercel.dns`, `vercel.teams`, `vercel.user`, `vercel.environment`, etc.

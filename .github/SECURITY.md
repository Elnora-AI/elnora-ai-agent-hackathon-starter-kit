# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.x.x   | Yes       |

## Reporting a Vulnerability

**DO NOT open a public GitHub issue for security vulnerabilities.**

Please report security vulnerabilities via one of the following channels:

- **Email:** [security@elnora.ai](mailto:security@elnora.ai)
- **GitHub Security Advisories:** [Report a vulnerability](https://github.com/Elnora-AI/elnora-ai-agent-hackathon-starter-kit/security/advisories/new)

Include as much detail as possible:

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

## Response Timeline

- **Acknowledgement:** Within 48 hours of report
- **Initial assessment:** Within 5 business days
- **Fix and disclosure:** Within 90 days of report

## Responsible Disclosure

We follow a 90-day disclosure timeline. We ask that you:

- Allow us reasonable time to fix the issue before public disclosure
- Do not access or modify other users' data
- Do not perform actions that could negatively impact other users
- Act in good faith to avoid privacy violations, data destruction, and service disruption

## Scope

**In scope:**

- The `elnora-ai-agent-hackathon-starter-kit` CLI and plugin code in this repository
- Configuration handling (`references/*.json`, env var resolution, API-key storage)
- Signal sources implemented in this repo (currently only `external_command`; the other source types in `schemas/signal-sources.json` are declared but not yet implemented)

**Out of scope:**

- Third-party dependencies (please report to their respective maintainers)
- The Linear API itself (report to Linear)
- User-configured `external_command` entries — those execute commands the user has chosen to trust
- Social engineering attacks against Elnora staff
- Denial of service attacks
- Issues in services not operated by Elnora

## Security Best Practices for Users

- Never commit API keys or tokens to version control
- The plugin saves your Linear API key to `~/.config/elnora-ai-agent-hackathon-starter-kit/.env` with mode `0600` by default — verify this if you suspect tampering
- Rotate your Linear API key periodically via Linear's account settings
- When configuring `external_command` signal sources, only point at trusted local binaries

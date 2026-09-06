# Contributing

Thank you for considering a contribution.

## Before you start

For anything more than a typo, open an issue first and describe what you intend to change. It is
cheaper for both of us to disagree about an approach in an issue than in a finished pull request.

## Working on a change

1. Fork the repository and branch from `main`.
2. Name the branch for what it does: `feat/short-description`, `fix/short-description`,
   `docs/short-description`.
3. Keep the change to one purpose. A pull request that fixes a bug and also reformats four files is
   hard to review and harder to revert.
4. Match the surrounding code. Every file here already has a style; follow the file you are in rather
   than the style you prefer.
5. Run whatever the repository uses to build, lint and test before you open the pull request. Check
   the README for the commands, and if a check does not exist for what you changed, say so in the
   pull request rather than leaving the reviewer to guess.

## Commit messages

Conventional Commits: `type(scope): subject`. Types in use are `feat`, `fix`, `docs`, `refactor`,
`test`, `chore` and `security`. Write the subject as what the change does, not what you did.

## Pull requests

Explain what changes and why. If the reasoning is not obvious from the diff, the pull request body is
where it belongs, because that is what someone reads in a year when deciding whether the change can
be reverted.

State what you actually ran. "Builds and tests pass" is only useful when it is true and specific.

## Never commit

Credentials of any kind: API keys, tokens, OAuth client secrets, private keys, `.env` files, exported
credential JSON. This is enforced by a secret scan on every push and pull request, and by GitHub push
protection, but neither is a substitute for checking your own diff.

Nor customer names, account identifiers, internal hostnames, or anything else that identifies a
specific organisation. Use `example.com` and obvious placeholders.

If you believe a secret has already been committed, do not open a pull request removing it. Follow
[SECURITY.md](./SECURITY.md) instead, because the value is in the history and needs rotating rather
than deleting.

## Reporting a security problem

Do not open an issue. See [SECURITY.md](./SECURITY.md).

## Licence

Contributions are accepted under the licence in [LICENSE](../LICENSE).

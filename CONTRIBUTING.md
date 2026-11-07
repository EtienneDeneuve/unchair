# Contributing to Unchair

Unchair is intentionally small. Keep changes the same way.

## Start with an issue

Non-trivial behavior starts from a GitHub issue or written specification.

Before coding:

1. read the issue and acceptance criteria;
2. identify affected domain/privacy invariants;
3. add or update the test that describes the behavior;
4. make the smallest coherent implementation;
5. run the relevant tests and then the full suite.

See [agent.md](./agent.md) for the engineering contract.

## Tests

```bash
xcodebuild test \
  -scheme Unchair \
  -destination 'platform=macOS'
```

PR CI runs the same suite with ad-hoc signing.

Bug fixes require a regression test.

Hardware-specific behavior that cannot be exercised in CI must be tested around a deterministic boundary and clearly marked for manual verification.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/):

```text
<type>(optional-scope): <summary>
```

Common types:

| Type | Use |
|---|---|
| `feat` | user-visible capability |
| `fix` | bug fix |
| `docs` | documentation |
| `test` | tests |
| `refactor` | behavior-preserving change |
| `chore` | tooling / release plumbing |
| `ci` | GitHub Actions |

Prefer one logical change per PR.

## Changelog

Update [CHANGELOG.md](./CHANGELOG.md) for user-visible changes.

- development work goes under `[Unreleased]`;
- releases move entries into `[X.Y.Z] — YYYY-MM-DD`;
- `scripts/release.sh` uses that section for GitHub Release notes.

## Releases

Public releases are signed and notarized.

See:

- [docs/DISTRIBUTION.md](./docs/DISTRIBUTION.md)
- [docs/RELEASE.md](./docs/RELEASE.md)

Signing material never belongs in the repository or PR CI.

## Product boundaries

Do not weaken these to make a feature easier:

- a Mac alone must remain a complete product;
- network failure cannot break the core loop;
- remote integrations cannot mark movement complete;
- camera frames and body-landmark streams are never persisted or transmitted;
- optional integrations remain adapters, not domain dependencies.

If two designs satisfy the specification, choose the one that is easier to delete.

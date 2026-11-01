# Contributing to Unchair

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/):

```text
<type>(optional-scope): <summary>

[optional body]

Fixes #<issue>
```

Common types:

| Type | When |
|---|---|
| `feat` | user-visible capability |
| `fix` | bug fix |
| `docs` | documentation only |
| `test` | tests only |
| `refactor` | no behavior change |
| `chore` | tooling, version bumps, release plumbing |
| `ci` | GitHub Actions / CI |

Examples:

- `feat(mqtt): accept safe Home Assistant commands`
- `docs: add CHANGELOG entry for 0.2.1`
- `chore: bump marketing version to 0.2.1`

Prefer one logical change per commit. PR titles can match the primary commit.

## Changelog

Update [`CHANGELOG.md`](./CHANGELOG.md) in the same PR when the change is user-visible.

- Land work under `## [Unreleased]` while developing
- On release, move that section to `## [X.Y.Z] — YYYY-MM-DD` and bump `MARKETING_VERSION` in `project.yml`
- `scripts/release.sh` pulls the matching CHANGELOG section into the GitHub Release notes

## Releases

See [`docs/RELEASE.md`](./docs/RELEASE.md). Signed + notarized builds are local-only (`./scripts/release.sh X.Y.Z`).

## Tests

```bash
xcodebuild test -scheme Unchair -destination 'platform=macOS'
```

PR CI runs the same suite with ad-hoc signing.

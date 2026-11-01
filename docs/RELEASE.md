# Unchair release process

Public releases must be **reproducible**, **Developer ID signed**, and **notarized**.

Signing credentials are **never** committed. PR CI only builds/tests with ad-hoc signing.

## Versioning

- Marketing version: `MARKETING_VERSION` in `project.yml` (SemVer `MAJOR.MINOR.PATCH`)
- Git tag: `vMAJOR.MINOR.PATCH` (example: `v0.1.0`)
- GitHub Release title: `Unchair MAJOR.MINOR.PATCH`
- Artifact: `Unchair-MAJOR.MINOR.PATCH-macos.zip` (+ `.sha256`)

Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml`, regenerate with `xcodegen generate` when needed, then tag.

## What CI does (every PR / main)

Workflow: [`.github/workflows/ci.yml`](../.github/workflows/ci.yml)

- `macos-15` runner
- `xcodebuild test -scheme Unchair`
- `CODE_SIGN_IDENTITY="-"` (ad-hoc only)

No Developer ID certs, no App Store Connect keys, no notary profiles in CI.

## Manual signed + notarized release (current path)

Reuse the same keychain notary profile as Omnivya Setup (`omnivya`).

Prerequisites on the release Mac:

1. Developer ID Application identity for team `H3QDKGAJ35`
2. Notary credentials stored once:

```bash
xcrun notarytool store-credentials omnivya \
  --apple-id "…" \
  --team-id H3QDKGAJ35 \
  --password "app-specific-password"
```

(or the App Store Connect API key variant already used for Omnivya)

### One-shot script

```bash
./scripts/release.sh 0.1.1
# or: VERSION=0.1.1 NOTARY_PROFILE=omnivya ./scripts/release.sh
```

The script:

1. Builds Release with Developer ID + timestamp + hardened runtime
2. Sets `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` (required — `get-task-allow` fails notarization)
3. Zips the `.app`, submits with `notarytool --keychain-profile omnivya --wait`
4. Staples the `.app`
5. Verifies with `spctl -a -vv`
6. Creates `gh release create vX.Y.Z` with zip + sha256

### Manual commands (if you prefer)

```bash
IDENTITY='Developer ID Application: ETIENNE CHARLES EDOUARD DENEUVE (H3QDKGAJ35)'
TEAM=H3QDKGAJ35
VERSION=0.1.1

xcodebuild -scheme Unchair -configuration Release \
  -derivedDataPath /tmp/UnchairRelease \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM" \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO

APP=/tmp/UnchairRelease/Build/Products/Release/Unchair.app
ditto -c -k --keepParent "$APP" /tmp/Unchair-notarize.zip
xcrun notarytool submit /tmp/Unchair-notarize.zip --keychain-profile omnivya --wait
xcrun stapler staple "$APP"
spctl -a -vv "$APP"

ditto -c -k --keepParent "$APP" "/tmp/Unchair-${VERSION}-macos.zip"
shasum -a 256 "/tmp/Unchair-${VERSION}-macos.zip" | tee "/tmp/Unchair-${VERSION}-macos.zip.sha256"

gh release create "v${VERSION}" \
  "/tmp/Unchair-${VERSION}-macos.zip" \
  "/tmp/Unchair-${VERSION}-macos.zip.sha256" \
  --title "Unchair ${VERSION}" \
  --notes-file -   # or --generate-notes
```

## Secrets boundary

| Secret / material | Where it lives | Used by |
| --- | --- | --- |
| Developer ID cert + private key | Release Mac keychain / Apple developer account | Local `scripts/release.sh` only |
| Notary profile `omnivya` | Keychain via `notarytool store-credentials` | Local release only |
| GitHub token | `gh` auth on release Mac | `gh release create` |

**Never** put signing certs, notary passwords, or API keys in the repo, PR CI, or issue comments.

If/when GitHub Actions publishes notarized builds, use a **separate** `release` workflow triggered only on tags, with environment protection and secrets scoped to that job — not the PR `CI` workflow.

## Gatekeeper checklist

After staple:

```bash
spctl -a -vv Unchair.app
# expected: accepted / source=Notarized Developer ID
codesign -d --entitlements :- Unchair.app
# must NOT contain com.apple.security.get-task-allow
```

## Related

- Privacy contract: [`docs/PRIVACY.md`](./PRIVACY.md)
- Omnivya Setup packaging (same team / notary profile): `mdm-setup/apps/omnivya-setup/scripts/package.sh`

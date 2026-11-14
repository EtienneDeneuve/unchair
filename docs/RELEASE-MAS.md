# Mac App Store release pipeline (#139)

Companions: [`DISTRIBUTION.md`](./DISTRIBUTION.md) · [`mas-sandbox.md`](./mas-sandbox.md) · [`RELEASE.md`](./RELEASE.md) (Direct)

This is the **signed archive / export / upload** path for `Unchair-MAS`.
It does **not** replace TestFlight acceptance (#140) or Store listing (#141).

## Targets

| Scheme | Target | Sparkle | Config |
| --- | --- | --- | --- |
| `Unchair` | `Unchair` | linked | Debug / Release (`DIRECT`) |
| `Unchair-MAS` | `UnchairAppStore` | **not linked** | AppStore (`APPSTORE`) |

CI on every PR still builds an **unsigned** AppStore configuration (compile gate only).
Signed archive + ASC upload use the release Mac or the protected GitHub Environment `mas-release`.

## One-shot (release Mac)

Prerequisites:

1. Apple Distribution certificate for team `H3QDKGAJ35` in the login keychain  
   (`security find-identity -v -p codesigning` should list `Apple Distribution: …`)
2. App record in App Store Connect for `com.etiennedeneuve.unchair` (#141 may still be WIP)
3. Optional ASC API key (Issuer ID + Key ID + `.p8`) for validate/upload

```bash
# Archive + export .pkg only (safe default — no ASC mutation)
./scripts/release-mas.sh 1.0.0

# Archive + export + upload via exportOptions destination=upload
UPLOAD=1 \
  ASC_API_KEY_ID=… \
  ASC_API_ISSUER_ID=… \
  ASC_API_KEY_PATH=$HOME/AuthKey_….p8 \
  ./scripts/release-mas.sh 1.0.0
```

Manual upload step when `UPLOAD=0`:

1. Open the exported `.pkg` in **Transporter**
2. Deliver to App Store Connect
3. Paste What’s New from `/tmp/UnchairMAS-<ver>/whats-new.txt` (from `CHANGELOG.md`)

**Failure rule:** if archive or export fails, the script exits non-zero and appends `FAILED` to `release-state.txt`. Never treat a partial run as shipped.

## Version / build uniqueness

- `MARKETING_VERSION` in `project.yml` must equal the script argument
- `CHANGELOG.md` must contain `## [X.Y.Z]`
- `CURRENT_PROJECT_VERSION` must be **new** for every ASC upload of that marketing version  
  Bump it in `project.yml` before re-uploading; ASC rejects colliding build numbers

## GitHub Actions

Workflow: [`.github/workflows/release-mas.yml`](../.github/workflows/release-mas.yml)

| Job | When | Signing |
| --- | --- | --- |
| `unsigned-gate` | `workflow_dispatch` | ad-hoc (always) |
| `signed-release` | `workflow_dispatch` + env `mas-release` | Apple Distribution via secrets |

### Environment `mas-release` secrets

Create the environment in repo Settings → Environments → `mas-release` (required reviewers recommended).

| Secret | Purpose |
| --- | --- |
| `ASC_API_KEY_ID` | App Store Connect API Key ID |
| `ASC_API_ISSUER_ID` | Issuer UUID |
| `ASC_API_KEY_P8` | Full `.p8` PEM contents |
| `APPLE_DISTRIBUTION_CERT_P12_BASE64` | Base64 of Apple Distribution `.p12` |
| `APPLE_DISTRIBUTION_CERT_PASSWORD` | `.p12` password |
| `KEYCHAIN_PASSWORD` | Temporary CI keychain password |

No signing material is committed. If secrets are missing, `signed-release` **fails closed** with an explicit message (does not report success).

## Local CI parity

```bash
xcodegen generate
xcodebuild build -scheme Unchair-MAS -configuration AppStore \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=NO
# Expect: no Sparkle.framework under Contents/Frameworks
```

## What’s New

Always sourced from `CHANGELOG.md` `## [X.Y.Z]` — same text as Direct GitHub Releases.

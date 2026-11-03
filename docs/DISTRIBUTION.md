# Distribution channels

Unchair ships on **two channels** that share one codebase, one `CHANGELOG.md`, and
the same SemVer (`MARKETING_VERSION`). Update mechanics differ.

```text
                    ┌─────────────────────┐
                    │   main + CHANGELOG  │
                    └─────────┬───────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
     scheme Unchair                    scheme Unchair-MAS
     config Release                    config AppStore
     flag DIRECT                       flag APPSTORE
     entitlements: camera              entitlements: sandbox + camera + network.client
              │                               │
              ▼                               ▼
     Developer ID + notarize           Apple Distribution + Transporter / ASC
     GitHub Release zip                Mac App Store
              │                               │
              ▼                               ▼
     Sparkle (planned)                 App Store updates only
     + manual download                 (no Sparkle)
```

## Direct (GitHub) — default

- Scheme: `Unchair` / configuration `Release`
- Compile flag: `DIRECT` (absence of `APPSTORE`)
- Script: [`scripts/release.sh`](../scripts/release.sh)
- Primary install artifact: **`Unchair-X.Y.Z-macos.dmg`**
  - Styled Finder window: app + **Applications** alias (drag to install)
  - Built by [`scripts/package-dmg.sh`](../scripts/package-dmg.sh)
  - Background: [`docs/assets/dmg/background.png`](./assets/dmg/background.png)
    (`scripts/generate-dmg-background.py`)
  - DMG is notarized + stapled (in addition to the app)
- Also attached: `Unchair-X.Y.Z-macos.zip` (+ `.sha256`) for automation / Sparkle
- In-app updates: Sparkle 2 (EdDSA + appcast) — scaffolding in
  `Unchair/Distribution/`; wire package + keys before enabling silent checks
- Feed URL (planned): hosted next to releases, e.g.
  `https://github.com/EtienneDeneuve/unchair/releases/latest/download/appcast.xml`

### Sparkle checklist (before first auto-update release)

1. `generate_keys` → store **private** key in release Mac keychain / CI secret (never commit)
2. Embed **public** EdDSA key in Info.plist (`SUPublicEDKey`) for Direct configs only
3. Extend `release.sh` to run `sign_update` and attach `appcast.xml`
4. Swap `DirectUpdateController` to `SPUStandardUpdaterController`
5. Document network contact in [`PRIVACY.md`](./PRIVACY.md)

## Mac App Store — `Unchair-MAS`

- Scheme: `Unchair-MAS` / configuration `AppStore`
- Compile flag: `APPSTORE`
- Entitlements: [`Unchair/Unchair-MAS.entitlements`](../Unchair/Unchair-MAS.entitlements) (App Sandbox)
- **No Sparkle**, no zip self-replace
- Script stub: [`scripts/release-mas.sh`](../scripts/release-mas.sh)
- CI workflow stub: [`.github/workflows/release-mas.yml`](../.github/workflows/release-mas.yml)
  (manual `workflow_dispatch` until ASC API key + certs are in GitHub Environments)

### Shared release notes

Both channels publish the same SemVer. GitHub Release body and ASC “What’s New”
are generated from the matching `## [X.Y.Z]` section in `CHANGELOG.md` (same
approach as `release.sh` today).

### Bundle ID

Default: keep `com.etiennedeneuve.unchair` for both while validating MAS.
If Keychain / sandbox migration becomes painful, introduce
`com.etiennedeneuve.unchair.mas` and document a one-shot settings migrate.

## Local verification

```bash
xcodegen generate

# Direct (default CI path)
xcodebuild build -scheme Unchair -configuration Release -destination 'platform=macOS'

# MAS compile gate (no ASC upload)
xcodebuild build -scheme Unchair-MAS -configuration AppStore -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Manual
```

Confirm flags:

```bash
# Direct binary should not define APPSTORE
nm -a ... # or: strings Unchair.app/Contents/Info.plist | head
```

In Settings → About, the channel label should read **Direct (GitHub)** or
**Mac App Store** accordingly.

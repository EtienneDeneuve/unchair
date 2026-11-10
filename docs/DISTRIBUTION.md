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
     GitHub Release DMG + zip          Mac App Store
              │                               │
              ▼                               ▼
     Sparkle 2 (EdDSA appcast)         App Store updates only
                                       (no Sparkle)
```

## Direct (GitHub) — default

- Scheme: `Unchair` / configuration `Release`
- Compile flag: `DIRECT` (absence of `APPSTORE`)
- Script: [`scripts/release.sh`](../scripts/release.sh)
- Primary install artifact: **`Unchair-X.Y.Z-macos.dmg`**
  - Styled Finder window: app + **Applications** alias (drag to install)
  - Built by [`scripts/package-dmg.sh`](../scripts/package-dmg.sh)
  - Background: [`docs/assets/dmg/background.png`](./assets/dmg/background.png)
  - DMG is notarized + stapled (in addition to the app)
- Also attached: `Unchair-X.Y.Z-macos.zip` (+ `.sha256`) — **Sparkle enclosure**
- `appcast.xml` attached to the release (and addressable as
  `…/releases/latest/download/appcast.xml`)
- In-app updates: Sparkle 2 via `DirectUpdateController` / `SPUStandardUpdaterController`
- Info.plist (Direct configs): `SUFeedURL`, `SUPublicEDKey`, `SUEnableAutomaticChecks`
- Homebrew **cask** (optional install path): [`Casks/unchair.rb`](../Casks/unchair.rb)
  - Points at the same notarized DMG on GitHub Releases
  - `auto_updates true` — Sparkle remains the in-app updater; `brew upgrade --cask` is optional
  - Bump helper: [`scripts/bump-homebrew-cask.sh`](../scripts/bump-homebrew-cask.sh) (also invoked by `release.sh`)

```bash
brew tap EtienneDeneuve/unchair
brew trust etiennedeneuve/unchair   # Homebrew 7+ third-party taps
brew install --cask unchair
```

Tap repo: [`EtienneDeneuve/homebrew-unchair`](https://github.com/EtienneDeneuve/homebrew-unchair) (mirrors [`Casks/unchair.rb`](../Casks/unchair.rb) from this repo).

### Dependency vigilance + SLSA

- Dependabot daily: [`.github/dependabot.yml`](../.github/dependabot.yml) (`github-actions` + `swift`)
- Sparkle pin: SPM via `project.yml` + committed [`Package.resolved`](../Unchair.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved)
- Post-publish SLSA asset attestation (does **not** claim CI built the app): [`docs/SLSA.md`](./SLSA.md)
- After each Direct release, run the public communication checklist: [`release-communication-checklist.md`](./release-communication-checklist.md)
- Before cutting **1.0**, dry-run the distribution quality gate: [`distribution-quality-gate.md`](./distribution-quality-gate.md) (#115)

### Sparkle keys (one-time per signing Mac)

```bash
# From a Sparkle release tarball (bin/):
./bin/generate_keys          # stores private key in login keychain
./bin/generate_keys -p       # prints SUPublicEDKey for project.yml
./bin/generate_keys -x unchair-sparkle-ed25519-private.pem   # offline backup — never commit
```

`release.sh` calls `sign_update` on the zip (looks in `.sparkle/bin`,
`/tmp/sparkle-tools/bin`, or Xcode DerivedData). Keep the private key safe — losing it
breaks the signature chain for existing installs (Sparkle key rotation is possible
but painful).

The app links Sparkle via SwiftPM (`packages.Sparkle` in `project.yml`, currently
resolved to 2.10.1). Tools (`generate_keys`, `sign_update`) live outside the app
bundle — download a [Sparkle release tarball](https://github.com/sparkle-project/Sparkle/releases)
and point `SIGN_UPDATE` / `.sparkle/bin` at its `bin/` directory.

`release.sh` re-signs Sparkle’s nested helpers (`Autoupdate`, `Updater.app`, XPCs) with
the Developer ID identity + secure timestamp before notarization — the stock framework
ships ad-hoc signed, which Apple rejects.

## Mac App Store — `Unchair-MAS`

- Scheme: `Unchair-MAS` / configuration `AppStore`
- Compile flag: `APPSTORE`
- Entitlements: [`Unchair/Unchair-MAS.entitlements`](../Unchair/Unchair-MAS.entitlements)
- **No Sparkle updater code** (`#if !APPSTORE`); do not ship a Sparkle feed in MAS Info.plist
- Script stub: [`scripts/release-mas.sh`](../scripts/release-mas.sh)

### Shared release notes

Both channels publish the same SemVer. GitHub Release body and ASC “What’s New”
are generated from the matching `## [X.Y.Z]` section in `CHANGELOG.md`.

## Local verification

```bash
xcodegen generate
xcodebuild build -scheme Unchair -configuration Release -destination 'platform=macOS'
```

Confirm Direct Info.plist carries `SUPublicEDKey` / `SUFeedURL`, and Settings → About
shows channel **Direct (GitHub)**.

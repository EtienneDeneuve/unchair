# Distribution quality gate — 1.0 release train

Issue: #115  
Companions: [DISTRIBUTION.md](./DISTRIBUTION.md) · [RELEASE.md](./RELEASE.md) · [release-communication-checklist.md](./release-communication-checklist.md) · [SLSA.md](./SLSA.md)

Goal: make the 1.0 Direct path boring — **sign, notarize, Sparkle, Homebrew, and public docs all agree** before the tag.

App Store submission is out of scope for this gate.

## Executable guards

`DistributionQualityGateTests` asserts on every CI run:

| Check | Intent |
| --- | --- |
| `project.yml` `MARKETING_VERSION` == `Casks/unchair.rb` `version` | No cask/app SemVer drift |
| `CHANGELOG.md` has `## [X.Y.Z]` for that version | Release notes source exists before tag |
| Cask URL uses GitHub Releases DMG pattern | Homebrew installs the notarized DMG |
| Direct `Info.plist` has `SUFeedURL` + `SUPublicEDKey` | Sparkle feed wired |
| `Info-AppStore.plist` has no Sparkle keys | MAS channel stays clean |
| `scripts/release.sh` notarizes, staples, runs `spctl`, builds appcast | Release path documented in code |
| README + DISTRIBUTION + RELEASE + communication checklist cross-link | Public docs stay findable |

## Operator dry-run (1.0 candidate)

Copy into the 1.0 release PR / issue and tick. Do **not** claim CI notarized the binary.

```text
Candidate: v1.0.0
Date (UTC):
Operator:

### Bits
[ ] MARKETING_VERSION / CURRENT_PROJECT_VERSION bumped for 1.0.0
[ ] CHANGELOG ## [1.0.0] filled (release notes draft — not empty Unreleased leftovers)
[ ] ./scripts/release.sh 1.0.0 completed (or dry-run rehearsal on a previous patch first)
[ ] GitHub Release assets: DMG + latest alias + zip + sha256 + appcast.xml

### Clean Mac install
[ ] DMG: open → drag to Applications → launch → menu bar icon
[ ] Homebrew: brew install --cask EtienneDeneuve/unchair/unchair → launch
[ ] About shows 1.0.0 + Direct (GitHub)
[ ] spctl -a -vv /Applications/Unchair.app → accepted / Notarized Developer ID
[ ] codesign entitlements: get-task-allow count == 0
[ ] shasum -a 256 -c Unchair-1.0.0-macos.dmg.sha256

### Sparkle
[ ] Existing Direct install (≤ previous SemVer) Check for Updates… finds 1.0.0
[ ] OR staged feed verified against the published zip + appcast signature
[ ] SUFeedURL still …/releases/latest/download/appcast.xml

### Public copy
[ ] README download + Homebrew instructions resolve
[ ] Product / compare pages do not claim unreleased companions
[ ] Known limitations listed in the GitHub Release body (see below)
[ ] release-communication-checklist.md fully run
```

### Known limitations (honest — for 1.0 Direct)

Ship only what is true:

- macOS 14+ only
- Camera optional for reminders; required only for movement verification
- MQTT / OpenMetrics / tracing optional; dead broker must not break the core loop
- Human Runtime card is local-history only — never auto-posted
- Direct channel uses Sparkle; MAS builds (if any) do not
- CI does not Developer ID–sign or notarize (see SLSA.md)
- PresentationGuard may miss Slack huddles until Core Audio detection lands — see [`known-issues.md`](./known-issues.md) (#134 / #135)

## Release notes draft (before tag)

Keep the draft in `CHANGELOG.md` under `## [Unreleased]` until cut, then rename to `## [1.0.0] — YYYY-MM-DD`.

Minimum structure for 1.0.0:

```markdown
## [1.0.0] — YYYY-MM-DD

### Added
- …

### Changed
- …

### Fixed
- …

### Distribution
- Direct: Developer ID + notarized DMG/zip + Sparkle appcast + Homebrew cask
```

`release.sh` lifts this section into the GitHub Release body — draft it **before** tagging.

## Relationship to #116

This gate proves the **train** is ready. #116 is the exit decision to cut `v1.0.0` once #108 children are done and this dry-run is green.

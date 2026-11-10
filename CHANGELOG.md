# Changelog

All notable changes to Unchair are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows SemVer (`MARKETING_VERSION`).

## [Unreleased]

### Added
- Public release communication checklist (`docs/release-communication-checklist.md`) — #86
- Honest Unchair vs Stretchly vs Time Out comparison (site FR/EN + `docs/compare-stretchly-timeout.md`) — #97
- Independent-mentions posting kit (`docs/independent-mentions.md`) — #98

## [0.4.0] — 2026-11-10

### Added
- Privacy-safe **Human Runtime** weekly card in Today — local history only, Copy Image / Save PNG with Unchair branding (#85)
- Repo discoverability metadata (description, topics, homepage, social preview) (#83)
- Daily Dependabot for GitHub Actions + SwiftPM (`swift` ecosystem)
- Post-publish SLSA asset attestation (digests only — CI still does not sign binaries)
- `./scripts/test.sh` for local ad-hoc build/test (same signing as CI)

### Changed
- Today rebuilt as a compact native status dashboard (hero → next break → Today → Human Runtime → export)
- Sparkle is an SPM dependency (pinned in `Package.resolved`, currently 2.10.1) instead of a vendored `Vendor/Sparkle.framework`

### Fixed
- `unchair` prints real help on stdout for `help` / `-h` / `--help` / no args (bad usage now exits 2)
- MQTT Keychain ACL prompts no longer fire under XCTest / ad-hoc test host

## [0.3.4] — 2026-11-04

### Added
- Optional OpenMetrics/Prometheus scrape endpoint (localhost by default) — Fixes #22
- Optional break-lifecycle tracing adapter (no-op exporter by default) — Fixes #23
- Grafana Human Runtime dashboard example — Fixes #24
- `unchair` CLI (`status` / `debt` / `break start` / `postpone` / `presentation` / `history today` / `doctor`) — Fixes #33

## [0.3.3] — 2026-11-03

### Added
- Menu bar **About Unchair** opens Settings on the About pane

### Fixed
- `release.sh` publishes `appcast.xml` (Sparkle `SUFeedURL`) alongside the versioned appcast copy

## [0.3.2] — 2026-11-03

### Added
- Home Assistant escalation policy examples (`break_due` +0/+3/+5/+7/+10m + reset) — Fixes #25

## [0.3.1] — 2026-11-03

### Added
- Sparkle 2 in-app updates on the Direct channel (EdDSA-signed `appcast.xml` + zip enclosure)
- Opaque full-bleed AppIcon + bundled `AppIcon.icns` so Finder/Dock show the Unchair mark reliably

### Changed
- Settings rebuilt as a System Settings–style sidebar (General / Camera / Integrations / About)
- **Check for Updates…** now runs Sparkle instead of only opening GitHub

## [0.3.0] — 2026-11-03

### Added
- Dual distribution scaffolding (`DIRECT` / `APPSTORE`): channel types, update controller seam, MAS entitlements, [docs/DISTRIBUTION.md](./docs/DISTRIBUTION.md)
- Styled GitHub release DMG (drag Unchair → Applications) via `scripts/package-dmg.sh` + notarized in `release.sh`
- Real macOS AppIcon for Dock, Finder and the DMG
- Settings → About: version, channel and project links
- Menu **Check for Updates…** on direct builds

## [0.2.3] — 2026-11-03

### Fixed
- Idle CPU: cache AVCapture / running-apps presentation probes, avoid re-evaluating the scheduler on every menu-bar SwiftUI read, and reduce MQTT liveness polling

## [0.2.2] — 2026-11-02

### Fixed
- Sitting counter and work deadline freeze while the Mac is locked or asleep

### Added
- HID idle freeze: after a configurable period without keyboard/mouse activity, desk clocks pause even if the Mac stays unlocked

## [0.2.1] — 2026-11-01

### Fixed
- PresentationGuard TTL cache removed after CI flake; keep failed-open posture verification path stable

## [0.2.0] — 2026-11-01

### Added
- Optional MQTT / Home Assistant discovery + command topics (#17, #18, #19)
- Home Assistant setup guide, Mosquitto ACL / Lovelace / automation examples, disposable broker smoke harness and MQTT privacy notes
- Anonymized README screenshots + product-tour GIF

## [0.1.0] — 2026-10-31

### Added
- Menu-bar sit/stand break coach with Vision movement verification
- Explicit break lifecycle state machine (#7)
- Presentation Mode / PresentationGuard (#13)
- Local break history (#8) + Today dashboard (#9)
- Launch at login via `SMAppService` (#11)
- Privacy model documentation (#10)

[0.3.4]: https://github.com/EtienneDeneuve/unchair/releases/tag/v0.3.4
[0.3.3]: https://github.com/EtienneDeneuve/unchair/releases/tag/v0.3.3
[0.3.2]: https://github.com/EtienneDeneuve/unchair/releases/tag/v0.3.2
[0.3.1]: https://github.com/EtienneDeneuve/unchair/releases/tag/v0.3.1
[0.3.0]: https://github.com/EtienneDeneuve/unchair/releases/tag/v0.3.0
[0.2.3]: https://github.com/EtienneDeneuve/unchair/releases/tag/v0.2.3
[0.2.2]: https://github.com/EtienneDeneuve/unchair/releases/tag/v0.2.2
[0.2.1]: https://github.com/EtienneDeneuve/unchair/releases/tag/v0.2.1
[0.2.0]: https://github.com/EtienneDeneuve/unchair/releases/tag/v0.2.0
[0.1.0]: https://github.com/EtienneDeneuve/unchair/releases/tag/v0.1.0

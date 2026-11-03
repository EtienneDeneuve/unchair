# Changelog

All notable changes to Unchair are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows SemVer (`MARKETING_VERSION`).

## [Unreleased]

## [0.3.0] — 2026-11-03

### Added
- Dual distribution scaffolding (`DIRECT` / `APPSTORE`): channel types, update controller seam, MAS entitlements, [`docs/DISTRIBUTION.md`](./docs/DISTRIBUTION.md)
- Styled GitHub release DMG (drag Unchair → Applications) via `scripts/package-dmg.sh` + notarized in `release.sh`
- Real macOS AppIcon (standing figure / empty chair) for Dock, Finder, and the DMG
- Settings → About: version, channel, UTM-tagged links to [etienne.deneuve.xyz](https://etienne.deneuve.xyz/?utm_source=unchair&utm_medium=app&utm_campaign=about) and [Omnivya](https://www.omnivya.fr/?utm_source=unchair&utm_medium=app&utm_campaign=about), plus a short “beyond desk health” note
- Menu **Check for Updates…** on direct builds (opens the latest GitHub release until Sparkle ships)

## [0.2.3] — 2026-11-03

### Fixed
- Idle CPU: cache AVCapture / running-apps presentation probes, keep lock/sleep freeze off that scan, avoid re-evaluating the scheduler on every menu-bar SwiftUI read; MQTT liveness poll slowed to 1s

## [0.2.2] — 2026-11-02

### Fixed
- Sitting counter and work deadline now freeze while the Mac is locked or asleep (same policy as movement debt); screen wake no longer clears lock latch

### Added
- HID idle freeze: after 5 minutes without keyboard/mouse (configurable in Settings, 0 = off), desk clocks pause even if the Mac stays unlocked

## [0.2.1] — 2026-11-01

### Fixed
- PresentationGuard TTL cache removed after CI flake; keep failed-open posture verification path stable

## [0.2.0] — 2026-11-01

### Added
- Optional MQTT / Home Assistant discovery + command topics (#17, #18, #19)
- Home Assistant setup guide, Mosquitto ACL / Lovelace / automation examples, disposable broker smoke harness, and MQTT privacy notes (#19)
- Anonymized README screenshots + product-tour GIF (`docs/assets/`), including Home Assistant sensors/device captures

## [0.1.0] — 2026-10-31

### Added
- Menu-bar sit/stand break coach with Vision movement verification
- Explicit break lifecycle state machine (#7)
- Presentation Mode / PresentationGuard (#13)
- Local break history (#8) + Today dashboard (#9)
- Launch at login via `SMAppService` (#11)
- Privacy model documentation (`docs/PRIVACY.md`) (#10)

[0.3.0]: https://github.com/EtienneDeneuve/unchair/releases/tag/v0.3.0
[0.2.3]: https://github.com/EtienneDeneuve/unchair/releases/tag/v0.2.3
[0.2.2]: https://github.com/EtienneDeneuve/unchair/releases/tag/v0.2.2
[0.2.1]: https://github.com/EtienneDeneuve/unchair/releases/tag/v0.2.1
[0.2.0]: https://github.com/EtienneDeneuve/unchair/releases/tag/v0.2.0
[0.1.0]: https://github.com/EtienneDeneuve/unchair/releases/tag/v0.1.0

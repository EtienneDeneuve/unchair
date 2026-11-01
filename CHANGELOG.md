# Changelog

All notable changes to Unchair are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows SemVer (`MARKETING_VERSION`).

## [Unreleased]

### Added
- Home Assistant setup guide, Mosquitto ACL / Lovelace / automation examples, disposable broker smoke harness, and MQTT privacy notes (#19)

## [0.2.1] — 2026-11-01

### Added
- Accept safe Home Assistant MQTT commands over `unchair/<device_id>/command` (#18): allowlisted `start_break` / `postpone` / `skip` / `presentation_on` / `presentation_off`, duplicate `id` dedupe, MQTT Discovery buttons
- Conventional Commits + Keep a Changelog workflow (`CONTRIBUTING.md`)

### Changed
- MQTT session stays connected after CONNECT (subscribe + receive loop) so command topic delivery works
- MQTT Keychain password is loaded once at startup and cached in-process (reconnect/test no longer re-prompt)

## [0.2.0] — 2026-11-01

Standalone trust milestone, plus the start of the optional Home Assistant plane.

### Added
- Movement debt as a first-class domain model (#20): current / peak / accumulated metrics, freeze on sleep/lock only, persisted across restart
- Typed capability catalog and operating modes (#34): Standalone / Apple Enhanced / Sensors Only, surfaced in Settings
- Multi-source Evidence Engine (#35): fuses Vision (and future) claims into verification outcomes without leaking landmarks or letting a source complete a break
- Domain event bus (#14): typed break / presentation events adapters can subscribe to without coupling BreakEngine to MQTT
- Home Assistant MQTT contract (#15) and optional client (#16): TLS/plain, Keychain password, reconnect backoff, Settings UI + Test Connection
- MQTT publish to Home Assistant (#17): retained state + availability, non-retained events, MQTT discovery entities
- CI build & test on every PR (#12) and documented Developer ID + notarized release path (`scripts/release.sh`)

### Changed
- Menu bar / snapshot surfaces expose richer debt and capability state for UI and adapters

### Security / privacy
- MQTT secrets stay in Keychain only; payloads omit camera / landmark / meeting content (see `docs/PRIVACY.md`, `docs/mqtt-contract.md`)
- Core break loop remains fully functional when MQTT is disabled or the broker is down

### Notes
- Artifact is Developer ID signed, notarized, and stapled

## [0.1.0] — 2026-11-01

First public Mac standalone cut (“Move your ass”).

### Added
- Menu bar scheduler + hard-to-ignore break overlay with live camera preview
- Local Vision sit→stand + subject-lifted movement proof
- Explicit break lifecycle state machine (#7)
- Presentation Mode / PresentationGuard (#13)
- Local break history (#8) + Today dashboard (#9)
- Launch at login via `SMAppService` (#11)
- Privacy model documentation (`docs/PRIVACY.md`) (#10)

[0.2.1]: https://github.com/EtienneDeneuve/unchair/releases/tag/v0.2.1
[0.2.0]: https://github.com/EtienneDeneuve/unchair/releases/tag/v0.2.0
[0.1.0]: https://github.com/EtienneDeneuve/unchair/releases/tag/v0.1.0

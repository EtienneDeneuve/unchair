# Mac App Store sandbox gate (#138)

Issue: [#138](https://github.com/EtienneDeneuve/unchair/issues/138) · Epic: [#137](https://github.com/EtienneDeneuve/unchair/issues/137)

This document is the **sandbox compatibility gate** for the `Unchair-MAS` / `AppStore` channel.
It is **not** a claim of App Store Connect / TestFlight / Review readiness (#139–#141).

Apple references used for entitlement decisions:

- [App Sandbox](https://developer.apple.com/documentation/security/app_sandbox) — Store Mac apps must enable `com.apple.security.app-sandbox`.
- [Enabling App Sandbox Network Access](https://developer.apple.com/documentation/xcode/configuring-network-connections-in-an-app-sandbox) — incoming listeners need `com.apple.security.network.server`; outbound clients need `com.apple.security.network.client`.
- [Accessing files from the macOS App Sandbox](https://developer.apple.com/documentation/security/accessing_files_from_the_macos_app_sandbox) — containerized Application Support / preferences.
- [Sharing access to keychain items](https://developer.apple.com/documentation/security/keychain_services/keychain_items/sharing_access_to_keychain_items_among_a_collection_of_apps) — `keychain-access-groups`.
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice) — `SMAppService.mainApp` for Login Items (no extra sandbox entitlement for the main app).

## Entitlements

| Key | Direct (`Unchair.entitlements`) | MAS (`Unchair-MAS.entitlements`) | Why |
| --- | --- | --- | --- |
| `com.apple.security.app-sandbox` | absent | **true** | Store requirement |
| `com.apple.security.device.camera` | true | true | Optional Vision verification |
| `com.apple.security.network.client` | absent (non-sandbox) | **true** | Outbound MQTT |
| `com.apple.security.network.server` | n/a | **absent** | OpenMetrics `NWListener` disabled on MAS instead |
| `com.apple.security.cs.disable-library-validation` | true (Sparkle helpers) | absent | Not needed without Sparkle runtime updates |
| `keychain-access-groups` | absent | `$(AppIdentifierPrefix)com.etiennedeneuve.unchair` | Sandboxed SecItem for MQTT password |

## Compatibility matrix

| Surface | Direct | MAS sandbox | Decision |
| --- | --- | --- | --- |
| Scheduler / overlay / debt | works | works | Keep |
| Camera + Apple Vision | works | works (`device.camera`) | Keep |
| Local history (Application Support) | `~/Library/Application Support/Unchair` | **container** path under `~/Library/Containers/…/Data/Library/Application Support/Unchair` | Keep; Direct↔MAS migration = [#142](https://github.com/EtienneDeneuve/unchair/issues/142) |
| UserDefaults preferences | works | containerized | Keep |
| Keychain MQTT password | works (non-sandbox) | works via access group | Keep identifiers; no silent rename |
| Launch at login (`SMAppService.mainApp`) | works | works | Keep |
| Notifications / permission recovery | works | works | Keep |
| MQTT client (outbound) | works | works (`network.client`) | Keep; fail-open unchanged |
| OpenMetrics HTTP (`NWListener`) | optional | **disabled** | Omit `network.server`; UI shows unavailable |
| Local Unix control socket + `unchair` CLI | works | **disabled** | Container path unreachable to external CLI; App Group deferred to #142 |
| Sparkle in-app updates | works | compile-gated off (`#if !APPSTORE`) | Keep; Sparkle package still linked in XcodeGen — strip/link hygiene = [#139](https://github.com/EtienneDeneuve/unchair/issues/139) |
| Fail-open optional integrations | yes | yes | Keep |

## Behavior differences (user-visible)

1. **About → Channel** shows `Mac App Store` (no Check for Updates…).
2. **Integrations → OpenMetrics** is unavailable with an explicit footer (no scrape port).
3. **`unchair` CLI** cannot control a Store install (socket not started). Direct installs unchanged.
4. History / settings live in the **sandbox container** — a prior Direct install’s files are not auto-imported (see #142).

## Validation commands

```bash
xcodegen generate
# Unit tests (Direct host — channel helpers + docs/entitlement source gates)
xcodebuild test -scheme Unchair -destination 'platform=macOS'

# Sandboxed AppStore configuration build
xcodebuild build -scheme Unchair-MAS -configuration AppStore \
  -derivedDataPath /tmp/UnchairMAS \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=NO

# Inspect entitlements baked into the product (signed local builds)
codesign -d --entitlements :- /tmp/UnchairMAS/Build/Products/AppStore/Unchair.app
```

Expect MAS entitlements to include `app-sandbox`, `device.camera`, `network.client`, and **not** `network.server`.

## Deferred (out of #138)

| Item | Issue |
| --- | --- |
| Apple Distribution signing / ASC upload | #139 |
| TestFlight clean-Mac acceptance | #140 |
| Store listing / privacy nutrition / Review notes | #141 |
| Direct ↔ MAS data coexistence / App Group for CLI | #142 |
| Unlink Sparkle framework from AppStore product | #139 |

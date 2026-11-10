# Privacy / security regression — Mac standalone

Issue: #114  
Contract: [PRIVACY.md](./PRIVACY.md)

This is the v1.0 gate that privacy-critical behavior cannot silently regress. Prefer **executable tests**; use the manual checklist only for paths that are awkward to automate.

## Executable coverage map

| Invariant | Primary tests |
| --- | --- |
| Vision frames stay in memory; pipeline never writes disk | `FramePipelineTests` |
| Break history JSON has only scalar keys (no media / landmarks) | `BreakHistoryStoreTests.testSchemaForbidsMediaFieldsByConstruction` |
| Domain / MQTT event payloads forbid landmarks / frames | `DomainEventTests`, `MQTTPublishTests` |
| MQTT command allowlist rejects `complete` / `fake_movement` | `MQTTCommandTests` |
| MQTT password lives in Keychain adapter; config JSON has no password | `MQTTClientTests` |
| BreakEngine stays free of MQTT / Keychain types | `MQTTClientTests.testBreakEngineStillFreeOfMQTTTypes` |
| Human Runtime card text has no camera / landmark / health fields | `HumanRuntimeWeeklySummaryTests`, `PrivacySecurityRegressionTests` |
| Human Runtime export metrics are summary scalars only | `PrivacySecurityRegressionTests.testHumanRuntimeExportSurfaceStaysScalar` |
| Lifecycle tracer allowlists attributes | `BreakLifecycleTracerTests` |
| Privacy doc stays honest | `PrivacyDocsTests`, `PrivacySecurityRegressionTests` |
| Docs for MQTT / HA still forbid landmarks & admin creds | `MQTTContractDocsTests`, `HomeAssistantDocsTests` |

Run the high-signal slice locally:

```bash
xcodebuild test -scheme Unchair -destination 'platform=macOS' \
  -only-testing:UnchairTests/PrivacySecurityRegressionTests \
  -only-testing:UnchairTests/PrivacyDocsTests \
  -only-testing:UnchairTests/FramePipelineTests \
  -only-testing:UnchairTests/BreakHistoryStoreTests \
  -only-testing:UnchairTests/MQTTCommandTests \
  -only-testing:UnchairTests/MQTTClientTests \
  -only-testing:UnchairTests/HumanRuntimeWeeklySummaryTests
```

## Manual regression checklist (release)

Use when shipping a privacy-touching build (camera, history, export, MQTT, Sparkle):

```text
[ ] Camera LED is off outside timed break / Settings Camera preview / probe
[ ] Completing a break with camera denied still writes history with failedOpen only (no media files under Application Support/Unchair)
[ ] MQTT: broker command `complete` is ignored; local verification still required
[ ] MQTT: password not visible in ~/Library/Preferences or config dumps; only Keychain
[ ] Human Runtime Copy Image / Save PNG shows counts/SLO/debt only — no pose overlay
[ ] docs/PRIVACY.md reviewed against the CHANGELOG for this release
```

## Change control

Any PR that weakens an invariant above must update this map and `PRIVACY.md` in the same change.

# App Privacy (nutrition labels) — Unchair MAS

Answers must match [`PRIVACY.md`](../PRIVACY.md) and the **Mac App Store** binary (no Sparkle; App Sandbox — see #138 `docs/mas-sandbox.md` when merged).

If ASC UI labels differ slightly, keep the same intent: **no collected data leaves the device for the core product**, and optional integrations are user-initiated.

## Data collection summary

| Question | Answer for MAS core |
| --- | --- |
| Do you or your third-party partners collect data from this app? | **No** for the core break loop (schedule, overlay, local history, optional on-device Vision). |
| Optional integrations | Only if the user enables MQTT / Home Assistant (or other allowlisted adapters). Then **derived break telemetry** may leave the device to **the user’s broker**. Still never frames, landmarks, masks, meeting content. |

If ASC forces a “Yes” because optional networking exists, declare only what MQTT may publish (event names, phase, durations, counters) under **Product Interaction** / **Other Diagnostic Data**-style buckets as **linked to user only via their own broker**, **not used for tracking**, **not used for third-party advertising**. Prefer documenting “Data Not Collected” for the default install path and explain integrations in Review notes.

## Camera / body-related

| Topic | Declare |
| --- | --- |
| Camera | Used for optional movement verification; **not** collected/stored/transmitted. Processed in memory via Apple Vision. |
| Body / Health | **Do not** declare HealthKit, clinical health records, or biometric identity. Joint landmarks are ephemeral and not persisted. |
| Sensitive info | None collected. |

## Tracking

- **Tracking:** No  
- No third-party ad SDKs  
- No analytics phone-home in the standalone Mac path  

## Direct-channel vs MAS (do not mix answers)

| Signal | Direct (Developer ID) | MAS |
| --- | --- | --- |
| Sparkle update check | May contact GitHub HTTPS for appcast/zip | **Absent** |
| OpenMetrics local HTTP server | Optional | **Unavailable** (sandbox gate) |
| Local CLI control socket | Optional | **Unavailable** (sandbox gate) |
| MQTT / HA | Optional | Optional (network client entitlements only as shipped) |

## Privacy Policy URL

https://github.com/EtienneDeneuve/unchair/blob/main/docs/PRIVACY.md

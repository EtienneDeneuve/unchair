# Unchair MQTT contract

**Contract version:** `1`  
**Status:** implemented through #17 (publish) and #18 (commands)  
**Depends on:** [integration-events.md](./integration-events.md) (`DomainEvent.schemaVersion = 1`)

This document is the public Home Assistant / MQTT surface for Unchair.
Adapters translate `DomainEvent` values into these topics. BreakEngine never
imports MQTT.

## Design goals

- One Mac ⇒ one coherent Home Assistant **device** via MQTT Discovery.
- Multiple Macs on one broker are distinguished by a stable `device_id`.
- Availability uses online/offline + broker Last Will.
- No camera frames, Vision landmarks, images, audio, or meeting/app metadata.
- Evolving the contract must not silently break existing HA entities
  (`uniq_id` stability + additive versioning).

## Device identity

```text
device_id = "uch_" + lowercase_hex(sha256(hardwareUUID)[0..<8])
```

- Prefer `IOPlatformUUID` (or equivalent anonymized machine id).
- Do **not** publish the user’s full name or raw hostname by default.
- Optional Settings override: display name only (never used as topic segment).

Example: `uch_a1b2c3d4`

## Topic namespace

```text
unchair/<device_id>/availability
unchair/<device_id>/state
unchair/<device_id>/event
unchair/<device_id>/command
homeassistant/sensor/unchair_<device_id>_<object_id>/config
homeassistant/binary_sensor/unchair_<device_id>_<object_id>/config
homeassistant/button/unchair_<device_id>_<object_id>/config
```

QoS defaults:

| Topic class | QoS | Retain |
|---|---|---|
| `availability` | 1 | yes |
| `state` | 1 | yes |
| `event` | 1 | **no** |
| `command` | 1 | no |
| discovery `.../config` | 1 | yes |

Last Will on `availability`: payload `offline`, retain=true, QoS 1.

## Availability

| Payload | Meaning |
|---|---|
| `online` | Unchair process connected and publishing |
| `offline` | LWT after disconnect / clean shutdown publishes offline |

## State topic

`unchair/<device_id>/state` — retained JSON snapshot of current derived state.

```json
{
  "contractVersion": 1,
  "deviceId": "uch_a1b2c3d4",
  "updatedAt": "2026-11-01T17:00:00Z",
  "phase": "working",
  "breakDue": false,
  "presentationMode": false,
  "hasMovementDebt": false,
  "movementDebtSeconds": 0,
  "sittingSeconds": 1200,
  "nextBreakAt": "2026-11-01T17:40:00Z",
  "today": {
    "completed": 2,
    "skipped": 1,
    "postponed": 0,
    "movementMinutes": 3,
    "longestSittingSeconds": 3200,
    "currentSittingSeconds": 1200
  }
}
```

### `phase` enum

`idle` | `working` | `breakDue` | `onBreak` | `postponed` | `deferredForPresentation` | `paused`

### Privacy

Allowed: timestamps, phase, booleans, counters, durations, `failedOpen`.  
Forbidden: landmarks, joints, frames, images, video, audio, process names,
bundle ids, meeting titles, hostnames (unless explicitly opted in later).

## Event topic

`unchair/<device_id>/event` — **non-retained** stream of domain events.

```json
{
  "contractVersion": 1,
  "deviceId": "uch_a1b2c3d4",
  "name": "break.completed",
  "occurredAt": "2026-11-01T17:05:12Z",
  "breakId": "550e8400-e29b-41d4-a716-446655440000",
  "payload": {
    "stoodForSeconds": 12,
    "motionScore": 0.42,
    "failedOpen": false
  }
}
```

`name` values match `DomainEventName` in [integration-events.md](./integration-events.md).

## Command topic (#18)

`unchair/<device_id>/command` — non-retained JSON. Only safe, explicit actions.
Unchair **subscribes** after CONNECT; Home Assistant (or any MQTT client) publishes.

```json
{
  "contractVersion": 1,
  "command": "postpone",
  "minutes": 15,
  "id": "optional-dedupe-key",
  "issuedAt": "2026-11-01T18:00:00Z"
}
```

| Field | Required | Notes |
|---|---|---|
| `contractVersion` | yes | must be `1` |
| `command` | yes | allowlisted name below |
| `minutes` | when required | integer; see allowlists |
| `id` | no | opaque string; duplicate `id` values are ignored (idempotent) |
| `issuedAt` | no | informational ISO-8601; not used for auth |

Allowed commands (v1):

| command | Effect | `minutes` |
|---|---|---|
| `start_break` | same as menu **Start break now** (`startBreakNow`) | omit |
| `postpone` | postpone owed break; keeps movement debt | required ∈ {15,30,45,60} |
| `skip` | skip owed break; keeps movement debt | omit |
| `presentation_on` | enable Presentation Mode | optional ∈ {30,45,60}; omit ⇒ until disabled |
| `presentation_off` | disable Presentation Mode | omit |

### Validation / rejection

- Unknown, malformed, or wrong `contractVersion` → **ignored** (logged safely, no payload dump).
- Commands pass through the same domain state machine as the local UI.
  Invalid transitions (e.g. `postpone` while idle/working with no owed break) are
  rejected by BreakEngine and do not mutate state.
- `presentation_on` during an active break is allowed; PresentationGuard then
  defers overlays until presentation ends (same as local menu).
- Duplicate `id` within the recent window → ignored (no second execution).

### Forbidden (hard denylist)

Never accepted over MQTT:

- marking a break **completed** / faking movement verification
- camera control
- settings that weaken privacy

Examples that must reject: `complete`, `complete_break`, `verify_movement`,
`fake_movement`, `camera_on`.

## Home Assistant MQTT Discovery

Publish retained discovery configs so entities group under one device:

```json
{
  "name": "Phase",
  "uniq_id": "unchair_uch_a1b2c3d4_phase",
  "stat_t": "unchair/uch_a1b2c3d4/state",
  "val_tpl": "{{ value_json.phase }}",
  "avty_t": "unchair/uch_a1b2c3d4/availability",
  "payload_available": "online",
  "payload_not_available": "offline",
  "dev": {
    "ids": ["uch_a1b2c3d4"],
    "name": "Unchair",
    "mf": "Unchair",
    "mdl": "Mac Standalone",
    "sw": "0.1.0"
  }
}
```

### Initial entities

| HA type | object_id | Source |
|---|---|---|
| sensor | `phase` | `state.phase` |
| sensor | `completed_today` | `state.today.completed` |
| sensor | `skipped_today` | `state.today.skipped` |
| sensor | `postponed_today` | `state.today.postponed` |
| sensor | `movement_minutes_today` | `state.today.movementMinutes` |
| sensor | `longest_sitting` | `state.today.longestSittingSeconds` (device_class duration) |
| sensor | `current_sitting` | `state.today.currentSittingSeconds` |
| sensor | `next_break` | `state.nextBreakAt` (timestamp) |
| binary_sensor | `break_due` | `state.breakDue` |
| binary_sensor | `presentation_mode` | `state.presentationMode` |
| sensor | `last_break_event` | latest `event.name` (optional convenience) |
| button | `start_break` | command `start_break` |
| button | `postpone_15` / `_30` / `_45` / `_60` | command `postpone` + minutes |
| button | `skip` | command `skip` |
| button | `presentation_on_30` / `_45` / `_60` | command `presentation_on` + minutes |
| button | `presentation_on` | command `presentation_on` until disabled |
| button | `presentation_off` | command `presentation_off` |

`uniq_id` format: `unchair_<device_id>_<object_id>` — **never reuse** for a different meaning.

Button discovery uses `cmd_t` = `unchair/<device_id>/command` and a fixed
`payload_press` JSON matching the command table above.

## Versioning / compatibility

1. `contractVersion` is an integer in every JSON payload.
2. Additive fields are allowed without bumping the version.
3. Removing/renaming fields or changing `uniq_id` semantics requires a major bump
   and dual-publish or migration notes in this doc.
4. Discovery configs should include `"o": { "name": "Unchair", "sw": "…" }` when
   HA supports origin metadata (optional).

## Multi-Mac

Each Mac uses its own `device_id` and topic prefix. A single broker can host
many Unchair devices; HA groups entities per `dev.ids`.

## Mapping from DomainEvent

| DomainEvent | MQTT action |
|---|---|
| any break / presentation event | publish non-retained `event` + refresh retained `state` |
| (periodic tick / today stats change) | refresh retained `state` only |

Adapters must ignore unknown `name` values forward-compatibly.

## Out of scope for this contract

- TLS / auth (Keychain credentials — #16)
- Client reconnect loops (#16)
- Command authorization beyond the safe allow-list (#18)
- Prometheus / OpenTelemetry (#22 / #23)

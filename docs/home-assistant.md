# Home Assistant + MQTT (optional)

Unchair can publish break state to Home Assistant over MQTT and accept a
**narrow allowlist** of commands back. This is entirely optional.

Core break scheduling, camera verification, Presentation Mode, and Today stats
keep working when MQTT is off, the broker is down, or HA is misconfigured.

**Contract (topics / schemas):** [`mqtt-contract.md`](./mqtt-contract.md)  
**Privacy implications:** [`PRIVACY.md`](./PRIVACY.md) § Network + § MQTT below  
**Copy-paste examples:** [`examples/home-assistant/`](../examples/home-assistant/)

## What you get

After a successful connect with **Home Assistant Discovery** enabled, HA should
show one device named **Unchair** with sensors (phase, today counters, sitting
durations, next break, last event) plus binary sensors (break due, presentation
mode) and **buttons** for safe commands (start / postpone / skip / presentation).

## Setup (Mosquitto add-on)

1. Install / start the **Mosquitto broker** add-on (or any MQTT 3.1.1 broker).
2. Create an **MQTT-only user** (not your HA admin account unless you intend that).
   - Prefer a dedicated HA People user, **or** a Mosquitto `logins:` entry.
3. Scope ACL to the device prefix when possible — see
   [`examples/home-assistant/mosquitto/`](../examples/home-assistant/mosquitto/).
   Least privilege is `unchair/<device_id>/#` for that Mac, not `#`.
4. In HA: **Settings → Devices & services → MQTT** pointing at the same broker.
5. In Unchair → Settings → **MQTT / Home Assistant**:
   - Enable MQTT
   - Host = HA / broker LAN address (or `homeassistant.local`)
   - Port `1883` (plain) or `8883` (TLS)
   - Username + password (Keychain)
   - Enable **Home Assistant Discovery**
   - **Test Connection** — should succeed once; password is cached in-process
6. Confirm the device under **MQTT → Devices → Unchair**.

Your Mac’s `device_id` is shown in Unchair Settings (form `uch_` + 8 hex).

## Privacy implications of enabling MQTT

Enabling MQTT means **derived break telemetry leaves the Mac** toward whatever
hosts the broker (often your LAN HA box).

| May leave the Mac | Must never leave the Mac |
|---|---|
| Phase, booleans, counters, durations | Camera frames / images / video / audio |
| Break event names + tiny scalars | Vision landmarks / joints / masks |
| Presentation on/off | Meeting titles, window contents, app inventories |
| Availability online/offline | Broker admin credentials in docs or git |

Commands from HA cannot mark a break completed or fake movement proof.

Treat the broker like any other home-automation bus: LAN trust, TLS when off-LAN,
dedicated MQTT user, least-privilege ACL. Unchair does not need (and docs never
ask for) broad broker admin credentials.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Test Connection: unreachable | Wrong host/port/TLS, firewall | Ping host; match 1883 vs 8883 + TLS toggle |
| `broker refused` / Mosquitto `not authorised` | Bad MQTT user/pass or ACL | Create MQTT user; check ACL for `unchair/<id>/#` |
| Keychain popup loop | Old build re-read Keychain every reconnect | Use ≥ 0.2.1; click **Always Allow** once per signed binary |
| No Unchair device in HA | Discovery off, or MQTT integration not on same broker | Enable Discovery; confirm HA MQTT points at broker |
| Buttons present, no effect | App not running / disconnected / invalid transition | Keep Unchair running; check phase (e.g. postpone only when break owed) |
| Entities unavailable | LWT offline / app quit | Open Unchair; wait for `availability=online` |

Listen with HA **Developer tools → MQTT** on `unchair/#` and `homeassistant/#`
while Unchair connects (admin / Advanced Mode may be required).

## Local validation without production HA

Use the disposable Mosquitto stack and smoke script under
[`examples/home-assistant/mosquitto/`](../examples/home-assistant/mosquitto/)
and [`scripts/mqtt-integration-smoke.sh`](../scripts/mqtt-integration-smoke.sh).

Optional live XCTest suite (skipped by default):

```bash
export UNCHAIR_MQTT_INTEGRATION=1
export UNCHAIR_MQTT_HOST=127.0.0.1
export UNCHAIR_MQTT_PORT=1883
# optional: UNCHAIR_MQTT_USERNAME / UNCHAIR_MQTT_PASSWORD
xcodebuild test -scheme Unchair -destination 'platform=macOS' \
  -only-testing:UnchairTests/MQTTLiveIntegrationTests
```

Default `xcodebuild test` stays **broker-free**.

## Examples vs product requirements

Automations that flash a desk light when a break is overdue are **illustrative**.
They are not required behavior and make **no medical or wellness claims**.
Unchair remains a local movement-break tool, not a health device.

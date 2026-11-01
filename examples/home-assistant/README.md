# Home Assistant examples

Copy-paste starters for optional Unchair MQTT integration.

These are **examples**, not required product behavior. They make no medical claims.

| Path | Purpose |
|---|---|
| [`mosquitto/`](./mosquitto/) | Disposable broker + least-privilege ACL for `unchair/<device_id>/#` |
| [`lovelace/unchair-dashboard.yaml`](./lovelace/unchair-dashboard.yaml) | Sample Lovelace cards |
| [`automations/`](./automations/) | Sample automations (desk light, notify) |

Setup walkthrough: [`docs/home-assistant.md`](../../docs/home-assistant.md)  
Wire contract: [`docs/mqtt-contract.md`](../../docs/mqtt-contract.md)

Replace `uch_d19add06` with the Device ID from Unchair Settings.

# Home Assistant examples

Copy-paste starters for optional Unchair MQTT integration.

These are **examples**, not required product behavior. They make no medical claims.

| Path | Purpose |
|---|---|
| [`mosquitto/`](./mosquitto/) | Disposable broker + least-privilege ACL for `unchair/<device_id>/#` |
| [`lovelace/unchair-dashboard.yaml`](./lovelace/unchair-dashboard.yaml) | Sample Lovelace cards |
| [`automations/break-due-desk-light.yaml`](./automations/break-due-desk-light.yaml) | One-shot desk light when break becomes due |
| [`automations/break-due-escalation.yaml`](./automations/break-due-escalation.yaml) | Timed escalation policy (+0 / +3 / +5 / +7 / +10m) + reset |
| [`automations/presentation-on-notify.yaml`](./automations/presentation-on-notify.yaml) | Notify when Presentation Mode engages |

### Escalation policy (optional)

[`automations/break-due-escalation.yaml`](./automations/break-due-escalation.yaml) turns a missed break into a staged physical-environment nudge. Unchair only publishes `break_due`; **HA owns the policy**.

```text
break due
  +0m  → notification
  +3m  → desk light orange
  +5m  → desk light red
  +7m  → voice / notify
 +10m  → standing desk (commented) / absurd notify
```

Stages use `for:` on `binary_sensor.unchair_<device_id>_break_due`. If the break clears before a stage’s duration, that stage never fires. The reset automation turns the example light off when `break_due` goes `off`. Lights / TTS / desk entities are placeholders — no vendor lock-in.

Setup walkthrough: [`docs/home-assistant.md`](../../docs/home-assistant.md)  
Wire contract: [`docs/mqtt-contract.md`](../../docs/mqtt-contract.md)

Replace `uch_d19add06` with the Device ID from Unchair Settings.

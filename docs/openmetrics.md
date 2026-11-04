# OpenMetrics / Prometheus (optional)

Unchair can expose a privacy-safe `GET /metrics` endpoint for local scraping.

**Off by default.** Enable in Settings → Integrations → **OpenMetrics**.

## Endpoint

| | |
|---|---|
| Default URL | `http://127.0.0.1:9108/metrics` |
| Bind | `127.0.0.1` unless **Allow LAN exposure** is on |
| Format | OpenMetrics text 1.0 |

## Metrics

| Name | Type | Meaning |
|---|---|---|
| `unchair_breaks_completed_total` | counter | Completed breaks (process lifetime) |
| `unchair_breaks_skipped_total` | counter | Skipped breaks |
| `unchair_breaks_postponed_total` | counter | Postpone actions |
| `unchair_movement_seconds_total` | counter | Standing/movement seconds from completed breaks |
| `unchair_movement_debt_seconds` | gauge | Current movement debt |
| `unchair_current_sitting_seconds` | gauge | Freeze-aware sitting stretch |
| `unchair_sitting_slo_ratio` | gauge | Today `completed/(completed+skipped)` (1 if empty) |
| `unchair_presentation_mode` | gauge | `1` if Presentation Mode on |

**No labels.** No hostname, user, app, window, or meeting dimensions.

## Privacy / threat model

| Exposed | Never exposed |
|---|---|
| Aggregated counters / gauges above | Camera frames, landmarks |
| | MQTT passwords / Keychain secrets |
| | Device IDs, usernames, window titles |

LAN exposure widens who can scrape the Mac on your network. Prefer localhost + SSH tunnel / local Prometheus.

Adapter failures (bind errors, scrape storms) do **not** stop the break loop.

## Prometheus scrape example

```yaml
scrape_configs:
  - job_name: unchair
    scrape_interval: 15s
    static_configs:
      - targets: ["host.docker.internal:9108"]
```

Dashboard example: [`examples/grafana/`](../examples/grafana/).

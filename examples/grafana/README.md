# Grafana — Human Runtime (example)

Import [`human-runtime-dashboard.json`](./human-runtime-dashboard.json) into Grafana.

Requires a Prometheus (or compatible) datasource scraping Unchair OpenMetrics — see [`docs/openmetrics.md`](../../docs/openmetrics.md).

## Panels

- Current sitting duration
- Current movement debt
- Completed vs skipped (rates)
- Movement minutes (from counter)
- Sitting SLO ratio
- Presentation mode
- Break completion / skip / postpone rates

No personal identifiers are hard-coded. No medical claims.

## Import

1. Enable OpenMetrics in Unchair (localhost `:9108`).
2. Point Prometheus at that target.
3. Grafana → Dashboards → Import → upload the JSON.
4. Select your Prometheus datasource when prompted (`DS_PROMETHEUS`).

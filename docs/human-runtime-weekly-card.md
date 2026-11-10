# Human Runtime weekly card

Privacy-safe weekly summary derived **only** from local break history on this Mac.

## Where

Today window → **Human Runtime — this week** → **Copy image** / **Save PNG…**

No automatic posting. The user chooses when and where to share.

## Schema (local-only)

| Field | Source | Notes |
| --- | --- | --- |
| Week number | Calendar week of `now` | Monday-start week |
| Sitting SLO | `completed / (completed + skipped)` | Postpones are debt, not scored as failures |
| Movement debt peak | Longest gap between completions in-week | Proxy from history ends — not camera |
| Breaks completed / postponed | History `result` counts | |
| MTTB | Mean `endedAt - startedAt` for completed rows with `startedAt` | Mean Time To Butt-off |
| SEV-2 line | Debt peak ≥ 1h | Deadpan copy only |

## Never included

- camera frames
- body landmarks
- health / HealthKit data
- app or window names
- meeting titles
- hostname / username (by default)
- exact work schedule

## Engineering

- Aggregation: `HumanRuntimeWeeklySummaryCalculator` (pure, fixture-tested)
- Rendering / export: `HumanRuntimeWeeklyCardView` (AppKit clipboard + Save panel)
- Network: none

Synthetic example for docs/marketing can be produced from fixtures without a real user history.

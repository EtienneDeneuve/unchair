# Break lifecycle tracing (optional)

Unchair emits OpenTelemetry-**style** spans for break lifecycles through an adapter boundary.

No OpenTelemetry SDK or exporter is required for core behavior. The default exporter is a no-op.

## Example reconstruction

```text
break.lifecycle
  -> break.due
  -> break.postponed
  -> movement.started
  -> movement.verified
  -> break.completed
```

## Attribute allowlist

Only these keys may appear on spans:

| Key | Meaning |
|---|---|
| `unchair.break_id` | Break UUID |
| `unchair.state` | Domain event name |
| `unchair.sitting_seconds` | Derived sitting duration |
| `unchair.postpone_until_epoch` | Postpone deadline |
| `unchair.presentation_pending_since_epoch` | Presentation deferral start |
| `unchair.break_ends_at_epoch` | Timed break end |
| `unchair.stood_for_seconds` | Verified stand duration |
| `unchair.motion_score` | Scalar motion score |
| `unchair.failed_open` | Verification failed-open flag |
| `unchair.presentation_until_epoch` | Manual presentation end |

Never serialized: camera frames, landmarks, window/meeting titles, app inventory, credentials.

## Tests

`UnchairTests/BreakLifecycleTracerTests` uses `InMemoryBreakTraceExporter` to assert lifecycle order and the attribute allowlist.

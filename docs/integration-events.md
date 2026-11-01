# Integration domain events

Stable boundary between BreakEngine and optional adapters (MQTT / Home Assistant / metrics).

```text
BreakEngine
    |
    v
DomainEvent  (schemaVersion = 1)
    |
    +--> History
    +--> UI
    +--> MQTT / Home Assistant
    +--> OpenMetrics / OTel (future)
```

## Rules

- Event names are stable strings (`break.due`, …).
- Payloads are typed and JSON-Codable.
- No camera frames, Vision landmarks, or meeting/app metadata.
- Adapters subscribe via `DomainEventBus`; zero sinks ⇒ core unchanged.
- Adding a fake adapter requires no BreakEngine changes.

## Events

| Name | When | Payload notes |
|---|---|---|
| `break.scheduled` | Work interval armed | `until` |
| `break.due` | Break becomes owed | optional `sittingSeconds` |
| `break.postponed` | User postpones | `until` |
| `break.deferredForPresentation` | PresentationGuard blocks | `pendingSince` |
| `break.started` | Timed break begins | `endsAt` |
| `break.completed` | Successful completion | optional motion metrics + `failedOpen` |
| `break.skipped` | Explicit skip | empty |
| `presentation.enabled` | Manual presentation on | optional `until` |
| `presentation.disabled` | Manual presentation off | empty |

Executable fixture: `UnchairTests/Fixtures/domain-events.json`.

# Break scheduler contract (#110)

Source of truth for the Mac-only break loop. Implementation: `BreakStateMachine` + `BreakScheduler` + `MovementDebtEngine`. UI (overlay / Today) must mirror this contract; it must not invent timers.

## Architecture

Clean-ish ports & adapters, Mac-app scale (not a hexagon factory):

| Layer | Owns |
| --- | --- |
| `BreakEngine/` | Pure domain: phases, events, debt, persistence *ports* (`BreakClock`, `PresentationGuarding`, `BreakLifecycleStoring`). **Foundation only.** |
| `PresentationGuard/`, `MovementDetection/`, AppKit adapters | Drive the ports with real signals / camera. |
| `MenuBarShell` | Composition root: wires scheduler + overlay + camera preference. |
| `UI/` | Renders `BreakSnapshot` / overlay models — no schedule math. |

Dependency rule: UI/App → Engine. Engine never imports AppKit/SwiftUI/AVFoundation.

Known compromise: `UserDefaultsBreakLifecycleStore` lives next to the domain types (adapter colocated for discoverability). The store is still behind `BreakLifecycleStoring`, so tests inject `InMemoryBreakLifecycleStore`.

## Invariants

1. **Mac-only is complete.** Presentation / MQTT / camera never become requirements for the loop.
2. **Absolute deadlines.** Work / postpone / break end times are wall-clock dates, adjusted only when the desk clock thaws.
3. **Fail open.** If camera verification cannot run, the user can still complete or skip; debt rules still apply.
4. **No silent debt loss.** Postpone, skip, presentation deferral, sleep/lock, and relaunch must not clear owed movement debt unless the break is completed (or debt is explicitly cleared on a fresh completed cycle).
5. **No invented sitting.** Sleep, lock, and HID idle freeze sitting duration and work countdown. Lunch at a locked Mac must not become two hours of desk time.

## Phases

| Phase | Meaning | UI expectation |
| --- | --- | --- |
| `idle` | Not started | Menu bar idle |
| `working(until)` | Cadence running until deadline | Countdown to next break |
| `breakDue` | Break owed now | Overlay due prompt; camera still off |
| `onBreak(endsAt, verification)` | Timed movement break | Overlay active; camera only if verification opted in |
| `postponed(until)` | User deferred; debt kept | Countdown to return |
| `deferredForPresentation(pendingSince)` | Call / presentation blocking | No nag; debt kept; resume to `breakDue` when clear |
| `paused` | Manual pause | Remaining work preserved |

`onBreak` is **never persisted as-is**. A quit mid-break restores as `breakDue` so a stale capture session is never resurrected.

## Events (domain)

`start` · `evaluate` · `startBreakNow` · `beginTimedBreak` · `complete` · `skip` · `postpone(until)` · `pause` · `resume` · `standDetected` · `movementVerified` · `verificationFailed` · `updateSettings`

Invalid transitions are rejected (`BreakTransitionResult.failure`) — the phase stays put.

## Desk-clock freeze vs presentation deferral

| Signal | Sitting / work clocks | Movement debt | Overlay |
| --- | --- | --- | --- |
| Screen locked / asleep | **Frozen** | Frozen | No due fire while frozen |
| HID idle (unlocked, past threshold) | **Frozen** | Frozen | Same |
| Presentation / call (`isBlocking`) | Accrue normally | Accrue | Defer to `deferredForPresentation`; return to `breakDue` |

Only `shouldFreezeDeskClock` (lock/sleep/idle) freezes. Meeting blocks defer interruptions; they do **not** discard debt.

## Movement debt

- Becomes active when a break is owed (`breakDue`, postpone, deferral, skip path).
- Accrues while active and not desk-frozen.
- Cleared on **complete** (verified or fail-open).
- Kept on **skip** and **postpone**.
- Survives process relaunch via `BreakPersistedState.movementDebt`.

## Persistence / relaunch

Persisted fields include phase kind, deadlines, sitting start, freeze start, debt state, break id, and settings intervals.

Restore rules:

- `working` / `postponed` / `paused` / `deferredForPresentation` / `breakDue` restore in kind.
- Mid-`onBreak` → `breakDue` + debt active.
- After restore, freeze is re-synced against current lock/idle so a long quit while locked does not inflate sitting on thaw.

## Evaluate tick

`evaluate` (periodic / wake) must:

1. sync inactivity freeze (possibly shift deadlines on thaw)
2. refresh debt
3. promote due deadlines only when not frozen
4. leave presentation deferral until `isBlocking` clears, then land on `breakDue` with debt intact

## UI copy alignment

| Domain fact | Honest copy |
| --- | --- |
| Freeze during lock/sleep/idle | Clocks pause; lunch does not become sitting |
| Presentation deferral | Interruptions wait; debt is not discarded |
| Postpone / skip | Debt preserved |
| Complete | Debt cleared; new work interval |
| Relaunch mid-break | Prompt returns as break due (no zombie camera) |

Avoid claiming medical rest, posture scores, or that deferral “resets” the break.

## Tests

Executable coverage lives in:

- `BreakStateMachineTests` — transitions, freeze, relaunch
- `BreakSchedulerTests` — façade cadence
- `MovementDebtTests` — accrual / freeze / restore
- `Fixtures/break-scheduler-transitions.json` — table of named scenarios for #110

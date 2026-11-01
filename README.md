# Unchair

> A mildly annoying macOS app that makes you move.

You've been sitting for 50 minutes. Unchair doesn't care about your deadline. Stand up.

Unchair is a small native macOS app that interrupts long, static desk sessions, asks for a short movement break, and verifies locally that you actually moved before marking the break complete.

No cloud account. No camera recording. No posture score. No wellness dashboard pretending to be medicine.

## Why

The goal is not to enforce a mythical "perfect posture".

The goal is to reduce long periods of immobility by creating small, regular movement interruptions that are hard to dismiss accidentally.

Unchair should be:

- local-first
- privacy-preserving
- mildly annoying
- technically boring
- easy to reason about
- useful without an account or backend

## MVP

- Native macOS menu bar app
- Configurable work interval and break duration
- Hard-to-ignore break overlay
- Postpone without erasing movement debt
- Presentation / screen-share safety guard
- Local sit -> stand detection with Apple Vision
- Lightweight movement verification
- Completed / skipped / postponed break history
- Daily movement summary
- Launch at login
- Optional Home Assistant integration through MQTT
- 100% local camera processing
- Zero image or video persistence

## Example

```text
You've been sitting for 52 minutes.

Move your ass.

[ Start 90s break ]   [ Postpone 15m ]

Standing detected.
Good start.

Movement verified.

Done.
You may return to your terrible posture.
```

## Break semantics

A completed break starts a new work interval.

A postponed break does not.

```text
completed    -> movement debt cleared
postponed    -> movement debt preserved
presentation -> movement debt preserved
skipped      -> explicit decision not to move
```

Example:

```text
14:00 break due
      |
      +--> postpone 45 min

14:45 break due again
      |
      +--> meeting still active
             |
             +--> PresentationGuard defers

14:52 meeting ends
      |
      +--> break becomes due immediately
```

## Product principles

1. **Local first**  
   Core behavior works without network access, accounts or a server.

2. **No surveillance**  
   Store events, not footage. Camera frames are ephemeral.

3. **Useful friction**  
   Annoying enough to work, never hostile or impossible to dismiss.

4. **Movement over posture policing**  
   Encourage movement variability instead of assigning a posture score.

5. **Privacy by architecture**  
   Raw camera data and Vision landmarks must never cross the movement-detection boundary.

6. **Small native app**  
   Prefer Swift, SwiftUI, AVFoundation, Vision and system frameworks before dependencies.

7. **Integrations are adapters**  
   Home Assistant, MQTT and future integrations must never become dependencies of the break engine.

## Architecture

```text
                       +------------------+
                       |       UI         |
                       +--------+---------+
                                |
                                v
+----------------+      +-------+--------+      +------------------+
| Presentation   |----->|   BreakEngine  |----->|     History      |
| Guard          |      | + StateMachine |      +------------------+
+----------------+      +-------+--------+
                                |
                                v
                       +--------+---------+
                       |  Domain Events   |
                       +--------+---------+
                                |
                +---------------+----------------+
                |                                |
                v                                v
       +--------+---------+             +--------+---------+
       | Local observers  |             | Integration      |
       | / diagnostics    |             | adapters         |
       +------------------+             +--------+---------+
                                                |
                                                v
                                         MQTT / Home Assistant

MovementDetection
  |
  +--> AVFoundation
  +--> Vision
  +--> derived movement state only
```

Suggested source boundaries:

```text
Unchair/
├── App/
├── BreakEngine/
├── MovementDetection/
├── PresentationGuard/
├── History/
├── Integrations/
│   └── MQTT/
└── UI/
```

Initial target stack:

- Swift
- SwiftUI
- AVFoundation
- Vision
- SwiftData or a tiny local store
- SMAppService for launch at login
- Keychain for integration secrets

## Presentation safety

Unchair must not decide that your quarterly review is the ideal moment to cover the screen with:

> Move your ass.

macOS does not expose a universal public API that reliably tells an unrelated app that another application is currently screen sharing.

The product therefore uses a fail-safe `PresentationGuard` based on strong signals such as:

- camera already in use
- microphone already in use when detectable
- explicit Presentation Mode
- sleep / screen lock
- meeting application + corroborating signal

When presentation activity is suspected:

```text
scheduled -> deferredForPresentation
```

No overlay. No camera activation. No sound.

The pending break becomes due when the guard clears.

Manual Presentation Mode supports bounded durations and "until HH:MM".

### Compatibility matrix (manual before v1)

| Context | Expected Unchair behavior |
| --- | --- |
| FaceTime with camera/mic in use | Defer break |
| Zoom / Teams / Slack huddle with device in use | Defer break |
| Google Meet in Safari/Chrome with camera or mic in use | Defer break |
| OBS / QuickTime / Screen Sharing with device in use | Defer break |
| Zoom idle in background, camera free | Do **not** defer forever |
| Manual Presentation Mode | Defer until duration / time / disabled |
| Screen lock or display sleep | Defer |
| Unchair’s own break camera | Does not count as “another app” |

Detection is fail-safe, not authoritative. Unchair does **not** require Screen Recording permission by default and does not inspect meeting content.

## Home Assistant

Home Assistant support is optional and uses MQTT.

Unchair remains fully functional when MQTT is disabled, unavailable or misconfigured.

### Device model

A Mac can expose entities such as:

```text
sensor.unchair_state
sensor.unchair_completed_today
sensor.unchair_skipped_today
sensor.unchair_postponed_today
sensor.unchair_movement_minutes_today
sensor.unchair_longest_sitting_minutes
sensor.unchair_current_sitting_minutes
sensor.unchair_next_break

binary_sensor.unchair_break_due
switch.unchair_presentation_mode

event.unchair_break
```

Suggested topics:

```text
unchair/<device-id>/state
unchair/<device-id>/event
unchair/<device-id>/availability
unchair/<device-id>/command
```

Home Assistant may eventually send a narrow set of commands:

```text
break.start
break.postpone
presentation.enable
presentation.disable
```

It must never be able to:

- mark a break completed
- fake movement verification
- inject arbitrary application state
- execute arbitrary commands

### Privacy boundary

MQTT may contain derived state such as:

```json
{
  "type": "completed",
  "duration_seconds": 103,
  "sitting_duration_seconds": 3124
}
```

It must never contain:

- images
- video
- audio
- Vision landmarks
- body geometry
- meeting titles
- window contents
- running application inventory

Credentials belong in macOS Keychain.

## Development model

Unchair is developed spec-first and test-first.

The expected loop is:

```text
issue/spec
   |
   v
acceptance criteria
   |
   v
failing test
   |
   v
minimal implementation
   |
   v
refactor
   |
   v
full test suite
```

Repository automation and coding agents must follow [agent.md](./agent.md).

### Building the Mac app

```text
open Unchair.xcodeproj
```

Or from the CLI:

```text
xcodebuild -project Unchair.xcodeproj -scheme Unchair -destination 'platform=macOS' test
```

The Xcode project targets macOS 14+, uses SwiftUI `MenuBarExtra`, and sets `LSUIElement` so Unchair runs as a menu bar agent without a Dock icon by default. `project.yml` mirrors the same layout for optional [XcodeGen](https://github.com/yonaskolb/XcodeGen) regeneration.

## Privacy

Camera input is processed in memory for pose and movement estimation.

The intended persisted event model looks like:

```text
2026-10-29T14:32:10+01:00 break.completed duration=104s
```

No images. No video. No biometric profile.

Network integrations are optional and may only receive explicitly allowed derived domain events.

## Operating modes

**Mac-only is a complete product.**

```text
Standalone
  Mac + local Vision verification

Apple Enhanced
  Mac + Vision + optional iPhone / Apple Watch evidence

Sensors Only
  Optional privacy mode using sufficiently strong non-camera evidence
```

iPhone, Apple Watch, Home Assistant, MQTT, Prometheus and OpenTelemetry are capability layers. They are never prerequisites for the core break loop.

## Roadmap

See [ROADMAP.md](./ROADMAP.md) for the release train and [roadmap issue #44](https://github.com/EtienneDeneuve/unchair/issues/44) for operational tracking.

Current release direction:

- **v0.1** — complete Mac-only movement loop
- **v0.2** — trustworthy standalone daily-driver
- **v0.3** — Home Assistant and observability adapters
- **v1.0** — stable Mac Standalone release
- **v1.5** — Apple Enhanced with iPhone, Watch and HealthKit-derived evidence
- **v2.x** — Human Reliability Engineering, because apparently this was inevitable

## License

MIT

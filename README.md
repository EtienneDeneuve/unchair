# Unchair

<p align="center">
  <strong>Your Mac knows you've been sitting for 52 minutes.<br/>Now it wants proof that you actually stood up.</strong>
</p>

<p align="center">
  A local-first macOS app that interrupts long sitting sessions and uses Apple Vision to verify movement — entirely on-device.
</p>

<p align="center">
  <a href="https://github.com/EtienneDeneuve/unchair/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/EtienneDeneuve/unchair/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/EtienneDeneuve/unchair/releases/latest"><img alt="Release" src="https://img.shields.io/github/v/release/EtienneDeneuve/unchair"></a>
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-black?logo=apple">
  <a href="./LICENSE"><img alt="MIT" src="https://img.shields.io/github/license/EtienneDeneuve/unchair"></a>
</p>

---

A reminder can be dismissed.

A notification can be ignored.

Unchair waits for you to **stand up and move**.

```text
You've been sitting for 52 minutes.

Move your ass.

[ Start 90s break ]   [ Postpone 15m ]

Standing detected.
Keep moving...

Movement verified.

Done.
You may return to your terrible posture.
```

No cloud account. No camera recording. No posture score. No wellness dashboard pretending to be medicine.

## Install

Download the latest signed and notarized build:

**[Download Unchair →](https://github.com/EtienneDeneuve/unchair/releases/latest)**

Then:

1. unzip `Unchair-*-macos.zip`
2. move `Unchair.app` to `/Applications`
3. open it
4. grant camera access if you want local movement verification
5. continue pretending your chair is not the problem

Current releases are Developer ID signed, notarized and stapled.

Requires **macOS 14+**.

## What it does

- lives quietly in the macOS menu bar
- tracks uninterrupted desk time
- interrupts long sitting sessions
- lets you postpone without erasing the debt
- detects **sit → stand** with Apple Vision
- verifies that you actually moved
- processes camera frames **only in memory**
- shows a local live skeleton/pose preview during verification
- avoids interrupting presentations and calls
- stores only tiny derived history locally
- launches at login
- optionally integrates with **Home Assistant over MQTT**

The Mac-only experience is the complete product. No iPhone, Apple Watch, Home Assistant, account or backend is required.

## The part that makes Unchair different

Most break apps trust the button.

Unchair can verify the movement.

```text
Mac camera
    |
    v
person segmentation
    |
    v
Apple Vision body pose
    |
    v
sit -> stand detection
    |
    v
standing time + movement score
    |
    v
Evidence Engine
    |
    v
movement verified
```

The camera is not a recording device here. It is an ephemeral sensor.

Frames, masks and Vision landmarks stay inside the local movement-detection boundary and are discarded after processing.

**No image or video persistence. No biometric profile. No upload.**

If no verification source is available — for example camera permission is denied — Unchair fails open rather than trapping the user in an impossible break.

See [the privacy model](./docs/PRIVACY.md) for the actual boundaries instead of marketing promises.

## Movement debt

Postponing is not completing.

```text
completed              -> movement debt cleared
postponed              -> movement debt preserved
deferredForPresentation -> movement debt preserved
skipped                -> explicit non-completion
```

Example:

```text
14:00  break due
       |
       +--> postpone 45m

14:45  break due again
       |
       +--> meeting still active
              |
              +--> PresentationGuard defers

14:52  meeting ends
       |
       +--> break becomes due immediately
```

Because "remind me later" should not magically count as exercise.

## Presentation-safe by design

Unchair should be annoying.

It should not be career-limiting.

A break is deferred when strong presentation signals are present, including:

- camera or microphone already in use by another app
- screen lock / sleep
- explicit Presentation Mode
- meeting application + corroborating device signal

When blocked:

```text
scheduled -> deferredForPresentation
```

No overlay. No camera activation. No interruption audio.

When the signal clears, the movement debt is still there.

macOS does not expose a perfect universal "someone is screen sharing" API, so the guard is deliberately conservative and does not require Screen Recording permission.

## Home Assistant, because obviously

Unchair works completely offline.

But if you already run Home Assistant, the chair situation can become infrastructure.

MQTT Discovery exposes an Unchair device with derived state such as:

- current phase
- current sitting duration
- completed / postponed / skipped breaks
- movement minutes
- next break
- presentation mode
- break due

And Home Assistant may send a narrow allowlist of commands:

```text
start_break
postpone
skip
presentation_on
presentation_off
```

It **cannot** mark movement as verified or complete a break remotely.

Example escalation policy:

```text
break due
  +0m  notification
  +3m  desk light orange
  +5m  desk light red
  +7m  voice announcement
 +10m  reconsider your life choices
```

Setup: [docs/home-assistant.md](./docs/home-assistant.md)  
Examples: [examples/home-assistant/](./examples/home-assistant/)  
MQTT contract: [docs/mqtt-contract.md](./docs/mqtt-contract.md)

## Architecture

Unchair is intentionally small and boring internally.

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
       | Evidence Engine  |             | Integration      |
       | Vision / future  |             | adapters         |
       +------------------+             +--------+---------+
                                                |
                                                v
                                         MQTT / Home Assistant
```

Core behavior does not depend on MQTT, Home Assistant, networking or future Apple companions.

### Stack

- Swift + SwiftUI
- AVFoundation
- Apple Vision
- SMAppService
- macOS Keychain
- Network.framework
- XCTest
- zero backend required

## Operating modes

```text
Standalone
  Mac + local Vision verification

Apple Enhanced
  Mac + Vision + optional iPhone / Apple Watch evidence

Sensors Only
  optional non-camera evidence
```

The Evidence Engine already abstracts movement verification away from the sensor source.

That means future Watch, HealthKit or chair-sensor evidence can improve verification without turning those devices into dependencies.

## Human Reliability Engineering

This started as "remind me to stand up."

It is unfortunately becoming a human observability platform.

Already real:

- **Movement Debt**
- domain events
- local history
- MQTT telemetry
- deterministic break state machine

On the roadmap, because restraint has clearly failed:

- Sitting SLO
- Human Error Budget
- Prometheus / OpenMetrics
- OpenTelemetry traces
- Grafana **Human Runtime**
- Apple Watch + HealthKit evidence
- chair occupancy sensors
- automatic sitting incident reports
- `unchair doctor`
- Mean Time To Butt-off

Potential future incident:

```text
INCIDENT #CHAIR-2026-11-01

Severity: SEV-2 Glute Availability Degradation
Duration: 2h17
Movement debt peak: 77m
Corrective action: human stood up
```

See [ROADMAP.md](./ROADMAP.md).

## Privacy is an architecture constraint

Unchair is not:

- a medical device
- a posture diagnostic tool
- an employee surveillance product
- a fitness tracker replacement
- a cloud SaaS dependency

Raw camera frames:

- exist only in memory
- are processed locally
- are never persisted
- are never transmitted

Vision landmarks and segmentation masks follow the same rule.

MQTT and future integrations receive only explicitly allowed derived state.

Full threat model: [docs/PRIVACY.md](./docs/PRIVACY.md)

## Build from source

```bash
git clone https://github.com/EtienneDeneuve/unchair.git
cd unchair
open Unchair.xcodeproj
```

Or run the test suite:

```bash
xcodebuild \
  -project Unchair.xcodeproj \
  -scheme Unchair \
  -destination 'platform=macOS' \
  test
```

CI runs on every PR and on `main`.

Signed/notarized releases are built with [scripts/release.sh](./scripts/release.sh).  
Release process: [docs/RELEASE.md](./docs/RELEASE.md)

## Contributing

Unchair is spec-driven and test-first.

```text
issue/spec
   -> acceptance criteria
   -> failing test
   -> minimal implementation
   -> refactor
   -> full test suite
```

Read [CONTRIBUTING.md](./CONTRIBUTING.md) and [agent.md](./agent.md) before changing behavior.

The core rule is simple:

> If two designs satisfy the specification, choose the one that is easier to delete.

## Status

Unchair is young, functional and moving quickly.

The Mac standalone loop is implemented. Home Assistant/MQTT support is already shipping. Apple Watch, HealthKit and the more questionable Human Reliability Engineering features are tracked in the roadmap.

If Unchair made you stand up before finishing this README, the bug is working.

## License

MIT.

# Unchair Roadmap

> Mac-first. Apple-enhanced. Local-first. Mildly annoying.

This roadmap is intentionally release-oriented.

The most important product rule is:

> **A Mac by itself is a complete Unchair product.**

iPhone, Apple Watch, Home Assistant, MQTT, Prometheus, OpenTelemetry and every other absurd enhancement are optional capability layers.

---

## Release train

### v0.1 — Move your ass

Goal: prove the complete Mac-only loop.

- [ ] #1 Bootstrap native macOS menu bar app
- [ ] #2 Implement configurable break scheduler
- [ ] #3 Build hard-to-ignore break overlay
- [ ] #4 Add camera permission and local capture pipeline
- [ ] #5 Detect sit -> stand transition with Apple Vision
- [ ] #6 Implement movement proof for a completed break
- [ ] #7 Model break lifecycle as an explicit state machine
- [ ] #13 Add presentation / screen-share safety guard

**Exit criteria**

A user with only a Mac can install Unchair, receive a break, postpone it, avoid interruption during a presentation, stand up, move, and have the break verified locally.

No account. No network. No cloud.

---

### v0.2 — Standalone that we can trust

Goal: turn the prototype into a privacy-safe daily-driver.

- [ ] #8 Store break history locally
- [ ] #9 Add Today dashboard and menu bar stats
- [ ] #10 Document privacy model and threat boundaries
- [ ] #11 Support launch at login and sane lifecycle behavior
- [ ] #12 Set up CI, signed builds and release pipeline
- [ ] #20 Model movement debt as a first-class domain concept
- [ ] #34 Define Unchair capability model and operating modes
- [ ] #35 Generalize movement verification into a multi-source Evidence Engine

**Exit criteria**

Standalone mode is releasable, deterministic, testable and independent of every optional integration.

Camera frames remain ephemeral and local.

---

### v0.3 — The integration plane nobody asked for

Goal: expose Unchair without coupling the core to anything external.

- [ ] #14 Define integration domain events and adapter boundary
- [ ] #15 Design Home Assistant MQTT contract and discovery
- [ ] #16 Implement optional MQTT client with Keychain-backed credentials
- [ ] #17 Publish Unchair telemetry and break events to Home Assistant
- [ ] #18 Accept safe Home Assistant commands over MQTT
- [ ] #19 Add Home Assistant examples, test harness and privacy documentation
- [ ] #22 Expose privacy-safe OpenMetrics / Prometheus metrics
- [ ] #23 Add OpenTelemetry tracing for break lifecycle
- [ ] #24 Create Grafana Human Runtime dashboard example
- [ ] #25 Add Home Assistant escalation policy examples
- [ ] #33 Add unchair CLI and unchair doctor

**Exit criteria**

All integrations are optional adapters.

Network loss, a dead MQTT broker, a broken Grafana dashboard or Home Assistant deciding to become Home Assistant must not affect the core break loop.

---

### v1.0 — Mac Standalone

Goal: first stable public release.

Required release properties:

- native macOS experience
- local Vision verification
- presentation-safe behavior
- movement debt semantics
- local history
- deterministic state machine
- privacy threat model
- signed/notarized delivery
- CI and test coverage around domain invariants
- no external dependency required for normal use

Integrations from v0.3 may ship when stable, but are not allowed to delay the standalone product unless they affect privacy/security.

---

### v1.5 — Apple Enhanced

Goal: make iPhone and Apple Watch improve the evidence quality without replacing Mac Vision.

- [ ] #36 Create optional iOS companion foundation
- [ ] #37 Add HealthKit-derived recent movement adapter on iOS
- [ ] #38 Create watchOS companion for live movement evidence and break UI
- [ ] #39 Implement WatchConnectivity live channel and reachability model
- [ ] #40 Bridge Apple companion telemetry to Mac over authenticated local transport
- [ ] #41 Add wearable-aware recent movement reconciliation
- [ ] #42 Research optional Watch-iPhone proximity as evidence quality signal
- [ ] #43 Extend privacy threat model for HealthKit, Watch and companion transport

**Operating modes**

```text
Standalone
  Mac + Vision

Apple Enhanced
  Mac + Vision + optional Watch/iPhone evidence

Sensors Only
  Optional privacy mode where strong non-camera evidence can replace camera use
```

**Hard requirement**

Removing the iPhone and Watch must leave a fully functional Unchair.

---

### v2.x — Human Reliability Engineering

Goal: maximize technical seriousness around an objectively unserious problem.

- [ ] #21 Add Sitting SLO and human error budget
- [ ] #26 Add optional smart standing desk adapter via Home Assistant
- [ ] #27 Define optional chair occupancy sensor integration
- [ ] #28 Add Boss Fight movement challenge mode
- [ ] #29 Add achievements without turning Unchair into Duolingo
- [ ] #30 Generate automatic sitting incident reports and weekly post-mortems
- [ ] #31 Add calendar-aware break deferral adapter
- [ ] #32 Reconcile one human across multiple Macs

Potential terminology that should never have existed:

- Movement Debt
- Sitting SLO
- Human Error Budget
- Mean Time To Butt-off
- Human Runtime
- SEV-2 Glute Availability Degradation

---

## Architecture evolution

### Stage 1

```text
Mac
 |
 +-- BreakEngine
 +-- Vision
 +-- PresentationGuard
 +-- History
```

### Stage 2

```text
                     +--> History
                     |
BreakEngine --> Domain Events --> MQTT / HA
                     |
                     +--> OpenMetrics / OTel
```

### Stage 3

```text
Mac Vision -----------+
Apple Watch ----------+
HealthKit ------------+--> Evidence Engine --> BreakEngine
Chair sensor ---------+
Mac activity ---------+
```

Every stage must remain independently useful.

---

## Release gates

A feature does not move the release forward merely because it works once.

For a release gate to be considered complete:

- acceptance criteria are satisfied
- tests cover domain behavior
- failure paths are explicit
- privacy boundaries are preserved
- no new permission is broader than necessary
- documentation reflects public behavior
- hardware-only claims are manually verified before being advertised
- optional adapters fail open without degrading core behavior

See [agent.md](./agent.md) for the engineering contract.

---

## Non-goals

Unchair is not:

- a medical device
- a posture diagnostic tool
- an employee surveillance platform
- a fitness tracker replacement
- a cloud SaaS dependency
- a reason to store camera footage
- an excuse to infer health state from HRV, sleep or heart rate

The project may be absurd.

The architecture should not be.

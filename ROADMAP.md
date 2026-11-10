# Unchair Roadmap

> Mac-first. Local-first. Mildly annoying.

The product rule is simple:

> **A Mac by itself is a complete Unchair product.**

Everything else is optional evidence, integration or unnecessary infrastructure.

## Shipped

### Mac standalone

The core loop is live:

- menu-bar app
- configurable break scheduler
- hard-to-ignore overlay
- local camera capture
- Apple Vision sit → stand detection
- movement verification
- movement debt
- presentation safety
- local history + Today stats
- launch at login
- privacy threat model
- signed + notarized direct releases
- Sparkle updates

### Integration layer

Also shipped:

- domain-event adapter boundary
- Home Assistant MQTT discovery
- safe inbound MQTT commands
- Keychain-backed integration credentials
- optional OpenMetrics / Prometheus endpoint
- optional OpenTelemetry break tracing
- Grafana Human Runtime dashboard
- Home Assistant escalation examples
- `unchair` CLI
- `unchair doctor`

These adapters must remain optional. A dead broker or broken dashboard must never break the core product.

### Distribution — make it findable

Goal: turn a working app into something people can actually discover and install.

- [x] #82 Distribution readiness for Unchair
- [x] #83 Improve repository metadata and discoverability
- [x] #84 Ship a first-class Homebrew Cask install path
- [x] #85 Add a privacy-safe Human Runtime weekly summary card
- [x] #86 Define a repeatable public release communication checklist
- [x] #91 Publish dedicated Unchair pages on etienne.deneuve.xyz and Omnivya
- [x] #97 SEO: honest Unchair vs Stretchly vs Time Out comparison (FR + EN)
- [x] #98 Earn independent mentions outside our own sites

Engineering-health issues such as #87, #89 and #90 are deliberately tracked outside the public product roadmap.

## Now — make the standalone product boringly good

Target: **v1.0 Mac Standalone**.

Tracked work:

- [ ] #108 v1.0 Mac Standalone readiness
- [x] #109 First-run onboarding for install, permissions and login item
- [x] #110 Deterministic break scheduler under deferral and debt — see `docs/break-scheduler.md`
- [x] #111 Recoverable camera and permission failure modes
- [x] #112 Battery and CPU budget for Vision and idle — see `docs/battery-cpu.md`
- [x] #113 Accessibility pass for Today and break overlay — see `docs/accessibility.md`
- [ ] #114 Privacy and security regression coverage for Mac standalone
- [ ] #115 Distribution quality gate for the 1.0 release train
- [ ] #116 v1.0 exit gate and 1.0.0 release

Focus:

- reliability of the Mac-only loop
- polish around install/update/onboarding
- battery/CPU discipline
- accessibility
- deterministic scheduler behavior
- clean failure modes for camera and permissions
- privacy/security regression coverage
- distribution quality

v1.0 does not wait for iPhone, Apple Watch, Home Assistant or observability features.

## Next — Apple Enhanced

Goal: use Apple devices as optional evidence sources without turning them into dependencies.

Tracked work:

- #36 iOS companion foundation
- #37 HealthKit-derived recent movement
- #38 watchOS companion
- #39 WatchConnectivity live channel
- #40 authenticated local Mac bridge
- #41 wearable-aware movement reconciliation
- #42 proximity research
- #43 privacy-model extension

```text
Mac Vision -----------+
Apple Watch ----------+
HealthKit ------------+--> Evidence Engine --> BreakEngine
Chair sensor ---------+
Mac activity ---------+
```

Removing the iPhone and Watch must leave a fully functional Unchair.

## Later — Human Reliability Engineering

Goal: apply an unreasonable amount of operational discipline to sitting down.

Tracked ideas:

- #21 Sitting SLO and human error budget
- #26 optional standing-desk adapter
- #27 optional chair-occupancy sensor
- #28 Boss Fight movement challenge
- #29 achievements
- #30 sitting incident reports / weekly post-mortems
- #31 calendar-aware break deferral
- #32 multi-Mac reconciliation

Potential terminology:

- Movement Debt
- Sitting SLO
- Human Error Budget
- Mean Time To Butt-off
- Human Runtime
- SEV-2 Glute Availability Degradation

The jokes are optional.

The domain invariants are not.

## Release gates

A feature is not done because it worked once.

Before release:

- acceptance criteria are satisfied
- domain behavior is covered by tests
- failure paths are explicit
- privacy boundaries remain intact
- permissions are no broader than necessary
- documentation matches public behavior
- hardware claims are manually verified
- optional adapters fail open

See [agent.md](./agent.md).

## Non-goals

Unchair is not:

- a medical device
- a posture diagnostic tool
- an employee-monitoring platform
- a fitness tracker replacement
- a cloud SaaS dependency
- a reason to store camera footage
- an excuse to infer health state from HRV, sleep or heart rate

The project may be absurd.

The architecture should not be.

# agent.md

This file defines the engineering contract for humans and coding agents working on Unchair.

The goal is not maximum abstraction. The goal is a small, native, privacy-preserving macOS application whose behavior is easy to specify, test and reason about.

## 1. Source of truth

Work must start from a GitHub issue or an explicit written specification.

Before changing code:

1. Read the relevant issue completely.
2. Identify the acceptance criteria.
3. Identify affected domain invariants.
4. Identify privacy/security implications.
5. Write or update tests that express the intended behavior.
6. Only then implement.

Do not silently invent product behavior.

If an issue is ambiguous, choose the smallest behavior consistent with the existing state machine, README and privacy model. Document the assumption in the PR.

## 2. Spec-driven development

Every non-trivial feature must have observable behavior defined before implementation.

Specifications should describe:

- inputs
- outputs
- state transitions
- failure behavior
- persistence behavior
- privacy boundaries
- timing semantics where relevant

Prefer executable specifications expressed as tests over prose-only specifications.

State-machine behavior should be table-driven when practical.

Example:

```text
given: break is due
when: user postpones 45 minutes
then:
  state = postponed
  movement debt remains
  resumeAt = now + 45m
  regular cadence is not reset
```

## 3. TDD is the default

Use Red -> Green -> Refactor.

For behavior changes:

1. Add or change a test that fails for the right reason.
2. Implement the smallest change that makes it pass.
3. Refactor without changing behavior.
4. Run the relevant test target.
5. Run the full suite before considering the work complete.

Do not add implementation first and tests later unless the change is purely mechanical.

Bug fixes require a regression test.

## 4. Test pyramid

### Unit tests

Required for:

- BreakEngine
- scheduler logic
- state-machine transitions
- postpone semantics
- PresentationGuard decisions
- domain-event emission
- command validation
- MQTT payload mapping
- privacy serialization rules

Unit tests must not require:

- camera hardware
- a real MQTT broker
- Home Assistant
- network access
- wall-clock sleeps

Use injected clocks, fake transports and deterministic fixtures.

### Integration tests

Use integration tests for:

- AVFoundation/Vision boundaries
- persistence
- Keychain access
- MQTT broker behavior
- Home Assistant discovery payloads
- launch-at-login behavior

Integration tests may use disposable local dependencies.

### UI tests

Use UI tests only for workflows where view behavior matters.

Do not move domain logic into UI tests.

## 5. Architecture rules

Dependencies point inward.

```text
UI ----------------------+
                         |
PresentationGuard -------+--> BreakEngine / Domain
                         |
History -----------------+
                         |
MQTT / Home Assistant ---+
```

The core domain must not import:

- MQTT
- Home Assistant concepts
- networking clients
- SwiftUI views
- camera frame types
- persistence implementation details

Use protocols at boundaries where they improve testability.

Do not introduce a protocol for every type.

## 6. Domain invariants

These rules are product behavior, not implementation details.

### Break debt

Only a successfully completed break clears movement debt and starts a fresh work interval.

```text
completed              -> clears debt
postponed              -> keeps debt
deferredForPresentation -> keeps debt
skipped                -> explicit non-completion
```

### Movement proof

A break cannot be remotely marked complete.

Completion must come from the local break-verification flow.

Do not allow:

- MQTT
- Home Assistant
- URL schemes
- UI shortcuts
- test/debug commands in release builds

to bypass movement proof.

### Presentation safety

When PresentationGuard has a strong blocking signal:

- do not show the break overlay
- do not activate the camera
- do not play interruption audio
- preserve the pending break

### Local-first behavior

A network failure must never prevent:

- scheduling
- showing a break
- verifying movement
- storing local history
- completing a break

## 7. Privacy invariants

Privacy constraints are hard architectural requirements.

Raw camera frames:

- exist only in memory
- are processed locally
- are released after processing
- are never persisted
- are never transmitted

Vision/body data:

- do not persist landmark streams
- do not transmit landmarks
- do not construct a biometric profile
- do not infer identity
- do not infer sensitive traits

Integration payloads may contain only explicitly allowed derived information.

Forbidden external fields include:

- images
- video
- audio
- body landmarks
- body geometry
- meeting titles
- window contents
- application inventories

Add tests around serializers so forbidden fields cannot accidentally leak.

## 8. Security rules

Secrets must never be committed.

Use macOS Keychain for:

- MQTT passwords
- MQTT tokens
- future integration secrets

Never place secrets in:

- UserDefaults
- source files
- fixture files
- logs
- crash metadata
- snapshots

Remote command handling must use an allowlist.

There is no arbitrary command execution feature.

Do not use private macOS APIs.

Do not broaden permissions when a narrower design is possible.

## 9. Time is a dependency

Scheduler code must not read the wall clock everywhere.

Inject a clock/time provider into domain code.

Tests involving:

- postpone
- deadlines
- sleep/wake
- presentation deferral
- next-break calculation

must be deterministic and complete without real sleeping.

## 10. Concurrency

Prefer Swift structured concurrency.

Use:

- `async/await`
- actors where mutable shared state genuinely exists
- `@MainActor` for UI-bound state

Avoid:

- arbitrary detached tasks
- hidden global queues
- shared mutable singletons
- callback pyramids

Cancellation behavior must be explicit for:

- camera capture
- Vision processing
- MQTT reconnect loops
- timers

## 11. Error handling

Expected failures are part of the product.

Examples:

- camera permission denied
- camera unavailable
- MQTT broker unreachable
- Keychain lookup failure
- corrupt local history
- unsupported state transition

Handle them explicitly.

Do not use `fatalError` for recoverable runtime conditions.

Errors shown to users must be actionable.

Logs must be useful without containing secrets or sensitive data.

## 12. Dependencies

Prefer Apple frameworks.

Before adding a third-party dependency, document:

- problem solved
- why system APIs are insufficient
- maintenance status
- binary/source footprint
- privacy/security impact
- licensing

Avoid adding a dependency for functionality that can be implemented clearly in a small amount of native Swift.

## 13. Code quality

Prefer boring code.

Rules:

- small focused types
- explicit names
- minimal global state
- no hidden side effects
- avoid premature abstraction
- avoid god objects
- avoid giant view models
- domain logic stays outside SwiftUI views
- no duplicated state-machine logic

Comments explain **why**, not what obvious code does.

Public/internal APIs should be intentionally scoped.

## 14. Swift style

Follow current Swift conventions.

Prefer:

- value types for immutable domain models
- enums for closed state sets
- exhaustive switches
- typed identifiers where confusion is possible
- dependency injection through initializers
- pure functions for mappings and calculations

Avoid force unwraps in production code unless an invariant is both local and mechanically guaranteed.

## 15. Observability

Use structured, privacy-safe logs.

Useful fields include:

- event name
- break id
- state transition
- derived durations
- adapter status

Do not log:

- credentials
- camera frames
- landmarks
- meeting metadata
- window titles

Debug logging must obey the same privacy rules as release logging.

## 16. Home Assistant / MQTT boundary

MQTT is an adapter.

The domain emits typed events. The MQTT adapter translates them.

The MQTT adapter must not mutate internal state directly.

Inbound commands are translated into validated domain commands.

Allowed command families are intentionally narrow:

- start break
- postpone break
- enable presentation mode
- disable presentation mode

Home Assistant cannot mark movement as verified or a break as completed.

MQTT failures are non-fatal.

## 17. Git workflow

Keep changes focused.

A PR should normally address one issue or one coherent slice of an issue.

Prefer small commits with meaningful messages.

Recommended prefixes:

- `feat:`
- `fix:`
- `test:`
- `refactor:`
- `docs:`
- `chore:`

Do not mix broad formatting/refactoring with behavior changes unless required.

## 18. Definition of done

A change is done when:

- acceptance criteria are satisfied
- relevant specs/tests exist
- tests pass
- no privacy invariant is weakened
- no unnecessary permission is added
- failure paths are handled
- documentation is updated when public behavior changes
- code remains understandable without hidden context

"Works on my machine" is not sufficient.

## 19. Agent behavior

Coding agents must:

- inspect existing code before editing
- read the issue and nearby tests
- preserve established naming and architecture
- make the smallest coherent change
- run tests after changes
- report what was changed and what was verified

Coding agents must not:

- rewrite unrelated files
- silently change product semantics
- weaken tests to make a build pass
- disable compiler warnings to hide problems
- introduce network/cloud dependencies into core behavior
- fabricate test results
- claim hardware behavior was verified when only mocked

If hardware-dependent behavior cannot be verified in the current environment, implement deterministic tests around the boundary and state clearly what remains to be manually tested.

## 20. Core principle

Unchair is deliberately small.

Every new abstraction, permission, service, dependency and background process must justify its existence.

If two designs satisfy the specification, choose the one that is easier to delete.

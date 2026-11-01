# Unchair privacy model and threat boundaries

This document is the verifiable privacy contract for Unchair — not marketing copy.

If code and this document disagree, treat that as a bug.

## Product promise

Unchair verifies movement **on this Mac**, locally, during a break.

It does **not**:

- record video or audio
- build a biometric or identity profile
- require an account
- require network access for core break scheduling and verification
- send camera frames, landmarks, or meeting content anywhere

## Camera data flow

```text
AVCaptureSession (live)
        │
        ▼
CVPixelBuffer  ──in memory only──►  person segmentation mask (ephemeral)
        │                                      │
        │                                      ▼
        │                            masked buffer (ephemeral)
        ▼
VNDetectHumanBodyPoseRequest
        │
        ▼
PoseSample (joints + optional subjectCoverage)
        │
        ▼
Posture / sit→stand / MovementProof  →  derived scalars only
        │
        ▼
Break history JSON  (timestamps, outcomes, tiny metrics)
```

### What enters memory

| Artifact | Lifetime | Leaves the process? |
| --- | --- | --- |
| Camera `CVPixelBuffer` | Current frame callback | No |
| Person segmentation mask | Pose estimation call | No |
| Masked pixel buffer | Pose estimation call | No |
| Body joints (`PoseSample`) | Until next frame / break end | No (not persisted as a stream) |
| Live `AVCaptureSession` preview | While Settings or active break shows preview | No encoding / no disk |

### What is persisted

Under Application Support (`Unchair/`):

1. **`break-history.v1.json`** — local break outcomes (see README schema).
2. **`UserDefaults` lifecycle blob** — postpone / deferred / working schedule restore across relaunch (no media).

Persisted verification fields are limited to derived scalars such as:

- `stoodForSeconds`
- `motionScore`
- `failedOpen`
- `subjectCoverage` is **not** written to history today; if added later it remains a scalar, never a mask or landmark list.

### What is never persisted

- images / video / audio
- raw or encoded camera frames
- person/subject masks
- body landmark streams or geometry timelines
- face data (Unchair drops face joints from Vision body pose)
- biometric templates or identity embeddings
- meeting titles, window contents, screen pixels
- application inventories beyond transient PresentationGuard checks

Clearing break history from Settings deletes the history file contents. It does not require a network call.

## Network behavior

**Core product (schedule → break → verify → history → Today) works offline.**

Network is only relevant for **optional** future integrations (e.g. MQTT / Home Assistant). Those adapters:

- must fail open (broker down ≠ break loop broken)
- may publish only allowlisted derived events
- must never receive frames, landmarks, masks, or meeting content
- store secrets in Keychain only

Unchair does not phone home for analytics, accounts, or license checks in the standalone Mac path.

## Permissions

| Permission | Why | When requested |
| --- | --- | --- |
| Camera | Local movement verification + optional live preview | Once at launch (not every Settings open / not mid-break prompt) |
| Screen Recording | **Not required** by default | Only if a future opt-in detection path needs it — documented separately |
| Login Item (`SMAppService`) | Optional launch at login | User toggle in Settings — reflects `SMAppService.mainApp` status |
| Network | Not required for core | Only if user enables an integration |

Presentation safety uses public signals (camera/mic in use by another app, screen lock/sleep, manual Presentation Mode, meeting app **plus** device-use corroboration). It does not inspect meeting content.

## Debug logging rules

`OSLog` / `Logger` usage must follow:

- **Allowed:** phase names, durations, boolean flags, quantized motion scores, public timing scalars.
- **Forbidden:** pixel buffers, image/video bytes, base64 media, landmark coordinate dumps, mask buffers, full joint dictionaries as structured payloads.

Current MovementProof logs emit stand-source labels and scalar stood/motion values with `.public` privacy annotations for those scalars only — never joint lists.

If you add logging, prefer:

```swift
log.info("verified stood=\(elapsed, privacy: .public)s")
```

over serializing `PoseSample.joints`.

## Threat boundaries (what we defend against)

| Threat | Mitigation |
| --- | --- |
| Accidental surveillance archive | No frame/mask persistence; history is event scalars only |
| Cloud exfiltration of body data | No network in core path; integration allowlists forbid media/landmarks |
| Remote “mark complete” | Completion requires local verification / failed-open camera policy — not MQTT |
| Over-broad TCC | Camera only; no Screen Recording by default |
| Debug leak via Console | Logging rules above; no landmark serialization |
| Background camera while presenting / locked | PresentationGuard defers overlay + camera |

## Out of scope (explicit non-goals)

Unchair is not a medical device, employee monitoring product, or fitness/HRV analyzer. It does not claim health diagnoses from sitting time.

## Change control

Privacy-affecting changes must:

1. update this document in the same PR
2. keep or add tests that guard serializers / history schema against forbidden fields
3. avoid new permissions wider than necessary

See also [agent.md](../agent.md) § Privacy invariants and [README.md](../README.md) Privacy section.

# Known issues

Honest limitations of the **shipped** Mac standalone build. Prefer linking a GitHub issue over silent folklore.

## PresentationGuard misses Slack huddles (AVFoundation blind spot)

**Issue:** [#134](https://github.com/EtienneDeneuve/unchair/issues/134)  
**Fix track:** [#135](https://github.com/EtienneDeneuve/unchair/issues/135)

During a Slack huddle (including with microphone + screen share), Unchair may still show the break overlay.

**Why:** PresentationGuard’s device signals use `AVCaptureDevice.isInUseByAnotherApplication`. Slack’s huddle audio/share path (WebRTC / Core Audio / ScreenCaptureKit) often never sets that flag — confirmed live with all capture devices reporting `false` while Slack’s audio helper was running.

**Workaround now:** enable **Presentation Mode** from the menu (or `unchair presentation Nm`) for the duration of the call.

**Intended fix:** detect call audio via Core Audio `DeviceIsRunningSomewhere`, still corroborated with the meeting-app allowlist (#135). Screen-share-only detection remains a follow-up.

## Other standing limits (not bugs)

These are product constraints, not defects:

- macOS 14+ only
- Camera optional for reminders; required only for sit→stand verification
- MQTT / OpenMetrics / tracing are optional and must fail open
- Human Runtime is local history only — never auto-posted
- CI does not Developer ID–sign or notarize binaries (see [`SLSA.md`](./SLSA.md))

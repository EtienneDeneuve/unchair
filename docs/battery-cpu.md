# Battery and CPU budget (Mac standalone)

Default Unchair should stay cheap while you work, idle, lock the screen, or sleep the Mac.

Related: #112

## Cost posture (default Direct / MAS build)

| Work | When it may run | When it must stop |
| --- | --- | --- |
| AVCapture + Vision body pose | Timed break with camera verification enabled, or Settings → Camera live preview / probe | Break ends (complete / skip / postpone / deferred); Settings preview closes; lock / sleep / HID idle freeze |
| 1 Hz scheduler tick | Desk clock accruing (working / due / on break) | Throttled to ~5 s while lock / sleep / HID idle freezes the desk clock |
| MQTT client | Only if Integrations → MQTT is enabled | Disabled → no connect / no 15 s state publish tick |
| OpenMetrics HTTP | Only if Integrations → OpenMetrics is enabled | Disabled → no scrape port, no per-tick gauge refresh |
| Local control socket | Always (loopback CLI) | Idle accept only — no polling loop |
| Sparkle (Direct builds) | Periodic update check (default daily) + manual Check for Updates | Not tied to the break ticker |

**Default Mac-only configuration** means: camera verification optional, MQTT/OpenMetrics off, PresentationGuard on public signals only. In that shape, Unchair should not keep the camera LED on between breaks, and should not run Vision while the desk clock is frozen.

## Vision session rules

1. Capture starts only for `onBreak` when the user opted into camera verification, or for an explicit Settings preview/probe.
2. Capture stops when the phase leaves `onBreak`, when Settings closes / leaves the Camera pane, and when a probe finishes (unless a break still needs the session).
3. Opting in from Today / onboarding requests Camera TCC **without** leaving a preview session running.
4. While `shouldFreezeDeskClock` (screen locked / asleep / HID idle past the Settings threshold), Vision is **power-suspended**: capture stops, break completion stays fail-open, and capture may resume when the desk clock thaws if the break is still active.

## What we do not do

- No user-facing “battery mode” product surface in v1.0
- No rewriting Vision models
- No cloud profiling or remote battery telemetry

## Verification

Regression coverage lives in `BreakCameraCoordinatorTests` (power suspend / opt-in without preview leak) and this document is linked from the README privacy / architecture area.

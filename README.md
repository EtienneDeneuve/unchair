# Unchair

> A mildly annoying macOS app that makes you move.

You've been sitting for 50 minutes. Unchair doesn't care about your deadline. Stand up.

## Why

Long, static desk sessions are easy to ignore. Unchair interrupts them, asks for a short movement break, and verifies locally that you actually moved before marking the break complete.

No cloud. No account. No camera recording.

## MVP

- Native macOS menu bar app
- Configurable break scheduler
- Hard-to-ignore break overlay
- Local camera-based sit -> stand detection with Apple Vision
- Lightweight movement verification
- Completed / skipped break history
- Daily movement summary
- 100% local processing
- Zero image or video persistence

## Product principles

1. **Local first** - camera frames never leave the Mac.
2. **No surveillance** - store events, not footage.
3. **Useful friction** - annoying enough to work, never hostile.
4. **Movement over posture policing** - encourage variability, not a mythical perfect posture.
5. **Small native app** - Swift, SwiftUI, AVFoundation and Vision before adding dependencies.

## Example

```text
You've been sitting for 52 minutes.

Move your ass.

[ Start 90s break ]

Standing detected.
Good start.

8 / 10 squats

Done.
You may return to your terrible posture.
```

## Architecture

```text
Unchair
├── App
├── BreakEngine
├── MovementDetection
├── History
└── UI
```

Initial target stack:

- Swift
- SwiftUI
- AVFoundation
- Vision
- SwiftData or a tiny local store
- SMAppService for launch at login

## Privacy

Unchair should function without transmitting personal data.

Camera input is processed in memory for pose and movement estimation. The intended design stores only derived break events such as:

```text
2026-10-29T14:32:10+01:00 break.completed duration=104s
```

No images. No video. No biometric profile.

## Status

Early prototype. The issue tracker is the roadmap.

## License

MIT

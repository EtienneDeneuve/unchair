# App Review notes — Unchair (Mac)

Paste into App Store Connect → App Review Information → Notes.

## Contact

Use the account holder / developer contact already on the Apple Developer membership.  
Support: https://github.com/EtienneDeneuve/unchair/issues

## What the app does

Unchair is a **local-first macOS menu bar app** that reminds the user to take movement breaks. Optionally, during a break, it can use the **Mac camera + Apple Vision** to verify that the user stood up and moved. Verification runs **entirely on-device**.

## Camera / Vision (likely Review questions)

1. Camera permission is **opt-in** (onboarding or Settings). The app does **not** prompt at every launch.  
2. Frames are processed **in memory only**. Unchair does **not** save video, images, masks, or body landmark streams to disk, and does **not** upload them.  
3. Persisted break history is **derived scalars** only (timestamps, outcomes, tiny metrics such as stood duration / motion score).  
4. Face joints from Vision body pose are dropped; Unchair does not build an identity/biometric profile.  
5. If camera access is denied, busy, or unavailable, the break loop **fail-opens**: reminders continue; the user can still complete/skip without silent stalls.

Purpose string (`NSCameraUsageDescription`):

> Unchair uses the camera only during a movement break to verify that you stood up and moved. Frames are processed in memory on this Mac and are never saved or uploaded.

## How to exercise the main path

1. Launch Unchair (menu bar extra).  
2. Open **Settings** from the menu → review Schedule / Camera preference.  
3. Optionally grant Camera, then **Start Break Now** from the menu.  
4. Observe the break overlay; with camera authorized, movement verification may run locally.  
5. Open **Today** for local history / Human Runtime card.  
6. No account sign-in is required.

## Networking / integrations

- **Core product works offline.**  
- **Mac App Store builds do not embed Sparkle.** Updates are via the App Store.  
- Optional MQTT / Home Assistant publish **derived break events** to the **user’s** broker only when configured. They cannot remotely mark a break complete or inject fake verification.  
- OpenMetrics scrape HTTP server and the local CLI control socket are **disabled** on the MAS channel (App Sandbox).

## Positioning

Unchair is **not** a medical device, posture diagnostic, employee-monitoring product, or fitness/HRV tracker. Please evaluate it as a productivity / wellbeing break reminder with optional on-device movement verification.

## Demo account

None required — no login.

## Attachments

Privacy contract: https://github.com/EtienneDeneuve/unchair/blob/main/docs/PRIVACY.md  
Sandbox channel notes: GitHub issue #138 / `docs/mas-sandbox.md` (when merged).

# Documentation assets

Anonymized product screenshots and the README tour GIF.

| File | Description |
|---|---|
| `unchair-tour.gif` | Crossfade product tour for the README hero |
| `unchair-icon-1024.png` | Marketing master of the macOS AppIcon |
| `dmg/background.png` | Finder window backdrop for the GitHub release DMG |
| `screenshots/01-menubar-menu.png` | Menu bar dropdown |
| `screenshots/02-settings-schedule-posture.png` | Schedule + anonymized Vision preview |
| `screenshots/03-settings-mqtt.png` | MQTT / Home Assistant (placeholder device id) |
| `screenshots/04-settings-capabilities.png` | Operating mode + capability catalog |
| `screenshots/05-overlay-break-due.png` | Full-screen break-due overlay |
| `screenshots/06-ha-sensors.png` | Home Assistant Sensors card (MQTT discovery entities) |
| `screenshots/07-ha-device-controls.png` | HA device page: controls + activity |
| `today-ui/today-light.png` | Today window — realistic light mode (#85) |
| `today-ui/today-dark.png` | Today window — realistic dark mode (#85) |
| `today-ui/today-pathological.png` | Today window — 50h+ debt fixture |
| `today-ui/human-runtime-week-card.png` | Branded Copy/Save PNG (icon + Unchair + repo URL) |

## Privacy rules for these files

- No raw camera frames or real faces — posture preview is a synthetic skeleton stub
- Device IDs are placeholders (`uch_a1b2c3d4`), never a live machine id
- EXIF / TIFF / IPTC / GPS metadata is not allowed in documentation media
- Desktop chrome / usernames from capture hosts are cropped out
- Keep the hero GIF below 1 MB and the full README media set below 2 MB

Do not commit raw personal screenshots into this folder. Privacy-sensitive metadata is checked by the test suite; pixel content still requires human review.

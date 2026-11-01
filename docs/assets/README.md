# Documentation assets

Anonymized product screenshots and the README tour GIF.

| File | Description |
|---|---|
| `unchair-tour.gif` | Crossfade product tour for the README hero |
| `screenshots/01-menubar-menu.png` | Menu bar dropdown |
| `screenshots/02-settings-schedule-posture.png` | Schedule + anonymized Vision preview |
| `screenshots/03-settings-mqtt.png` | MQTT / Home Assistant (placeholder device id) |
| `screenshots/04-settings-capabilities.png` | Operating mode + capability catalog |
| `screenshots/05-overlay-break-due.png` | Full-screen break-due overlay |

## Privacy rules for these files

- No raw camera frames or real faces — posture preview is a synthetic skeleton stub
- Device IDs are placeholders (`uch_a1b2c3d4`), never a live machine id
- EXIF / TIFF / IPTC / GPS metadata is not allowed in documentation media
- Desktop chrome / usernames from capture hosts are cropped out
- Keep the hero GIF below 1 MB and the full README media set below 2 MB

Do not commit raw personal screenshots into this folder. Privacy-sensitive metadata is checked by the test suite; pixel content still requires human review.

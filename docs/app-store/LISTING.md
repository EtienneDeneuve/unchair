# App Store Connect listing package (#141)

Copy-paste source for the Mac App Store product page, App Privacy, and App Review.

**Not** a claim that TestFlight (#140) or Review submission is done.

## Upload checklist

| Field | Value / source |
| --- | --- |
| Name | `Unchair` |
| Subtitle | EN/FR below (≤30 chars) |
| Category | **Primary:** Health & Fitness · **Secondary:** Productivity |
| Age rating | 4+ (no unrestricted web, no violence, no medical treatment claims) |
| Copyright | `© 2026 Etienne Deneuve` |
| Support URL | `https://github.com/EtienneDeneuve/unchair/issues` |
| Marketing URL | `https://etienne.deneuve.xyz/en/unchair/` |
| Privacy Policy URL | `https://github.com/EtienneDeneuve/unchair/blob/main/docs/PRIVACY.md` |
| Screenshots | [`../assets/app-store/screenshots/`](../assets/app-store/screenshots/) — prefer `*-2880x1800.png` |
| What's New | From [`CHANGELOG.md`](../../CHANGELOG.md) for the shipped MAS build |
| Review notes | [`review-notes.md`](./review-notes.md) |
| App Privacy | [`privacy-nutrition.md`](./privacy-nutrition.md) |
| EN copy | [`en.md`](./en.md) |
| FR copy | [`fr.md`](./fr.md) |

## Screenshots

Regenerate:

```bash
python3 scripts/generate-asc-screenshots.py
```

ASC Mac sizes accepted: `1280×800`, `1440×900`, `2560×1600`, `2880×1800`.

These frames composite **shipping** UI crops from `docs/assets/` onto 16:10 canvases. Prefer replacing them with native fullscreen captures from the MAS build when Screen Recording is available on the capture Mac.

### Shot order (suggested)

1. Menu bar
2. Today
3. Settings (schedule / posture)
4. Break overlay
5. Human Runtime weekly card

## Positioning (hard rules)

Do **not** claim Unchair is:

- a medical device or diagnostic tool
- an employee-monitoring / workforce-surveillance product
- a fitness tracker or HRV replacement

Do claim:

- local-first break reminders on macOS
- optional on-device Apple Vision movement verification
- frames/landmarks never saved or uploaded
- optional integrations only when the user enables them

## Camera purpose string (Info.plist)

Already shipped:

> Unchair uses the camera only during a movement break to verify that you stood up and moved. Frames are processed in memory on this Mac and are never saved or uploaded.

## Related

- Privacy contract: [`../PRIVACY.md`](../PRIVACY.md)
- MAS sandbox / release docs land with #138–#139 (`docs/mas-sandbox.md`, `docs/RELEASE-MAS.md`) when those PRs merge
- Epic: #137 · this package: #141

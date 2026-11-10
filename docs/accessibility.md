# Accessibility — Today and break overlay

Issue: #113  
Related: [ux-macos.md](./ux-macos.md)

## Goals

VoiceOver, Full Keyboard Access, Dynamic Type, and Increase Contrast must keep the main break loop usable:

1. Start / complete / skip / postpone / quit from the break overlay
2. Read status and open Camera Settings / Unchair Settings from Today recovery
3. Export Human Runtime when history exists

## Overlay

| Control | Label | Notes |
| --- | --- | --- |
| Status block | `headline` + `subheadline` + verification text | Header trait |
| Primary | action title | Return / default button; hint explains disabled state |
| Skip | secondary title | Keeps movement debt |
| Recovery | recovery title when present | Opens System Settings → Camera |
| Postpone 15 min | same | Escape |
| Quit Unchair | same | ⌘Q |
| Camera preview / denied slot | explicit label + privacy hint | Decorative icons hidden |

Typography uses `@ScaledMetric` relative to text styles. Increase Contrast / Reduce Transparency raise chip and secondary-action opacities.

## Today

| Region | Behavior |
| --- | --- |
| Camera setup banner | Containment group; recovery + Settings hints |
| Hero | Combined header label; value scales and can wrap to 2 lines |
| Next action | Spoken as its own element |
| Metrics | One label per metric |
| Export | Copy / Save hints; disabled when week empty |

Layout allows horizontal growth (`minWidth` 420 → `maxWidth` 520) so larger text does not clip critical status.

## Appearance modes

Validated for these surfaces:

- Light / Dark
- Increase Contrast (secondary text and overlay chrome strengthen)
- Reduce Transparency (overlay chip / secondary fill opaque enough)
- Reduce Motion (press scale disabled on overlay buttons)

## Non-goals

- App Store accessibility marketing claims
- Redesigning product hierarchy beyond a11y fixes
- New localization beyond existing copy

## Tests

`AccessibilitySurfaceTests` asserts non-empty required labels for overlay and Today models across verification states.

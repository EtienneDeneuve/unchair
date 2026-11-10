# Unchair macOS UX direction

Issue: #118  
Related: #109 first-run onboarding, #111 recoverable permission failures

This document is the visual and interaction source of truth for the current Mac-only product.

## Product reality

Unchair is a native macOS menu-bar app that:
- tracks desk/sitting time
- schedules movement breaks
- preserves movement debt when breaks are postponed
- can use the Mac camera + Apple Vision body pose locally to verify stand-up + movement
- has a compact Today/Human Runtime view
- exposes Settings for schedule, verification, MQTT/Home Assistant and OpenMetrics

It is **not** a posture-scoring wellness dashboard and must not invent health metrics.

## Apple platform baseline

Follow current macOS Human Interface Guidelines and system UI conventions.

- Native SwiftUI/AppKit controls first.
- Liquid Glass only where macOS provides it naturally in navigation/functional chrome.
- No fake glass cards in the content layer.
- Desktop density, not enlarged iOS cards.
- System typography and SF Symbols.
- Standard focus, keyboard and VoiceOver behavior.
- Support light/dark appearance, Increase Contrast, Reduce Transparency, Reduce Motion and Show Borders.
- No fake title bars, fake traffic lights, web-dashboard chrome or mobile navigation.

## Brand palette

Reuse the personal-site palette, adapted semantically to macOS system surfaces.

Source: `EtienneDeneuve/etiennedeneuve.github.io/src/styles/global.css`.

### Light
- ink: `#151819`
- muted ink: `#454A4D`
- subtle ink: `#6B7073`
- paper: `#F3EFE7`
- elevated paper: `#FAF8F3`
- muted paper: `#E8E3D8`
- copper accent: `#A54822`
- copper hover/secondary: `#C45A2E`
- success: `#0F7A4C`
- danger: `#B42318`

### Dark
- graphite: `#111416`
- graphite elevated: `#1B1E20`
- text: `#F7F3EC`
- muted text: `#CDD0CF`
- copper accent: `#F0AA78`
- success: `#3DD68C`
- danger: `#F97066`

Do not hard-code the website background onto every native surface. Use system materials/backgrounds and apply these as brand/accent semantics.

## Shared state language

- neutral/system: working, paused, presentation deferral
- copper/amber: break due, movement debt, attention
- green: standing detected, verified, completed
- red: permission/error/destructive only

Never use green just because the camera is running.

## 1. Menu bar

Keep the surface compact and command-oriented.

Target:

```
Next break                 18 min
Sitting                     32 min
─────────────────────────────────
▶ Start Break Now
  Postpone                       ›
  Presentation Mode              ›
  Pause Schedule
─────────────────────────────────
Today · 3 completed · 4 min
─────────────────────────────────
Settings…
About Unchair
Check for Updates…
Quit Unchair
```

Attention state:

```
Break due                    NOW
Movement debt              24 min
─────────────────────────────────
▶ Start 90s Break
  Postpone                       ›
  ...
```

Rules:
- no hero card
- no large branding
- no weekly dashboard here
- one visually dominant command
- preserve menu behavior and keyboard navigation

## 2. Today

Keep the current information architecture.

```
Unchair

AT DESK
32 min
Next break in 18 min

TODAY
3 completed   1 skipped   4 min moved   52 min longest

──────────────────────────────────────────

HUMAN RUNTIME · WEEK 46

Sitting SLO     92.4%      Debt peak      24 min
Completed           18      Postponed           7
MTTB              6m12s

SEV-2 · Glute availability degradation

[Copy Image] [Save PNG…]                  Tue, Nov 10
```

Debt state:

```
MOVEMENT DEBT
24 min
Postpone keeps debt. Complete clears it.

Break owed now — stand when you can
```

Active break state:

```
ON BREAK
00:42
Local movement check — frames stay on this Mac.

Finish the movement check to clear this break
```

Rules:
- approximately current 420 pt content width
- no sidebar
- Today metrics stay one aligned strip
- Human Runtime is the single grouped content surface
- export actions stay subordinate

## 3. Break overlay

### Break due

Camera must still be off.

```
              [figure.stand]

    You've been sitting for 52 minutes.
              Move your ass.

          Break · 90 seconds

         [ Start 90s break ]

             Skip for now

   Postpone 15 min      Quit Unchair

Esc postpones 15 minutes · ⌘Q quits Unchair
```

### Active verification

```
                    BREAK
                 00:42 left

            Stand up. Keep moving.

    ┌────────────────────────────────┐
    │      live mirrored camera      │
    │   + Apple Vision body pose     │
    └────────────────────────────────┘

      Camera on · posture detected
      On-device · frames are not saved

                  Standing
            Keep moving to verify

              [ Keep moving… ]

                Skip for now
```

### Verified

```
                    BREAK
                 00:08 left

                 ✓ Verified
          Movement requirement met

              [ Mark complete ]
```

### Camera unavailable

```
                    BREAK
                 00:42 left

            Camera unavailable
 You can still complete the break manually.

              [ Mark complete ]
```

### Verification opted out (Reminders only)

```
                    BREAK
                 00:42 left

         Camera verification off
      Mark complete when ready

              [ Mark complete ]
```

Rules:
- full-screen interruption remains intentional
- dark graphite/HUD-like surface, not a wellness gradient
- camera remains evidence, not hero content
- preview roughly keeps existing 560 × 320 proportions
- simplify Vision skeleton to a restrained semantic treatment
- timer uses monospaced digits
- no rings, scores, charts or gamification
- real overlay states include: waiting, pending movement, capturing, standing detected, permission denied, camera busy, camera unavailable, verification opted out, verified
- denied / busy / unavailable show a recovery CTA to System Settings → Camera; completion stays fail-open

## 4. Settings

Keep native macOS settings patterns.

### General
- Work interval
- Break duration
- Pause when idle
- Launch at login
- Postpone until
- History / Clear

### Verification
Rename the current Camera pane.

```
Verification

CAMERA
Camera access                               Allowed
Movement verification                      Available

[ live camera preview + subtle Vision skeleton ]

Posture                                    Standing
Camera live · body pose detected

✓ Processed on-device.
  Camera frames and body landmarks are not stored or uploaded.

[Test Camera]
```

### Integrations
Keep the real features:
- MQTT/Home Assistant enablement
- host / port / TLS / username / Keychain password
- HA discovery
- connection state / device ID / Test connection
- OpenMetrics enablement
- port / LAN exposure / status

### About
Keep version/update/product information.

## 5. First-run onboarding

### Shipped (#109)

A single Welcome window covers the #109 acceptance criteria. It is already in the product.

```
[Unchair icon]

Welcome to Unchair
Local-first break reminders for your Mac. No account. No cloud.

Break reminders
When a break is due, Unchair shows a hard-to-ignore overlay.
Reminders work without the camera.

Launch Unchair at login                  [OFF]
Keeps the break loop running after restart.
(opt-in — mirrors real ServiceManagement state)

Optional movement verification
Unchair can use the Mac camera to check sit → stand locally.
Frames stay in memory and are never saved or uploaded.

Where things live
Menu bar → Today, Settings, or Quit.

[Reminders only]          [Enable camera verification]
```

Rules already enforced in code:
- no auto camera prompt at process launch
- explain before any system camera sheet
- camera remains optional and reversible from Settings → Camera and Today recovery
- Reminders only leaves the core break loop usable without starting capture (`verificationOptedOut`)
- launch at login is opt-in; never silently register a login item
- existing installs that already answered the system camera prompt migrate quietly (no re-wizard)

### Target polish (under #118)

A longer multi-step wizard remains optional polish after visual approval — not a blocker for #109:

1. Welcome
2. Choose default rhythm (work / break duration)
3. Camera verification (dedicated step)
4. Launch at login (dedicated step)
5. Ready summary + Open Today

Until that polish lands, keep the shipped single Welcome window. Do not regress to a launch-time permission nag.

### Onboarding behavior (invariant)

- shown once after clean install / first-run state
- can be reopened from About or Settings if useful
- never requires account creation
- integrations are not part of onboarding
- no marketing carousel
- no telemetry consent because core product does not require telemetry
- no HealthKit / iPhone / Watch setup in the Mac standalone wizard
- permissions requested just-in-time after an explanatory screen
- every optional choice remains reversible

## 6. Copy rules

Keep the current dry Unchair tone.

Good:
- `You've been sitting for 52 minutes.`
- `Move your ass.`
- `Postponed. Debt preserved.`
- `Movement verified.`
- `On-device · frames are not saved.`

Avoid:
- motivational coaching
- medical claims
- posture scores
- streaks
- “great job!”
- fake health insights

## 7. Implementation boundaries

UI work must not change:
- BreakEngine state semantics
- movement debt semantics
- presentation guard
- fail-open behavior
- local-only camera processing
- Today aggregation
- Human Runtime metrics
- MQTT/OpenMetrics behavior

The onboarding implementation may change **when** camera permission is requested because #109 explicitly requires an understandable first launch. It must not change what camera data is processed or persisted.

## Delivery split

After visual approval, implement as child work under #118:

1. menu-bar polish
2. Today + Human Runtime polish
3. break overlay redesign
4. Settings + Verification redesign
5. optional multi-step onboarding polish (single Welcome already shipped in #109)
6. accessibility/appearance regression pass
7. screenshot/documentation refresh

## Acceptance criteria

- [ ] Mac desktop only for current release
- [ ] wizard included
- [ ] every existing surface maps to real repo behavior
- [ ] no invented posture score
- [ ] personal-site graphite / ivory / copper palette applied semantically
- [ ] current Apple macOS HIG followed
- [ ] camera permission is explained before request in first-run flow
- [ ] camera remains optional
- [ ] menu bar remains compact
- [ ] Today preserves real metrics
- [ ] overlay preserves real verification states
- [ ] Settings preserves real capabilities
- [ ] accessibility appearance modes validated

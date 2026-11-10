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

Rules:
- full-screen interruption remains intentional
- dark graphite/HUD-like surface, not a wellness gradient
- camera remains evidence, not hero content
- preview roughly keeps existing 560 × 320 proportions
- simplify Vision skeleton to a restrained semantic treatment
- timer uses monospaced digits
- no rings, scores, charts or gamification

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

## 5. First-run wizard / onboarding

This is required by #109 and is part of the coherent UX, even though it is not implemented yet.

The wizard must be short, native, skippable where technically optional and recoverable later from Settings.

### Step 1 — Welcome

```
[Unchair icon]

Unchair
A mildly annoying reminder that checks whether you actually moved.

No account.
No cloud.
No wellness dashboard.

                         [Continue]
```

### Step 2 — Choose the default rhythm

```
Set your rhythm

Work interval        [ 50 min ]
Break duration       [ 90 sec ]

You can change this anytime in Settings.

[Back]                   [Continue]
```

Use native controls. Do not turn this into a questionnaire.

### Step 3 — Camera verification

```
Movement verification

Unchair can use your Mac camera to check that you stood up and moved.

[ camera / figure illustration ]

Processed on-device.
Frames and body landmarks are not stored or uploaded.

[Not now]         [Enable Camera]
```

Rules:
- explain before triggering the macOS permission dialog
- camera remains optional
- `Not now` must leave the core break loop usable
- denial must be recoverable from Verification settings
- no surprise permission prompt on first process launch before this explanation

This implies the current launch camera priming flow must be reconciled with onboarding implementation in #109; do not silently preserve a permission prompt that appears before the wizard explains it.

### Step 4 — Launch at login

```
Keep Unchair running

Unchair works best when it starts with your Mac.

Launch Unchair at login                  [ON]

[Back]                   [Continue]
```

Use the real ServiceManagement state. Do not claim enabled if macOS rejects it.

### Step 5 — Ready

```
You're set.

Next break in 50 min

Camera verification       Enabled
Launch at login            Enabled

Unchair lives in your menu bar.

[Open Today]                         [Done]
```

If camera is skipped:

```
Camera verification       Off
Break reminders still work normally.
```

### Wizard behavior

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

After visual approval, implement as child work under #118 / #109:

1. menu-bar polish
2. Today + Human Runtime polish
3. break overlay redesign
4. Settings + Verification redesign
5. first-run wizard
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

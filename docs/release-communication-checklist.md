# Public release communication checklist

Repeatable, technical checklist for a **stable** Unchair release.

This is the public companion to [`RELEASE.md`](./RELEASE.md) (build / sign / notarize / publish).
It covers what must be true **before** people are pointed at the release, and what the
public package must contain.

## Out of scope (do not store here)

- Audience targets, campaign calendars, influencer lists
- Paid ads, private Slack/Discord blast plans
- Growth hypotheses or “go-to-market” strategy

Those stay outside this repository. Public work may track **artifact downloads** and
**issue feedback** only.

## When to run

Run this checklist for every tagged Direct release (`vMAJOR.MINOR.PATCH`) after
`./scripts/release.sh` succeeds (or an equivalent signed/notarized publish).

---

## 1. Preconditions

Copy this block into the release PR / issue comment and tick as you go.

```text
Version: vX.Y.Z
Date (UTC): YYYY-MM-DD
Operator:

[ ] CI green on the commit that became the tag (Actions → CI on main / release PR)
[ ] MARKETING_VERSION in project.yml == X.Y.Z
[ ] CURRENT_PROJECT_VERSION bumped for this release
[ ] CHANGELOG.md has a ## [X.Y.Z] section (not empty Unreleased leftovers for this ship)
[ ] ./scripts/release.sh X.Y.Z completed without error
[ ] GitHub Release vX.Y.Z exists with DMG + zip + sha256 + appcast.xml
[ ] Homebrew cask EtienneDeneuve/homebrew-unchair matches X.Y.Z + DMG sha256
```

### Artifact verification (no unsupported claims)

```bash
# Gatekeeper / notarization (install from the published DMG first, or staple-check the .app)
spctl -a -vv /Applications/Unchair.app
# expected: accepted / source=Notarized Developer ID

codesign -d --entitlements :- /Applications/Unchair.app 2>/dev/null | grep -c get-task-allow
# expected: 0

# Digests for the versioned DMG from the Release assets
shasum -a 256 -c Unchair-X.Y.Z-macos.dmg.sha256
```

**Do not claim** in public notes:

- that CI signed or notarized the binary (it does not — see [`SLSA.md`](./SLSA.md))
- medical / health outcomes
- “zero bugs”, “enterprise ready”, or other unbacked superlatives
- telemetry reach or user counts we do not measure publicly

---

## 2. Install path smoke test

Verify at least **one** primary path on a clean-ish Mac (or a second user account):

```text
[ ] DMG: open Unchair-X.Y.Z-macos.dmg → drag to Applications → launch
[ ] OR Homebrew: brew install --cask EtienneDeneuve/unchair/unchair → launch
[ ] Menu bar icon appears (LSUIElement — no Dock icon by default)
[ ] Open Today (menu) — window appears without crash
[ ] Open Settings — Schedule / Camera / Integrations / About load
[ ] About shows version X.Y.Z and the Direct channel label
[ ] Optional: unchair doctor (CLI) exits 0 against the running app
```

If Sparkle shipped a zip for this version:

```text
[ ] Existing Direct install offers / accepts update, or Check for Updates… finds X.Y.Z
```

---

## 3. Docs match the shipped release

```text
[ ] README install links resolve (latest DMG + Homebrew instructions)
[ ] README “What ships today” does not describe unreleased behavior
[ ] docs/PRIVACY.md still accurate if this release touched camera / history / export / MQTT
[ ] docs/DISTRIBUTION.md channel claims match what you published (Direct vs MAS)
[ ] Feature docs for anything new in CHANGELOG are linked (e.g. human-runtime-weekly-card.md)
[ ] Repository metadata still sane (description, topics, homepage) — docs/repository-metadata.md
```

Update product screenshots / tour GIF **only when UI behavior changed** in this release:

```text
[ ] N/A — no user-visible UI change
[ ] OR docs/assets/screenshots/ + README media refreshed and privacy-scrubbed
    (see docs/assets/README.md rules)
```

---

## 4. Public release package

GitHub Release body should be readable by a stranger who never saw the repo.

Minimum contents (already partially filled by `release.sh` from CHANGELOG):

```text
[ ] Title: Unchair X.Y.Z
[ ] Concise notes from CHANGELOG ## [X.Y.Z] (Added / Changed / Fixed)
[ ] Install steps (DMG + optional Homebrew)
[ ] Verify commands (spctl / shasum) present
[ ] Links: CHANGELOG, PRIVACY, DISTRIBUTION
[ ] Known limitations called out when relevant (examples below)
```

### Known limitations (pick what applies — do not invent)

Use only limitations that are true for this build:

- macOS 14+ only
- Camera permission required for movement verification; breaks still schedule without it
- MQTT / OpenMetrics / tracing are optional; a dead broker must not break the core loop
- Human Runtime card is local-history only — never auto-posted
- MAS builds (if any) do not use Sparkle

---

## 5. Post-publish hygiene

```text
[ ] Tag vX.Y.Z pushed and matches the Release
[ ] Casks/unchair.rb committed on main with the new version + sha256
[ ] SLSA attestation workflow finished or noted as digest-only (docs/SLSA.md)
[ ] Parent distribution epic updated if this closed a child (#82 / related)
[ ] No private GTM notes committed “for convenience”
```

---

## 6. Measurement boundary (public only)

Allowed to observe after publish:

- GitHub Release asset download counts
- Issues / discussions filed against the version
- Homebrew tap traffic if exposed by GitHub insights

Not allowed in this repo:

- shipping pixel trackers, invasive analytics, or dark-pattern engagement hooks
- storing private campaign metrics in issues or docs

---

## Worked example

`v0.4.0` (2026-11-10) used this shape: CHANGELOG section → `release.sh` → notarized DMG →
Homebrew cask publish → Release notes with install + verify. Follow-up UI/docs for Human
Runtime live under [`human-runtime-weekly-card.md`](./human-runtime-weekly-card.md) and
[`docs/assets/today-ui/`](./assets/today-ui/).

---

## Related

- Build / sign / notarize: [`RELEASE.md`](./RELEASE.md)
- Channels + Sparkle + Homebrew: [`DISTRIBUTION.md`](./DISTRIBUTION.md)
- Privacy contract: [`PRIVACY.md`](./PRIVACY.md)
- SLSA boundary: [`SLSA.md`](./SLSA.md)
- Repo discoverability: [`repository-metadata.md`](./repository-metadata.md)

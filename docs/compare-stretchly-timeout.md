# Unchair vs Stretchly vs Time Out

Honest, first-party comparison for people shopping macOS break reminders.

**Canonical pages (FR + EN, SEO + JSON-LD):**

- EN: https://etienne.deneuve.xyz/en/unchair/compare/
- FR: https://etienne.deneuve.xyz/unchair/compare/

Disclosure: Étienne Deneuve builds Unchair. Stretchly / Time Out facts are taken from their public product docs (checked 2026-11-10). No fake winner, no medical claims.

## Useful shortcut

| If you need… | Prefer… |
| --- | --- |
| Cross-platform (macOS / Windows / Linux) | **Stretchly** |
| Deep scheduling, themes, rules on Mac | **Time Out** |
| Local sit→stand / movement verification | **Unchair** |

## Factual table

| Criterion | Unchair | Stretchly | Time Out |
| --- | --- | --- | --- |
| Platforms | macOS 14+ | macOS 13+, Windows, Linux | Time Out 4.x: macOS 26+ (Tahoe); older OS → 2.9.x |
| Break model | Configurable breaks + movement debt | Configurable mini + long breaks | Highly configurable breaks and schedules |
| Verifies that you moved | Yes — sit→stand + movement via Apple Vision on-device | No documented body-movement verification | No documented body-movement verification |
| Meetings / context | Presentation guard + lock / sleep / idle | Idle, Do Not Disturb, app exclusions | Rules, fullscreen, configurable meeting detection |
| Open source | MIT | BSD-2-Clause | Proprietary |
| Price | Free | Free / open source | Free core + Premium / Supporter / Lifetime options |
| Home Assistant | Native MQTT Discovery + constrained commands | No native integration documented | No native integration documented |
| Observability | Optional OpenMetrics / Prometheus + OpenTelemetry | Not a product feature | Not a product feature |
| macOS distribution | Notarized Developer ID DMG + Sparkle + Homebrew cask | Homebrew; ad-hoc signed app | Native Dejal distribution |

## Sources

- Unchair: this repository / [PRIVACY.md](./PRIVACY.md) / [releases](https://github.com/EtienneDeneuve/unchair/releases)
- Stretchly: https://github.com/hovancik/stretchly · https://hovancik.net/stretchly/
- Time Out: https://www.dejal.com/timeout/ · [4.0 release notes](https://www.dejal.com/blog/time-out-4-0-released/)

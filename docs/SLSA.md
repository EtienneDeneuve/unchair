# SLSA posture (Unchair)

Unchair is moving toward [SLSA](https://slsa.dev/)-style release integrity **without lying about the current build boundary**.

## Current reality (honest)

| Step | Where it runs today |
| --- | --- |
| Compile / test (ad-hoc) | GitHub Actions `CI` |
| Developer ID sign + notarize + staple | **Release Mac** (`scripts/release.sh`) |
| GitHub Release upload (DMG / zip / appcast) | Release Mac (`gh release create`) |
| Homebrew cask bump | Release Mac / follow-up commit |
| Digest attestation (SLSA generic) | GitHub Actions `Release attestations (SLSA)` |

CI **cannot** yet produce the notarized Direct-channel binaries. Do not treat a green `CI` workflow as a signed release.

## What we do ship today

1. **Dependabot (daily)** — `.github/dependabot.yml`  
   Tracks `github-actions` updates. Opens PRs every day when Actions pins move.

2. **Sparkle watch (daily)** — `.github/workflows/deps-sparkle.yml`  
   Compares `Vendor/SPARKLE_VERSION` to `sparkle-project/Sparkle` latest. Opens/updates a `dependencies` issue when the vendored framework lags. Dependabot cannot see `Vendor/Sparkle.framework`.

3. **No `package-ecosystem: swift` yet** — Unchair does not ship a `Package.swift` / committed Xcode SPM lockfile. Sparkle is a vendored binary (`Vendor/Sparkle.framework`), not an SPM product dependency. Adding a Swift Dependabot feed now would be empty noise; enable it when deps move to SwiftPM and `Package.resolved` is tracked.

3. **Release asset attestation** — `.github/workflows/release-attest.yml`  
   On `release: published`, downloads the DMG + zip already attached to the release, hashes them, and asks [`slsa-github-generator`](https://github.com/slsa-framework/slsa-github-generator) (generic SLSA3) to attest those digests and upload `*-slsa-provenance.intoto.jsonl` to the release.

   That provenance means: *these byte digests were observed and attested by GitHub Actions after publish*.  
   It does **not** mean: *GitHub Actions compiled or notarized Unchair*.

## Verify a release attestation

```bash
TAG=v0.3.4
gh release download "$TAG" --pattern '*-slsa-provenance.intoto.jsonl'
# Inspect subjects / predicate builder.id before relying on it.
```

Also keep the classic checksums:

```bash
gh release download "$TAG" --pattern '*.sha256'
shasum -a 256 -c Unchair-*-macos.dmg.sha256
shasum -a 256 -c Unchair-*-macos.zip.sha256
```

## Roadmap (when CI can sign)

Only then raise the bar:

1. Move Developer ID + notary credentials into a protected `release` Environment (never PR `CI`).
2. Build + notarize in Actions; attach artifacts from that job.
3. Feed **CI-produced** digests into the SLSA generator (provenance builder = the release workflow).
4. Optionally add SBOM (`syft` / CycloneDX) next to the provenance.

Until that migration lands, keep `scripts/release.sh` as the source of signed bits and keep this attestation workflow labeled as post-publish verification.

## Related

- [`DISTRIBUTION.md`](./DISTRIBUTION.md) — Direct vs MAS channels  
- [`RELEASE.md`](./RELEASE.md) — secrets boundary  
- [`PRIVACY.md`](./PRIVACY.md) — Sparkle network behavior on Direct builds  

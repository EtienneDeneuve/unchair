#!/usr/bin/env bash
# Build, Developer ID–sign, notarize, staple, and publish a GitHub Release.
# Secrets stay on the release Mac (keychain profile) — never committed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-${VERSION:-}}"
if [[ -z "$VERSION" ]]; then
  echo "usage: $0 <semver>   # example: $0 0.1.1" >&2
  exit 1
fi
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: VERSION must be MAJOR.MINOR.PATCH (got '$VERSION')" >&2
  exit 1
fi

IDENTITY="${CODE_SIGN_IDENTITY:-Developer ID Application: ETIENNE CHARLES EDOUARD DENEUVE (H3QDKGAJ35)}"
TEAM="${DEVELOPMENT_TEAM:-H3QDKGAJ35}"
NOTARY_PROFILE="${NOTARY_PROFILE:-omnivya}"
DERIVED="${DERIVED_DATA_PATH:-/tmp/UnchairRelease-$VERSION}"
TAG="v${VERSION}"
ZIP="/tmp/Unchair-${VERSION}-macos.zip"
SHA="$ZIP.sha256"

echo "[release] version=$VERSION identity=$IDENTITY notary=$NOTARY_PROFILE"

command -v gh >/dev/null || { echo "error: gh CLI required" >&2; exit 1; }
command -v xcodebuild >/dev/null || { echo "error: xcodebuild required" >&2; exit 1; }

rm -rf "$DERIVED"
xcodebuild -scheme Unchair -configuration Release \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM" \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO

APP="$DERIVED/Build/Products/Release/Unchair.app"
test -d "$APP"

echo "[release] verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"
ENTITLEMENTS="$(codesign -d --entitlements :- "$APP" 2>/dev/null || true)"
if echo "$ENTITLEMENTS" | grep -q 'get-task-allow'; then
  echo "error: get-task-allow present — notarization will fail" >&2
  exit 1
fi

NOTARY_ZIP="/tmp/Unchair-${VERSION}-notarize.zip"
rm -f "$NOTARY_ZIP"
ditto -c -k --keepParent "$APP" "$NOTARY_ZIP"

echo "[release] submitting to notarytool (profile=$NOTARY_PROFILE)"
xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "[release] stapling"
xcrun stapler staple "$APP"
spctl -a -vv "$APP"

rm -f "$ZIP" "$SHA"
ditto -c -k --keepParent "$APP" "$ZIP"
shasum -a 256 "$ZIP" | tee "$SHA"

NOTES="$(mktemp)"
# Prefer the matching section from CHANGELOG.md when present.
if [[ -f "$ROOT/CHANGELOG.md" ]] && awk -v ver="$VERSION" '
  $0 ~ "^## \\[" ver "\\]" {grab=1; print; next}
  grab && $0 ~ /^## \[/ {exit}
  grab {print}
' "$ROOT/CHANGELOG.md" >"$NOTES" && [[ -s "$NOTES" ]]; then
  {
    echo ""
    echo "---"
    echo ""
    echo "Developer ID signed, notarized, and stapled (team \`${TEAM}\`)."
    echo ""
    echo "### Install"
    echo "1. Download \`Unchair-${VERSION}-macos.zip\`, unzip"
    echo "2. Move \`Unchair.app\` to \`/Applications\`"
    echo "3. Open Unchair"
    echo ""
    echo "### Verify"
    echo '```bash'
    echo "spctl -a -vv Unchair.app"
    echo "shasum -a 256 -c Unchair-${VERSION}-macos.zip.sha256"
    echo '```'
    echo ""
    echo "Full history: [CHANGELOG.md](https://github.com/EtienneDeneuve/unchair/blob/main/CHANGELOG.md) · Privacy: [docs/PRIVACY.md](https://github.com/EtienneDeneuve/unchair/blob/main/docs/PRIVACY.md)"
  } >>"$NOTES"
else
  cat >"$NOTES" <<EOF
## Unchair ${VERSION}

Developer ID signed, notarized, and stapled (team \`${TEAM}\`).

Add a \`## [${VERSION}]\` section to CHANGELOG.md before releasing so notes stay useful.

### Install
1. Download \`Unchair-${VERSION}-macos.zip\`, unzip
2. Move \`Unchair.app\` to \`/Applications\`
3. Open Unchair

### Verify
\`\`\`bash
spctl -a -vv Unchair.app
shasum -a 256 -c Unchair-${VERSION}-macos.zip.sha256
\`\`\`

Privacy: see docs/PRIVACY.md
EOF
fi

if gh release view "$TAG" >/dev/null 2>&1; then
  echo "[release] deleting existing GitHub release $TAG"
  gh release delete "$TAG" --yes
  git push origin ":refs/tags/$TAG" 2>/dev/null || true
  git tag -d "$TAG" 2>/dev/null || true
fi

echo "[release] creating GitHub release $TAG"
gh release create "$TAG" "$ZIP" "$SHA" \
  --title "Unchair ${VERSION}" \
  --notes-file "$NOTES"

rm -f "$NOTES" "$NOTARY_ZIP"
echo "[release] ok → $(gh release view "$TAG" --json url -q .url)"

#!/usr/bin/env bash
# Stub: archive the App Store channel and prepare an ASC upload.
# Full automation lands with GitHub Environment secrets (ASC API key + certs).
# See docs/DISTRIBUTION.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-${VERSION:-}}"
if [[ -z "$VERSION" ]]; then
  echo "usage: $0 <semver>" >&2
  exit 1
fi

DERIVED="${DERIVED_DATA_PATH:-/tmp/UnchairMAS-$VERSION}"
TEAM="${DEVELOPMENT_TEAM:-H3QDKGAJ35}"

echo "[release-mas] building AppStore configuration (no upload yet)"
rm -rf "$DERIVED"
xcodegen generate
xcodebuild archive \
  -scheme Unchair-MAS \
  -configuration AppStore \
  -archivePath "$DERIVED/Unchair.xcarchive" \
  -destination 'generic/platform=macOS' \
  DEVELOPMENT_TEAM="$TEAM"

echo "[release-mas] archive ready: $DERIVED/Unchair.xcarchive"
echo "[release-mas] next: export with App Store export options + Transporter / altool"
echo "[release-mas] What’s New: copy ## [$VERSION] from CHANGELOG.md into ASC"
exit 0

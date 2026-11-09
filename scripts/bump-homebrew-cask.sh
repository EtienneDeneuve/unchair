#!/usr/bin/env bash
# Update Casks/unchair.rb to the given SemVer + DMG sha256.
# Usage:
#   ./scripts/bump-homebrew-cask.sh 0.3.4
#   ./scripts/bump-homebrew-cask.sh 0.3.4 /tmp/Unchair-0.3.4-macos.dmg
#   DMG_SHA256=… ./scripts/bump-homebrew-cask.sh 0.3.4
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CASK="$ROOT/Casks/unchair.rb"
VERSION="${1:-}"
DMG_PATH="${2:-}"

if [[ -z "$VERSION" || ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: $0 <semver> [path-to-dmg]" >&2
  exit 1
fi

if [[ -n "${DMG_SHA256:-}" ]]; then
  SHA="$DMG_SHA256"
elif [[ -n "$DMG_PATH" && -f "$DMG_PATH" ]]; then
  SHA="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
elif [[ -f "/tmp/Unchair-${VERSION}-macos.dmg.sha256" ]]; then
  SHA="$(awk '{print $1}' "/tmp/Unchair-${VERSION}-macos.dmg.sha256")"
elif [[ -f "/tmp/Unchair-${VERSION}-macos.dmg" ]]; then
  SHA="$(shasum -a 256 "/tmp/Unchair-${VERSION}-macos.dmg" | awk '{print $1}')"
else
  URL="https://github.com/EtienneDeneuve/unchair/releases/download/v${VERSION}/Unchair-${VERSION}-macos.dmg.sha256"
  echo "[cask] fetching $URL"
  SHA="$(curl -fsSL "$URL" | awk '{print $1}')"
fi

if [[ ! "$SHA" =~ ^[a-f0-9]{64}$ ]]; then
  echo "error: invalid sha256 '$SHA'" >&2
  exit 1
fi

tmp="$(mktemp)"
python3 - "$CASK" "$VERSION" "$SHA" <<'PY' >"$tmp"
from pathlib import Path
import re, sys
path, version, sha = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
text = path.read_text()
text = re.sub(r'version "[^"]+"', f'version "{version}"', text, count=1)
text = re.sub(r'sha256 "[^"]+"', f'sha256 "{sha}"', text, count=1)
sys.stdout.write(text)
PY
mv "$tmp" "$CASK"
echo "[cask] updated $CASK → version=$VERSION sha256=$SHA"

echo "[cask] source updated: $CASK"
echo "[cask] publish with:"
echo "  bash ./scripts/publish-homebrew-cask.sh $VERSION"
echo "[cask] install:"
echo "  brew install --cask EtienneDeneuve/unchair/unchair"

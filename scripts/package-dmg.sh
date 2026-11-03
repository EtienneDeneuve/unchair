#!/usr/bin/env bash
# Build a styled UDZO DMG: Unchair.app + Applications shortcut (drag-to-install).
# Usage: package-dmg.sh /path/to/Unchair.app /path/to/Unchair-X.Y.Z.dmg
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-}"
OUT_DMG="${2:-}"

if [[ -z "$APP" || -z "$OUT_DMG" ]]; then
  echo "usage: $0 <Unchair.app> <output.dmg>" >&2
  exit 1
fi
if [[ ! -d "$APP" ]]; then
  echo "error: app not found: $APP" >&2
  exit 1
fi

VOL_NAME="Unchair"
WINDOW_W=660
WINDOW_H=400
ICON_SIZE=128
# Icon centers inside the Finder window (points).
APP_X=180
APP_Y=168
APPS_X=480
APPS_Y=168

BG_SRC="$ROOT/docs/assets/dmg/background.png"
if [[ ! -f "$BG_SRC" ]]; then
  echo "[dmg] generating background"
  python3 "$ROOT/scripts/generate-dmg-background.py" -o "$BG_SRC"
fi

STAGE="$(mktemp -d /tmp/unchair-dmg-stage.XXXXXX)"
RW_DMG="$(mktemp /tmp/unchair-dmg-rw.XXXXXX).dmg"
MOUNT=""

cleanup() {
  if [[ -n "$MOUNT" && -d "$MOUNT" ]]; then
    hdiutil detach "$MOUNT" -quiet || hdiutil detach "$MOUNT" -force || true
  fi
  rm -rf "$STAGE"
  rm -f "$RW_DMG"
}
trap cleanup EXIT

echo "[dmg] staging"
ditto "$APP" "$STAGE/Unchair.app"
ln -s /Applications "$STAGE/Applications"
mkdir -p "$STAGE/.background"
ditto "$BG_SRC" "$STAGE/.background/background.png"

echo "[dmg] creating RW image"
rm -f "$RW_DMG"
hdiutil create \
  -srcfolder "$STAGE" \
  -volname "$VOL_NAME" \
  -fs HFS+ \
  -fsargs "-c c=64,a=16,e=16" \
  -format UDRW \
  -size 200m \
  "$RW_DMG" >/dev/null

echo "[dmg] mounting"
MOUNT_OUT="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG")"
MOUNT="$(echo "$MOUNT_OUT" | awk '/\/Volumes\//{print $NF; exit}')"
if [[ -z "$MOUNT" || ! -d "$MOUNT" ]]; then
  echo "error: failed to mount $RW_DMG" >&2
  echo "$MOUNT_OUT" >&2
  exit 1
fi

# Bless Finder look: icon positions + background.
echo "[dmg] applying Finder layout"
osascript <<EOF
tell application "Finder"
  tell disk "$VOL_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {120, 120, $((120 + WINDOW_W)), $((120 + WINDOW_H))}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to $ICON_SIZE
    set background picture of viewOptions to file ".background:background.png"
    set position of item "Unchair.app" of container window to {$APP_X, $APP_Y}
    set position of item "Applications" of container window to {$APPS_X, $APPS_Y}
    update without registering applications
    delay 1
    close
    open
    delay 1
    close
  end tell
end tell
EOF

sync
hdiutil detach "$MOUNT" -quiet
MOUNT=""

echo "[dmg] compressing → $OUT_DMG"
rm -f "$OUT_DMG"
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$OUT_DMG" >/dev/null
hdiutil internet-enable -yes "$OUT_DMG" >/dev/null 2>&1 || true

echo "[dmg] ok $(du -h "$OUT_DMG" | awk '{print $1}')"

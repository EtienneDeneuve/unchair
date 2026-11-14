#!/usr/bin/env bash
# Archive → export → validate → (optional) upload the Mac App Store channel.
#
# Secrets stay on the release Mac or in GitHub Environment `mas-release` — never commit them.
# See docs/RELEASE-MAS.md.
#
# Usage:
#   ./scripts/release-mas.sh 1.0.0
#   UPLOAD=1 ./scripts/release-mas.sh 1.0.0          # export + upload to ASC
#   UPLOAD=0 ./scripts/release-mas.sh 1.0.0          # archive+export only (default)
#
# ASC API auth (one of):
#   ASC_KEYCHAIN_PROFILE=omnivya          # notarytool-compatible keychain profile with ASC API key
#   or ASC_API_KEY_ID + ASC_API_ISSUER_ID + ASC_API_KEY_PATH (.p8)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-${VERSION:-}}"
if [[ -z "$VERSION" ]]; then
  echo "usage: $0 <semver>   # example: $0 1.0.0" >&2
  exit 1
fi
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: VERSION must be MAJOR.MINOR.PATCH (got '$VERSION')" >&2
  exit 1
fi

UPLOAD="${UPLOAD:-0}"
TEAM="${DEVELOPMENT_TEAM:-H3QDKGAJ35}"
DERIVED="${DERIVED_DATA_PATH:-/tmp/UnchairMAS-$VERSION}"
ARCHIVE="$DERIVED/Unchair.xcarchive"
EXPORT_DIR="$DERIVED/export"
EXPORT_OPTIONS="${EXPORT_OPTIONS_PLIST:-$ROOT/scripts/ExportOptions-mas.plist}"
NOTES="$DERIVED/whats-new.txt"
STATE="$DERIVED/release-state.txt"

fail() {
  echo "error: $*" >&2
  echo "FAILED $(date -u +%Y-%m-%dT%H:%M:%SZ) $*" >>"$STATE" 2>/dev/null || true
  exit 1
}

mark() {
  echo "$*"
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" >>"$STATE"
}

command -v xcodegen >/dev/null || fail "xcodegen required (brew install xcodegen)"
command -v xcodebuild >/dev/null || fail "xcodebuild required"

rm -rf "$DERIVED"
mkdir -p "$DERIVED"
: >"$STATE"
mark "[release-mas] start version=$VERSION upload=$UPLOAD team=$TEAM"

# --- Preconditions -----------------------------------------------------------
MARKETING="$(sed -n 's/.*MARKETING_VERSION: "\([^"]*\)".*/\1/p' project.yml | head -1)"
BUILD="$(sed -n 's/.*CURRENT_PROJECT_VERSION: "\([^"]*\)".*/\1/p' project.yml | head -1)"
[[ -n "$MARKETING" && -n "$BUILD" ]] || fail "could not read MARKETING_VERSION / CURRENT_PROJECT_VERSION from project.yml"
[[ "$MARKETING" == "$VERSION" ]] || fail "project.yml MARKETING_VERSION=$MARKETING does not match requested $VERSION — bump before releasing"

if [[ -f CHANGELOG.md ]]; then
  awk -v ver="$VERSION" '
    $0 ~ "^## \\[" ver "\\]" {grab=1; print; next}
    grab && $0 ~ /^## \[/ {exit}
    grab {print}
  ' CHANGELOG.md >"$NOTES"
fi
[[ -s "$NOTES" ]] || fail "CHANGELOG.md missing ## [$VERSION] section (What’s New source)"

mark "[release-mas] marketing=$MARKETING build=$BUILD changelog_ok"

# --- Generate + archive ------------------------------------------------------
xcodegen generate
mark "[release-mas] archiving Unchair-MAS (AppStore)"

# Prefer Apple Distribution when present; otherwise Automatic + DEVELOPMENT_TEAM
# (Xcode manages profiles). Do not fall back to Developer ID — that is Direct-only.
DIST_IDENTITY="${CODE_SIGN_IDENTITY:-}"
if [[ -z "$DIST_IDENTITY" ]]; then
  if security find-identity -v -p codesigning 2>/dev/null | grep -q 'Apple Distribution:'; then
    DIST_IDENTITY="Apple Distribution: ETIENNE CHARLES EDOUARD DENEUVE ($TEAM)"
  fi
fi

ARCHIVE_ARGS=(
  archive
  -scheme Unchair-MAS
  -configuration AppStore
  -archivePath "$ARCHIVE"
  -destination 'generic/platform=macOS'
  -derivedDataPath "$DERIVED/DerivedData"
  DEVELOPMENT_TEAM="$TEAM"
)
if [[ -n "$DIST_IDENTITY" ]]; then
  ARCHIVE_ARGS+=(
    CODE_SIGN_STYLE=Manual
    CODE_SIGN_IDENTITY="$DIST_IDENTITY"
  )
  mark "[release-mas] signing identity=$DIST_IDENTITY"
else
  ARCHIVE_ARGS+=(CODE_SIGN_STYLE=Automatic)
  mark "[release-mas] signing style=Automatic (install Apple Distribution cert for CI/repro)"
fi

xcodebuild "${ARCHIVE_ARGS[@]}" || fail "xcodebuild archive failed — refusing to claim a release"

APP_IN_ARCHIVE="$ARCHIVE/Products/Applications/Unchair.app"
[[ -d "$APP_IN_ARCHIVE" ]] || fail "archive missing Unchair.app"

# Sparkle must not ship in the MAS product.
if [[ -d "$APP_IN_ARCHIVE/Contents/Frameworks/Sparkle.framework" ]]; then
  fail "Sparkle.framework present in AppStore archive — UnchairAppStore target must not link Sparkle"
fi

# Entitlements sanity (when codesigned).
if codesign -d --entitlements :- "$APP_IN_ARCHIVE" &>/dev/null; then
  ENT="$(codesign -d --entitlements :- "$APP_IN_ARCHIVE" 2>/dev/null || true)"
  echo "$ENT" | grep -q 'com.apple.security.app-sandbox' || fail "archived app missing app-sandbox entitlement"
  if echo "$ENT" | grep -q 'com.apple.security.network.server'; then
    fail "archived app has network.server — MAS gate forbids it (#138)"
  fi
fi

mark "[release-mas] archive ok → $ARCHIVE"

# --- Export ------------------------------------------------------------------
mkdir -p "$EXPORT_DIR"
EXPORT_PLIST="$DERIVED/ExportOptions.plist"
cp "$EXPORT_OPTIONS" "$EXPORT_PLIST"
if [[ "$UPLOAD" == "1" ]]; then
  /usr/libexec/PlistBuddy -c 'Set :destination upload' "$EXPORT_PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c 'Add :destination string upload' "$EXPORT_PLIST"
  mark "[release-mas] export destination=upload"
else
  /usr/libexec/PlistBuddy -c 'Set :destination export' "$EXPORT_PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c 'Add :destination string export' "$EXPORT_PLIST"
  mark "[release-mas] export destination=export (set UPLOAD=1 to push to ASC)"
fi

AUTH_ARGS=()
if [[ -n "${ASC_API_KEY_ID:-}" && -n "${ASC_API_ISSUER_ID:-}" && -n "${ASC_API_KEY_PATH:-}" ]]; then
  AUTH_ARGS+=(
    -authenticationKeyPath "$ASC_API_KEY_PATH"
    -authenticationKeyID "$ASC_API_KEY_ID"
    -authenticationKeyIssuerID "$ASC_API_ISSUER_ID"
  )
  mark "[release-mas] using ASC API key file auth"
elif [[ -n "${ASC_KEYCHAIN_PROFILE:-}" ]]; then
  # xcodebuild does not take keychain-profile; altool/notarytool do. Keep profile for validate/upload.
  mark "[release-mas] ASC_KEYCHAIN_PROFILE=$ASC_KEYCHAIN_PROFILE (used for altool validate/upload)"
fi

mark "[release-mas] exporting"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  -allowProvisioningUpdates \
  "${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"}" \
  || fail "exportArchive failed — no ASC upload claimed"

PKG="$(find "$EXPORT_DIR" -maxdepth 1 -name '*.pkg' | head -1 || true)"
if [[ -z "$PKG" && "$UPLOAD" != "1" ]]; then
  # Some toolchains emit .pkg under a nested folder.
  PKG="$(find "$EXPORT_DIR" -name '*.pkg' | head -1 || true)"
fi

if [[ "$UPLOAD" == "1" ]]; then
  mark "[release-mas] upload requested via exportOptions destination=upload"
else
  [[ -n "$PKG" ]] || fail "export produced no .pkg under $EXPORT_DIR"
  mark "[release-mas] pkg=$PKG"

  # Optional explicit validate when API credentials exist (does not upload).
  if [[ -n "${ASC_API_KEY_ID:-}" && -n "${ASC_API_ISSUER_ID:-}" && -n "${ASC_API_KEY_PATH:-}" ]]; then
    mark "[release-mas] validating pkg with altool"
    xcrun altool --validate-app \
      --type macos \
      --file "$PKG" \
      --apiKey "$ASC_API_KEY_ID" \
      --apiIssuer "$ASC_API_ISSUER_ID" \
      || fail "altool --validate-app failed"
  elif [[ -n "${ASC_KEYCHAIN_PROFILE:-}" ]]; then
    mark "[release-mas] validate skipped for keychain-profile path — use Transporter or set ASC_API_*"
  else
    mark "[release-mas] validate skipped (no ASC API credentials) — open $PKG in Transporter"
  fi
fi

mark "[release-mas] What’s New (from CHANGELOG) → $NOTES"
sed -n '1,40p' "$NOTES"

mark "[release-mas] SUCCESS archive=$ARCHIVE export=$EXPORT_DIR"
echo ""
echo "Next (if UPLOAD=0):"
echo "  1. Transporter → deliver $PKG"
echo "  2. ASC → paste What’s New from $NOTES"
echo "  3. Ensure build $BUILD is unique for version $VERSION on ASC"
echo "Or: UPLOAD=1 ASC_API_KEY_ID=… ASC_API_ISSUER_ID=… ASC_API_KEY_PATH=… $0 $VERSION"

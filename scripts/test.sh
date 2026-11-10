#!/usr/bin/env bash
# Local build + test with ad-hoc signing (same as CI).
# Avoids login-keychain unlock prompts from Automatic / Developer ID signing.
set -euo pipefail
cd "$(dirname "$0")/.."

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
fi

xcodebuild test \
  -scheme Unchair \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGNING_ALLOWED=YES \
  "$@"

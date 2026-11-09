#!/usr/bin/env bash
# Publish the generated Unchair cask to the canonical Homebrew tap through GitHub API.
# Uses the existing authenticated gh session; no GitHub token is stored in the repository.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CASK="$ROOT/Casks/unchair.rb"
VERSION="${1:-}"
TAP_REPO="${HOMEBREW_TAP_REPO:-EtienneDeneuve/homebrew-unchair}"
TAP_PATH="${HOMEBREW_CASK_PATH:-Casks/unchair.rb}"

command -v gh >/dev/null || { echo "error: gh CLI required" >&2; exit 1; }
test -f "$CASK" || { echo "error: missing $CASK" >&2; exit 1; }

if [[ -z "$VERSION" ]]; then
  VERSION="$(sed -n 's/^  version "\([^"]*\)"/\1/p' "$CASK" | head -1)"
fi
if [[ -z "$VERSION" || ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: could not determine SemVer from $CASK" >&2
  exit 1
fi

CONTENT="$(base64 < "$CASK" | tr -d '\n')"
REMOTE_SHA="$(gh api "repos/$TAP_REPO/contents/$TAP_PATH" --jq .sha 2>/dev/null || true)"
MESSAGE="chore: bump unchair to $VERSION"

args=(
  --method PUT
  "repos/$TAP_REPO/contents/$TAP_PATH"
  -f "message=$MESSAGE"
  -f "content=$CONTENT"
)
if [[ -n "$REMOTE_SHA" ]]; then
  args+=(-f "sha=$REMOTE_SHA")
fi

echo "[cask] publishing $TAP_PATH → $TAP_REPO ($VERSION)"
gh api "${args[@]}" >/dev/null
echo "[cask] published → https://github.com/$TAP_REPO/blob/main/$TAP_PATH"

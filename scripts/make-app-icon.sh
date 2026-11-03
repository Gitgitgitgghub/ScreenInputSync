#!/bin/zsh
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SET="$ROOT_DIR/ScreenInputSync/Resources/Assets.xcassets/AppIcon.appiconset"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

swift "$ROOT_DIR/scripts/make-app-icon.swift" "$TMP/icon1024.png"
mkdir -p "$SET"
for size in 16 32 128 256 512; do
  sips -z $size $size "$TMP/icon1024.png" --out "$SET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$TMP/icon1024.png" --out "$SET/icon_${size}x${size}@2x.png" >/dev/null
done
echo "Updated $SET"

#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="${BUILD_DIR:-$ROOT_DIR/build/DerivedData}"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
APP_NAME="ScreenInputSync.app"
BUILT_APP="$DERIVED_DATA/Build/Products/Release/$APP_NAME"
INSTALLED_APP="$INSTALL_DIR/$APP_NAME"
SIGNING_IDENTITY="${CODE_SIGN_IDENTITY:-}"

command -v xcodegen >/dev/null || {
  echo "XcodeGen is required. Install it with: brew install xcodegen" >&2
  exit 1
}
command -v xcodebuild >/dev/null || {
  echo "Xcode command-line tools are required." >&2
  exit 1
}

cd "$ROOT_DIR"
xcodegen generate

if [[ -z "$SIGNING_IDENTITY" ]]; then
  SIGNING_IDENTITY="$(/usr/bin/security find-identity -v -p codesigning 2>/dev/null \
    | /usr/bin/sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' \
    | /usr/bin/head -n 1)"
fi

typeset -a SIGNING_ARGS
if [[ -n "$SIGNING_IDENTITY" ]]; then
  echo "Signing with: $SIGNING_IDENTITY"
  SIGNING_ARGS=(CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=$SIGNING_IDENTITY" CODE_SIGNING_REQUIRED=YES)
else
  echo "No Apple Development identity found; using ad-hoc signing."
  SIGNING_ARGS=(CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=YES)
fi

xcodebuild \
  -project ScreenInputSync.xcodeproj \
  -scheme ScreenInputSync \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  "${SIGNING_ARGS[@]}" \
  build

test -d "$BUILT_APP" || {
  echo "Build succeeded but $BUILT_APP was not found." >&2
  exit 1
}
test "$(/usr/bin/plutil -extract LSUIElement raw "$BUILT_APP/Contents/Info.plist")" = "true" || {
  echo "Built app is missing LSUIElement=true; refusing to install a Dock app." >&2
  exit 1
}
test -d "$INSTALL_DIR" || mkdir -p "$INSTALL_DIR"
test -w "$INSTALL_DIR" || {
  echo "$INSTALL_DIR is not writable. Re-run with an INSTALL_DIR you own or appropriate permissions." >&2
  exit 1
}

pkill -x ScreenInputSync 2>/dev/null || true
rm -rf "$INSTALLED_APP"
/usr/bin/ditto "$BUILT_APP" "$INSTALLED_APP"
/usr/bin/codesign --verify --deep --strict "$INSTALLED_APP"
/usr/bin/open "$INSTALLED_APP"

echo "Installed and launched: $INSTALLED_APP"

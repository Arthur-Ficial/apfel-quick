#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="apfel-quick"
VERSION="$(tr -d '\n' < "$ROOT_DIR/.version")"
ARCH="$(uname -m)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$ROOT_DIR/build/${APP_NAME}.app"
APP_ZIP="$DIST_DIR/${APP_NAME}-v${VERSION}-macos-${ARCH}.zip"
APP_ZIP_STABLE="$DIST_DIR/${APP_NAME}-macos-${ARCH}.zip"
SHA_FILE="$DIST_DIR/SHA256SUMS"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-}"
ENTITLEMENTS="${ENTITLEMENTS:-$ROOT_DIR/apfel-quick.entitlements}"

SIGN_IDENTITY="$SIGN_IDENTITY" ENTITLEMENTS="$ENTITLEMENTS" "$ROOT_DIR/scripts/build-app.sh"

if [[ "$SIGN_IDENTITY" != "-" && -n "$KEYCHAIN_PROFILE" ]]; then
    KEYCHAIN_PROFILE="$KEYCHAIN_PROFILE" "$ROOT_DIR/scripts/notarize.sh" "$APP_BUNDLE"
fi

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR/homebrew"

# Use ditto WITHOUT --norsrc so the stapled notarisation ticket is preserved
COPYFILE_DISABLE=1 ditto -c -k --keepParent "$APP_BUNDLE" "$APP_ZIP"
# Stable name for the always-works landing page download URL
cp "$APP_ZIP" "$APP_ZIP_STABLE"

(
    cd "$DIST_DIR"
    shasum -a 256 "$(basename "$APP_ZIP")" "$(basename "$APP_ZIP_STABLE")" > "$SHA_FILE"
)

APP_SHA="$(shasum -a 256 "$APP_ZIP" | awk '{print $1}')"
"$ROOT_DIR/scripts/render-homebrew-cask.sh" "$VERSION" "$APP_SHA" > "$DIST_DIR/homebrew/apfel-quick.rb"

print "==> Created:"
print "    $APP_ZIP"
print "    $APP_ZIP_STABLE"
print "    $SHA_FILE"
print "    $DIST_DIR/homebrew/apfel-quick.rb"

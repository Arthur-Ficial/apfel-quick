#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="apfel-quick"
APP_BUNDLE="$ROOT_DIR/build/${APP_NAME}.app"
VERSION="$(tr -d '\n' < "$ROOT_DIR/.version")"
ICON_SOURCE="$ROOT_DIR/Sources/Resources/AppIcon.icns"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
ENTITLEMENTS="${ENTITLEMENTS:-$ROOT_DIR/apfel-quick.entitlements}"

resolve_helper() {
    if [[ -n "${APFEL_HELPER_PATH:-}" && -x "${APFEL_HELPER_PATH}" ]]; then
        print -- "${APFEL_HELPER_PATH}"; return 0
    fi
    if command -v apfel >/dev/null 2>&1; then
        command -v apfel; return 0
    fi
    return 1
}

resolve_ohr_helper() {
    if [[ -n "${OHR_HELPER_PATH:-}" && -x "${OHR_HELPER_PATH}" ]]; then
        print -- "${OHR_HELPER_PATH}"; return 0
    fi
    if command -v ohr >/dev/null 2>&1; then
        command -v ohr; return 0
    fi
    return 1
}

codesign_path() {
    local target="$1"
    shift || true

    if [[ "$SIGN_IDENTITY" == "-" ]]; then
        codesign --force --sign "$SIGN_IDENTITY" "$@" "$target"
    else
        codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY" "$@" "$target"
    fi
}

sign_bundle() {
    xattr -cr "$APP_BUNDLE" 2>/dev/null || true

    # Sign embedded helpers first (before signing the bundle)
    if [[ -x "$APP_BUNDLE/Contents/Helpers/apfel" ]]; then
        codesign_path "$APP_BUNDLE/Contents/Helpers/apfel"
    fi
    # ohr is the mic helper. Sign with the parent's entitlements so when
    # apfel-quick spawns it, macOS TCC treats the child as part of the parent
    # app's identity and the microphone grant flows through.
    if [[ -x "$APP_BUNDLE/Contents/Helpers/ohr" ]]; then
        if [[ -n "$ENTITLEMENTS" && -f "$ENTITLEMENTS" ]]; then
            codesign_path "$APP_BUNDLE/Contents/Helpers/ohr" --entitlements "$ENTITLEMENTS"
        else
            codesign_path "$APP_BUNDLE/Contents/Helpers/ohr"
        fi
    fi

    if [[ -n "$ENTITLEMENTS" && -f "$ENTITLEMENTS" ]]; then
        codesign_path "$APP_BUNDLE" --entitlements "$ENTITLEMENTS"
    else
        codesign_path "$APP_BUNDLE"
    fi

    codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
}

print "==> Building ${APP_NAME} ${VERSION}"
swift build -c release --package-path "$ROOT_DIR"
BIN_DIR="$(swift build -c release --show-bin-path --package-path "$ROOT_DIR")"
BIN_PATH="${BIN_DIR}/${APP_NAME}"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$APP_BUNDLE/Contents/Helpers"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"
chmod +x "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"
cp "$ROOT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "$APP_BUNDLE/Contents/Info.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$APP_BUNDLE/Contents/Info.plist" >/dev/null

[[ -f "$ICON_SOURCE" ]] && cp "$ICON_SOURCE" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
[[ -f "$ROOT_DIR/PrivacyInfo.xcprivacy" ]] && cp "$ROOT_DIR/PrivacyInfo.xcprivacy" "$APP_BUNDLE/Contents/Resources/"

if HELPER_PATH="$(resolve_helper 2>/dev/null)"; then
    print "==> Embedding apfel helper from ${HELPER_PATH}"
    cp "$HELPER_PATH" "$APP_BUNDLE/Contents/Helpers/apfel"
    chmod +x "$APP_BUNDLE/Contents/Helpers/apfel"
else
    print "==> ERROR: apfel not found on this build host." >&2
    print "==> Every GUI release must ship with all dependencies bundled. Install apfel (brew install apfel) or set APFEL_HELPER_PATH and rerun." >&2
    exit 1
fi

if OHR_HELPER="$(resolve_ohr_helper 2>/dev/null)"; then
    print "==> Embedding ohr helper from ${OHR_HELPER}"
    cp "$OHR_HELPER" "$APP_BUNDLE/Contents/Helpers/ohr"
    chmod +x "$APP_BUNDLE/Contents/Helpers/ohr"
else
    print "==> ERROR: ohr not found on this build host." >&2
    print "==> apfel-quick ships with voice input: bundle ohr with every release." >&2
    print "==> Install: brew install Arthur-Ficial/tap/ohr  (or set OHR_HELPER_PATH)." >&2
    exit 1
fi

print "==> Signing bundle (${SIGN_IDENTITY})"
sign_bundle

print "==> Built ${APP_BUNDLE}"

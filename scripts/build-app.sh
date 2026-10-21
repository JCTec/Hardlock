#!/bin/bash
# Builds Hardlock.app into ./build.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${CONFIG:-release}"
APP="$ROOT/build/Hardlock.app"

cd "$ROOT"
# UNIVERSAL=1 builds for both Apple silicon and Intel.
ARCHS=()
[[ "${UNIVERSAL:-0}" == 1 ]] && ARCHS=(--arch arm64 --arch x86_64)
swift build -c "$CONFIG" ${ARCHS[@]+"${ARCHS[@]}"}
BIN="$(swift build -c "$CONFIG" ${ARCHS[@]+"${ARCHS[@]}"} --show-bin-path)/Hardlock"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Library/LaunchAgents"
cp "$BIN" "$APP/Contents/MacOS/Hardlock"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
# The LaunchAgent is registered from inside the bundle with SMAppService.
cp "$ROOT/Resources/LaunchAgents/"*.plist "$APP/Contents/Library/LaunchAgents/"

# App icon from the light iconset. iconutil wants "@2x" in the file names.
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
for png in "$ROOT/Resources/AppIcon/light/Hardlock-light.iconset/"*.png; do
    name="$(basename "$png")"
    cp "$png" "$ICONSET/${name/-2x/@2x}"
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$(dirname "$ICONSET")"

# Sign with the first Developer ID Application identity in the keychain, or set
# SIGN_IDENTITY. Ad-hoc signing (SIGN_IDENTITY=-) runs, but macOS files an
# unsigned app's background item under "Unknown Developer" and may not launch it.
if [[ -z "${SIGN_IDENTITY:-}" ]]; then
    SIGN_IDENTITY="$(security find-identity -v -p codesigning \
        | sed -nE 's/.*"(Developer ID Application: [^"]+)".*/\1/p' | head -1)"
    SIGN_IDENTITY="${SIGN_IDENTITY:--}"
fi
if [[ "$SIGN_IDENTITY" == "-" ]]; then
    codesign --force --sign - "$APP"
else
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
fi
echo "Signed with: $SIGN_IDENTITY"

echo "Built $APP"

#!/bin/bash
# Builds a universal Hardlock.app and packages it as build/Hardlock-<version>.dmg.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Hardlock.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
DMG="$ROOT/build/Hardlock-$VERSION.dmg"
STAGING="$ROOT/build/dmg"

UNIVERSAL=1 "$ROOT/scripts/build-app.sh"

rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

cp "$ROOT/README.md" "$ROOT/LICENSE" "$STAGING/"

hdiutil create -volname "Hardlock" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGING"

# Sign the DMG with the same identity as the app (skipped for ad-hoc builds).
IDENTITY="$(codesign -dv --verbose=2 "$APP" 2>&1 | sed -nE 's/^Authority=(Developer ID Application: .*)$/\1/p')"
if [[ -n "$IDENTITY" ]]; then
    codesign --force --timestamp --sign "$IDENTITY" "$DMG"
fi

# NOTARY_PROFILE=<name> notarizes and staples the DMG, using credentials saved with
# `xcrun notarytool store-credentials <name>`.
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
    spctl --assess --type open --context context:primary-signature --verbose "$DMG"
fi

shasum -a 256 "$DMG" | sed "s|$ROOT/build/||" > "$DMG.sha256"

echo "Built $DMG"
cat "$DMG.sha256"

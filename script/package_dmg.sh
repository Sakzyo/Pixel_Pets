#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
./script/build_universal.sh

SOURCE_APP="$ROOT_DIR/dist/Desktop Pets Universal.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SOURCE_APP/Contents/Info.plist")"
DMG_NAME="Desktop-Pets-${VERSION}-universal.dmg"
DMG_PATH="$ROOT_DIR/dist/$DMG_NAME"
STAGING_DIR="$(mktemp -d "$ROOT_DIR/.build/dmg-staging.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT

/usr/bin/ditto "$SOURCE_APP" "$STAGING_DIR/Desktop Pets.app"
ln -s /Applications "$STAGING_DIR/Applications"
cp "$ROOT_DIR/Config/DMG-README.txt" "$STAGING_DIR/Read Me.txt"
/usr/bin/codesign --verify --deep --strict "$STAGING_DIR/Desktop Pets.app"

/usr/bin/hdiutil create -volname "Desktop Pets $VERSION" -srcfolder "$STAGING_DIR" \
  -fs HFS+ -format UDZO -ov "$DMG_PATH"
/usr/bin/hdiutil verify "$DMG_PATH"
(
  cd "$ROOT_DIR/dist"
  /usr/bin/shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"
)
printf 'Created %s\n' "$DMG_PATH"

#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="DesktopPets"
BUNDLE_ID="dev.dylanxu.DesktopPets"
CONFIGURATION="${CONFIGURATION:-debug}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Config/Info.plist")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT_DIR/Config/Info.plist")"
APP_BUNDLE="$ROOT_DIR/dist/Desktop Pets.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_BINARY="$APP_CONTENTS/MacOS/$APP_NAME"

cd "$ROOT_DIR"
mkdir -p "$ROOT_DIR/.build/ModuleCache" "$ROOT_DIR/.build/SwiftPMCache"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT_DIR/.build/ModuleCache"
export XDG_CACHE_HOME="$ROOT_DIR/.build/SwiftPMCache"
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
swift build -c "$CONFIGURATION" --disable-sandbox --cache-path "$ROOT_DIR/.build/SwiftPMCache"
BUILD_BINARY="$(swift build -c "$CONFIGURATION" --disable-sandbox --show-bin-path)/$APP_NAME"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_CONTENTS/MacOS" "$APP_CONTENTS/Resources"
cp "$BUILD_BINARY" "$APP_BINARY"
cp -R Assets "$APP_CONTENTS/Resources/Assets"
cp Config/AppIcon.icns "$APP_CONTENTS/Resources/AppIcon.icns"
cp THIRD_PARTY_NOTICES.md "$APP_CONTENTS/Resources/"
chmod +x "$APP_BINARY"

cat >"$APP_CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>Desktop Pets</string>
  <key>CFBundleDisplayName</key><string>Desktop Pets</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>CFBundleShortVersionString</key><string>$APP_VERSION</string>
  <key>CFBundleIconFile</key><string>AppIcon.icns</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
/usr/bin/codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"

open_app() { /usr/bin/open -n "$APP_BUNDLE"; }
case "$MODE" in
  --build-only|build) : ;;
  run) open_app ;;
  --debug|debug) lldb -- "$APP_BINARY" ;;
  --logs|logs) open_app; /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\"" ;;
  --telemetry|telemetry) open_app; /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\"" ;;
  --verify|verify) open_app; sleep 2; pgrep -x "$APP_NAME" >/dev/null ;;
  *) echo "usage: $0 [run|--build-only|--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac

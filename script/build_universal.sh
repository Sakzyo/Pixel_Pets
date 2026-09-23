#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
xcodebuild -project DesktopPets.xcodeproj -scheme DesktopPets -configuration Release \
  -derivedDataPath "$ROOT_DIR/.build/XcodeUniversal" -destination 'generic/platform=macOS' \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build -quiet

SOURCE_APP="$ROOT_DIR/.build/XcodeUniversal/Build/Products/Release/DesktopPets.app"
OUTPUT_APP="$ROOT_DIR/dist/Desktop Pets Universal.app"
mkdir -p "$ROOT_DIR/dist"
rm -rf "$OUTPUT_APP"
cp -R "$SOURCE_APP" "$OUTPUT_APP"
/usr/bin/codesign --force --sign - --identifier dev.dylanxu.DesktopPets "$OUTPUT_APP"
/usr/bin/codesign --verify --deep --strict "$OUTPUT_APP"
lipo -info "$OUTPUT_APP/Contents/MacOS/DesktopPets"

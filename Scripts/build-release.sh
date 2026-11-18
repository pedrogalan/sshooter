#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="sShooter"
BINARY_NAME="sshooter"
APP_BUNDLE="dist/${APP_NAME}.app"
BUILD_DIR=".build/release-universal"

echo "Building arm64 release binary…"
swift build -c release --triple arm64-apple-macosx14.0 --scratch-path .build/release-arm64

echo "Building x86_64 release binary…"
swift build -c release --triple x86_64-apple-macosx14.0 --scratch-path .build/release-x86_64

mkdir -p "$BUILD_DIR" dist
lipo -create \
  ".build/release-arm64/out/Products/Release/${BINARY_NAME}" \
  ".build/release-x86_64/out/Products/Release/${BINARY_NAME}" \
  -output "$BUILD_DIR/${BINARY_NAME}"

SSHOOTER_BINARY="$BUILD_DIR/${BINARY_NAME}" ./Scripts/build-app.sh "$APP_BUNDLE"

VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")
ARCHIVE="dist/${APP_NAME}-${VERSION}-macos-universal.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ARCHIVE"

echo "Created universal app: $APP_BUNDLE"
echo "Created release archive: $ARCHIVE"

#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-$PROJECT_DIR/dist/sshooter.app}"
CONTENTS_PATH="$APP_PATH/Contents"

cd "$PROJECT_DIR"
swift build --configuration release

mkdir -p "$CONTENTS_PATH/MacOS"
cp "$PROJECT_DIR/.build/release/sshooter" "$CONTENTS_PATH/MacOS/sshooter"
chmod 755 "$CONTENTS_PATH/MacOS/sshooter"

cat > "$CONTENTS_PATH/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>sshooter</string>
	<key>CFBundleIdentifier</key>
	<string>com.pedrogalan.sshooter</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>sshooter</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSScreenCaptureUsageDescription</key>
	<string>sshooter captures the screen area you select for a screenshot.</string>
</dict>
</plist>
PLIST

/usr/bin/codesign --force --deep --sign - --identifier com.pedrogalan.sshooter "$APP_PATH"
printf 'Built %s\nLaunch it with: open "%s"\n' "$APP_PATH" "$APP_PATH"

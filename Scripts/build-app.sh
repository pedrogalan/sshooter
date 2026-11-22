#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-$PROJECT_DIR/dist/sShooter.app}"
BINARY="${SSHOOTER_BINARY:-$PROJECT_DIR/.build/release/sshooter}"
CONTENTS_PATH="$APP_PATH/Contents"
RESOURCES_PATH="$CONTENTS_PATH/Resources"

cd "$PROJECT_DIR"
# Skip the local build when a prebuilt executable is supplied (used by
# Scripts/build-release.sh to package the universal binary).
if [ -z "${SSHOOTER_BINARY:-}" ]; then
    swift build --configuration release
fi

mkdir -p "$CONTENTS_PATH/MacOS"
rm -rf "$RESOURCES_PATH"
mkdir -p "$RESOURCES_PATH"
cp "$BINARY" "$CONTENTS_PATH/MacOS/sShooter"
chmod 755 "$CONTENTS_PATH/MacOS/sShooter"
cp "$PROJECT_DIR/Assets/MenuBarIcon.png" "$RESOURCES_PATH/MenuBarIcon.png"
cp "$PROJECT_DIR/Sources/Sshotter/Resources/BlurToolIcon.png" "$RESOURCES_PATH/BlurToolIcon.png"
cp "$PROJECT_DIR/Sources/Sshotter/Resources/DueDate.ttf" "$RESOURCES_PATH/DueDate.ttf"
cp "$PROJECT_DIR/Sources/Sshotter/Resources/DueDate-LICENSE.txt" "$RESOURCES_PATH/DueDate-LICENSE.txt"

# Build an .icns from the source PNG. CFBundleIconFile, the Dock, Cmd-Tab, and
# Finder all expect an .icns rather than a raw PNG.
ICONSET_DIR="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$PROJECT_DIR/Assets/AppIcon.png" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
    sips -z "$((size * 2))" "$((size * 2))" "$PROJECT_DIR/Assets/AppIcon.png" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_PATH/AppIcon.icns"
rm -rf "$(dirname "$ICONSET_DIR")"

cat > "$CONTENTS_PATH/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleDisplayName</key>
	<string>sShooter</string>
	<key>CFBundleExecutable</key>
	<string>sShooter</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>com.pedrogalan.sshooter</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>sShooter</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.6.0</string>
	<key>CFBundleVersion</key>
	<string>7</string>
	<key>LSUIElement</key>
	<true/>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>NSScreenCaptureUsageDescription</key>
	<string>sShooter captures the screen area you select for a screenshot.</string>
</dict>
</plist>
PLIST

/usr/bin/codesign --force --deep --sign - --identifier com.pedrogalan.sshooter "$APP_PATH"
printf 'Built %s\nLaunch it with: open "%s"\n' "$APP_PATH" "$APP_PATH"

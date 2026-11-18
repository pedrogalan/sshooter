# Instructions for coding agents

This file contains development and release procedures. Keep the root README focused on information for people evaluating, installing, and using sShooter.

## Project basics

- sShooter is a native Swift and AppKit menu bar screenshot and annotation app for macOS 14 and later.
- `Package.swift` defines a single executable target at `Sources/Sshotter`. The SwiftPM product and binary are named `sshooter` (internal only).
- The app’s bundle identifier is `com.pedrogalan.sshooter`.
- Keep the app bundle named `sShooter.app`. Version numbers belong in `Scripts/build-app.sh`, release tags, release notes, and archive filenames; do not append them to the app bundle name.
- The GitHub repository slug and URLs are `sshooter`.
- The README is public-facing and should not contain a current version number or internal build/release commands.
- `Assets/AppIcon.png` is the editable app-icon source artwork; the build generates `AppIcon.icns` from it. `Assets/MenuBarIcon.png` is the menu bar template image, prepared from `Assets/sshooter-menubar-source.png` by `Scripts/prepare-logo-assets.swift`.

## Core principles

- **Native First:** Prefer official Apple frameworks (`SwiftUI`, `AppKit`, `ScreenCaptureKit`, `CoreImage`, `Vision`) over third-party libraries so the codebase stays transparent, fast, and easy to audit.
- **No Unnecessary Network Calls:** Keep all image processing, OCR, and file management completely local on the user’s Mac.
- **User-Controlled Storage:** Support saving screenshots to a user-configured local directory (via `UserDefaults` and `NSOpenPanel`), as well as copying directly to the clipboard.

## Tech stack and architecture

- **Language and UI:** Swift and SwiftUI, bridging to AppKit (`NSWindow`, `NSPanel`, `NSPasteboard`, `NSOpenPanel`) where needed for overlays, global hotkeys, and file dialogs.
- **Build system:** A Swift Package (`Package.swift`) targeting `macOS 14.0+` so it can be built and run directly from the terminal.
- **Code organisation:** Keep code modular with separate files for screen capture (`ScreenCapture.swift`), annotation (`AnnotationEditor.swift`), settings and preferences (`SettingsWindow.swift`, `ScreenshotStore.swift`, `Permissions.swift`), and the app entry point (`App.swift`).
- The Settings window has three tabs — General, Permissions, and About — matching the layout used by the sibling OptTab app.

## Build

Build a local app bundle with:

```bash
./Scripts/build-app.sh
```

This creates or replaces `dist/sShooter.app`. The script accepts an optional output bundle path as its first argument. `SSHOOTER_BINARY` can point it at an already-built executable; the release script uses that to package a universal binary.

The app icon is generated at build time: `Assets/AppIcon.png` is scaled with `sips` and packed into `Contents/Resources/AppIcon.icns` with `iconutil`. `Info.plist` is written by the build script; keep its version in sync with the release notes.

The build is ad-hoc signed because the project does not have an Apple Developer ID certificate. Ad-hoc signing is not notarization and may cause Gatekeeper warnings for downloaded builds.

Always run `swift build` after making changes to verify the project compiles cleanly, and fix any compiler errors right away.

## Release procedure

Use an annotated version tag such as `v1.0.0`. Keep the app name `sShooter.app` unchanged.

1. Start from a clean, up-to-date `master` branch and confirm that the release tag and GitHub release do not already exist.
2. Set `CFBundleShortVersionString` and increment `CFBundleVersion` in `Scripts/build-app.sh`.
3. Add `releases/v<version>.md` with the user-visible changes and review the README for factual changes. Do not put the current version in the README.
4. Build the universal app and archive on macOS:

   ```bash
   ./Scripts/build-release.sh
   ```

   This creates `dist/sShooter.app` and `dist/sShooter-<version>-macos-universal.zip`. The archive contains the app bundle; `dist/` is ignored by Git.
5. Verify the app version, both architectures, icon, signature, and archive:

   ```bash
   VERSION=1.0.0
   /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' dist/sShooter.app/Contents/Info.plist
   /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' dist/sShooter.app/Contents/Info.plist
   lipo -info dist/sShooter.app/Contents/MacOS/sShooter
   test -s dist/sShooter.app/Contents/Resources/AppIcon.icns
   codesign --verify --deep --strict dist/sShooter.app
   unzip -t "dist/sShooter-${VERSION}-macos-universal.zip"
   shasum -a 256 "dist/sShooter-${VERSION}-macos-universal.zip"
   ```

   Confirm the app bundle inside the ZIP is named `sShooter.app`, with no version suffix.
6. Review and stage the release changes, commit, and tag:

   ```bash
   VERSION=1.0.0
   git add -A
   git diff --cached
   git commit -m "Prepare sShooter ${VERSION} release"
   git tag -a "v${VERSION}" -m "sShooter ${VERSION}"
   git push origin master "v${VERSION}"
   ```
7. Confirm `gh auth status`, then publish the archive and notes:

   ```bash
   VERSION=1.0.0
   gh release create "v${VERSION}" \
     --title "sShooter ${VERSION}" \
     --notes-file "releases/v${VERSION}.md" \
     "dist/sShooter-${VERSION}-macos-universal.zip"
   ```

## Permissions and troubleshooting

- Screen Recording is the only permission sShooter needs; it is required to capture the screen through ScreenCaptureKit.
- Grant permission after installing sShooter at its final location. Ad-hoc rebuilds can change the app signature, which may cause macOS to ask for permission again.
- With `swift run`, permission may need to be granted to the development executable or the launching terminal instead of the packaged app.
- Screen Recording icons and entries in System Settings are cached per bundle identifier (`com.pedrogalan.sshooter`). After changing the icon, re-register the bundle with `lsregister -f` and restart the Dock if the cached icon looks stale.

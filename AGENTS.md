# Project Overview
A lightweight, fast, native macOS screenshot and annotation utility inspired by Shottr.

# Core Principles
- **Native First:** Prefer official Apple frameworks (`SwiftUI`, `AppKit`, `ScreenCaptureKit`, `CoreImage`, `Vision`) over third-party libraries so the codebase stays transparent, fast, and easy to audit.
- **No Unnecessary Network Calls:** Keep all image processing, OCR, and file management completely local on the user's Mac.
- **User-Controlled Storage:** Support saving screenshots to a user-configured local directory (e.g., via `UserDefaults` / `@AppStorage` and `NSOpenPanel`), as well as copying directly to the clipboard.

# Tech Stack & Architecture
- **Language & UI:** Swift and SwiftUI, bridging to AppKit (`NSWindow`, `NSPanel`, `NSPasteboard`, `NSOpenPanel`) where needed for overlays, global hotkeys, and file dialogs.
- **Build System:** Structure as a Swift Package (`Package.swift`) targeting `macOS 14.0+` so it can be built and run directly from the terminal (`swift build` / `swift run`).
- **Code Organization:** Keep code modular with separate files for screen capture, annotation tools, settings/preferences, and UI views.

# Workflow
- Always run `swift build` after making changes to verify the project compiles cleanly, and fix any compiler errors right away.

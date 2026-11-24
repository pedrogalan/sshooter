import AppKit
import ScreenCaptureKit

enum ScreenCapture {
    static func captureDisplay(id displayID: CGDirectDisplayID) async throws -> CGImage {
        let content = try await shareableContent()
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.noDisplay
        }
        return try await capture(display: display, in: content).image
    }

    static func captureRegion(in rect: CGRect, excludingWindowIDs: [CGWindowID] = []) async throws -> CGImage {
        let content = try await shareableContent()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        guard let display = content.displays.first(where: { $0.frame.contains(center) }) else {
            throw CaptureError.noDisplay
        }

        let (fullImage, scale) = try await capture(
            display: display,
            in: content,
            excludingWindowIDs: excludingWindowIDs
        )
        let localRect = CGRect(
            x: (rect.minX - display.frame.minX) * scale,
            y: (rect.minY - display.frame.minY) * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
        .integral
        .intersection(CGRect(x: 0, y: 0, width: fullImage.width, height: fullImage.height))

        guard !localRect.isNull,
              localRect.width >= 1,
              localRect.height >= 1,
              let crop = fullImage.cropping(to: localRect) else {
            throw CaptureError.couldNotCrop
        }
        return crop
    }

    private static func shareableContent() async throws -> SCShareableContent {
        try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    }

    private static func capture(
        display: SCDisplay,
        in content: SCShareableContent,
        excludingWindowIDs: [CGWindowID] = []
    ) async throws -> (image: CGImage, scale: CGFloat) {
        let filter = contentFilter(
            for: display,
            in: content,
            excludingWindowIDs: excludingWindowIDs
        )
        let scale = CGFloat(filter.pointPixelScale)

        let configuration = SCStreamConfiguration()
        configuration.width = Int(CGFloat(display.width) * scale)
        configuration.height = Int(CGFloat(display.height) * scale)
        configuration.showsCursor = false

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
        return (image, scale)
    }

    private static func contentFilter(
        for display: SCDisplay,
        in content: SCShareableContent,
        excludingWindowIDs: [CGWindowID]
    ) -> SCContentFilter {
        // Exclude our own windows so the overlay (or the editor) never ends up
        // in the screenshot, regardless of how quickly the window disappears.
        let ownProcessID = ProcessInfo.processInfo.processIdentifier
        let ownApplication = content.applications.first { $0.processID == ownProcessID }
        let ownWindows = content.windows.filter {
            excludingWindowIDs.contains(CGWindowID($0.windowID))
        }
        return SCContentFilter(
            display: display,
            excludingApplications: ownApplication.map { [$0] } ?? [],
            exceptingWindows: ownWindows
        )
    }
}

@MainActor
final class CaptureModel {
    static let shared = CaptureModel()

    private var activeOverlay: RegionCaptureWindow?
    private var editorWindow: AnnotationEditorWindow?
    private var isCapturing = false

    func beginRegionCapture() {
        guard !isCapturing else { return }
        isCapturing = true

        // Do this inside the menu item's user gesture. Deferring it to the
        // overlay would let macOS refuse activation, leaving the overlay
        // visible but not key so the first click only activates the app.
        NSApp.activate(ignoringOtherApps: true)

        // A status-menu action runs while the menu is still dismissing. Wait for
        // the next turn of the run loop so the first click after the overlay
        // appears is delivered to it instead of being swallowed by the menu.
        Task { [weak self] in
            guard let self else { return }
            await self.startRegionCapture()
        }
    }

    private func startRegionCapture() async {
        guard let screen = screenUnderPointer(),
              let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            isCapturing = false
            showError(CaptureError.noDisplay)
            return
        }

        let displayID = CGDirectDisplayID(screenNumber.uint32Value)
        do {
            let image = try await ScreenCapture.captureDisplay(id: displayID)
            presentOverlay(on: screen, image: image)
        } catch {
            isCapturing = false
            showError(error)
        }
    }

    private func screenUnderPointer() -> NSScreen? {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(pointer) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    private func presentOverlay(on screen: NSScreen, image: CGImage) {
        let overlay = RegionCaptureWindow(
            screen: screen,
            image: image,
            onComplete: { [weak self] rect in
                Task { @MainActor in self?.completeSelection(rect) }
            },
            onCancel: { [weak self] in
                Task { @MainActor in self?.cancelCapture() }
            }
        )
        activeOverlay = overlay
        overlay.show()
    }

    private func completeSelection(_ rect: CGRect) {
        let excludedWindowIDs = activeOverlay.map { [CGWindowID($0.windowNumber)] } ?? []

        Task { [weak self] in
            guard let self else { return }
            do {
                let image = try await ScreenCapture.captureRegion(
                    in: rect,
                    excludingWindowIDs: excludedWindowIDs
                )
                self.dismissOverlay()
                self.isCapturing = false
                self.showEditor(with: image)
            } catch {
                self.dismissOverlay()
                self.isCapturing = false
                self.showError(error)
            }
        }
    }

    private func cancelCapture() {
        dismissOverlay()
        isCapturing = false
        // Forcing activation was needed to make the overlay key. Hand focus
        // back when there is no editor to return to.
        if editorWindow?.isVisible != true {
            NSApp.deactivate()
        }
    }

    private func dismissOverlay() {
        activeOverlay?.dismiss()
        activeOverlay = nil
    }

    private func showEditor(with image: CGImage, autoSave: Bool = true) {
        if autoSave, ScreenshotStore.shared.autoSaveCaptures {
            do {
                _ = try ScreenshotStore.shared.saveCapture(image)
            } catch {
                showAutoSaveError(error)
            }
        }

        // The app is a menu-bar agent while idle, but the editor behaves like a
        // regular app: it gets its own menu bar and a Dock presence.
        NSApp.setActivationPolicy(.regular)

        if let editorWindow {
            editorWindow.present(image: image)
        } else {
            let editor = AnnotationEditorWindow(
                onCopy: { [weak self] image in
                    self?.copyToClipboard(image)
                },
                onSave: { data in
                    try ScreenshotStore.shared.save(pngData: data)
                },
                onClose: { [weak self] in
                    self?.editorDidClose()
                }
            )
            editorWindow = editor
            editor.present(image: image)
        }
    }

    private func editorDidClose() {
        NSApp.setActivationPolicy(.accessory)
    }

    func closeEditor() {
        editorWindow?.close()
    }

    func settingsDidClose() {
        if editorWindow?.isVisible != true {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    var canReopenEditor: Bool {
        editorWindow?.hasContent ?? false
    }

    func reopenEditor() {
        guard let editorWindow, editorWindow.hasContent else { return }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        editorWindow.reopen()
    }

#if SSHOOTER_DEBUG_MENU
    /// Dev-only blank canvas for exercising the annotation tools without a
    /// screen capture. Compiled out of release builds by Package.swift.
    func showBlankCanvas() {
        let size = CGSize(width: 1280, height: 800)
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        guard let image = context.makeImage() else { return }
        showEditor(with: image, autoSave: false)
    }
#endif

    private func copyToClipboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        if let tiff = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let png = bitmap.representation(using: .png, properties: [:]) {
            pasteboard.setData(png, forType: .png)
        }
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Couldn’t capture the screen"
        alert.informativeText = error.localizedDescription + "\n\nCheck System Settings → Privacy & Security → Screen & System Audio Recording, then try again."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showAutoSaveError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Couldn’t save the automatic screenshot"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

}

private enum CaptureError: LocalizedError {
    case noDisplay
    case couldNotCrop

    var errorDescription: String? {
        switch self {
        case .noDisplay: "No display was available to capture."
        case .couldNotCrop: "The selected area was outside the captured display."
        }
    }
}

@MainActor
private final class RegionCaptureWindow: NSWindow {
    private var selectionView: RegionSelectionView?

    init(
        screen: NSScreen,
        image: CGImage,
        onComplete: @escaping (CGRect) -> Void,
        onCancel: @escaping () -> Void
    ) {
        let view = RegionSelectionView(
            image: image,
            size: screen.frame.size,
            onComplete: onComplete,
            onCancel: onCancel
        )
        selectionView = view

        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        contentView = view
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
        if let selectionView {
            makeFirstResponder(selectionView)
            invalidateCursorRects(for: selectionView)
        }
        NSCursor.crosshair.set()
    }

    func dismiss() {
        orderOut(nil)
        contentView = nil
        selectionView = nil
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
private final class RegionSelectionView: NSView {
    private let screenImage: NSImage
    private let onComplete: (CGRect) -> Void
    private let onCancel: () -> Void
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var guidePoint: CGPoint?
    private var hasFinished = false

    init(
        image: CGImage,
        size: NSSize,
        onComplete: @escaping (CGRect) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.screenImage = NSImage(cgImage: image, size: size)
        self.onComplete = onComplete
        self.onCancel = onCancel
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        trackingAreas.forEach(removeTrackingArea)
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        super.updateTrackingAreas()
    }

    override func viewDidMoveToWindow() {
        window?.makeFirstResponder(self)
        NSCursor.crosshair.set()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseEntered(with event: NSEvent) {
        updateGuide(with: event)
        NSCursor.crosshair.set()
    }

    override func mouseMoved(with event: NSEvent) {
        updateGuide(with: event)
        NSCursor.crosshair.set()
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func draw(_ dirtyRect: NSRect) {
        screenImage.draw(in: bounds)

        NSColor.black.withAlphaComponent(0.32).setFill()
        bounds.fill()

        if let selection = selectionRect, !selection.isEmpty {
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: selection).addClip()
            screenImage.draw(in: bounds)
            NSGraphicsContext.restoreGraphicsState()

            NSColor.white.setStroke()
            let border = NSBezierPath(rect: selection)
            border.lineWidth = 1.5
            border.stroke()
        }

        drawGuideLines()
    }

    /// Full-width and full-height dotted guides that meet at the pointer, so
    /// the selection can be lined up with things elsewhere on the screen.
    private func drawGuideLines() {
        guard !hasFinished, let guidePoint else { return }

        let path = NSBezierPath()
        path.move(to: CGPoint(x: bounds.minX, y: guidePoint.y))
        path.line(to: CGPoint(x: bounds.maxX, y: guidePoint.y))
        path.move(to: CGPoint(x: guidePoint.x, y: bounds.minY))
        path.line(to: CGPoint(x: guidePoint.x, y: bounds.maxY))
        path.lineWidth = 1
        path.setLineDash([4, 4], count: 2, phase: 0)

        // Alternating black and white dashes stay visible on any background.
        NSColor.black.withAlphaComponent(0.7).setStroke()
        path.stroke()
        path.setLineDash([4, 4], count: 2, phase: 4)
        NSColor.white.withAlphaComponent(0.95).setStroke()
        path.stroke()
    }

    private func updateGuide(with event: NSEvent) {
        updateGuide(to: convert(event.locationInWindow, from: nil))
    }

    private func updateGuide(to point: CGPoint) {
        guard !hasFinished else { return }
        let oldPoint = guidePoint
        guard oldPoint != point else { return }
        guidePoint = point

        var dirty = guideBand(at: point)
        if let oldPoint {
            dirty = dirty.union(guideBand(at: oldPoint))
        }
        setNeedsDisplay(dirty)
    }

    private func guideBand(at point: CGPoint) -> CGRect {
        CGRect(x: bounds.minX, y: point.y - 1, width: bounds.width, height: 3)
            .union(CGRect(x: point.x - 1, y: bounds.minY, width: 3, height: bounds.height))
    }

    override func mouseDown(with event: NSEvent) {
        guard !hasFinished else { return }
        let point = convert(event.locationInWindow, from: nil)
        startPoint = point
        currentPoint = point
        updateGuide(to: point)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard !hasFinished else { return }
        let point = convert(event.locationInWindow, from: nil)
        currentPoint = point
        updateGuide(to: point)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard !hasFinished else { return }
        let point = convert(event.locationInWindow, from: nil)
        currentPoint = point
        updateGuide(to: point)
        guard let selection = selectionRect,
              selection.width >= 2,
              selection.height >= 2,
              let screenRect = screenRect(for: selection) else {
            cancel()
            return
        }

        // Keep the overlay on screen while the capture runs so the app is
        // present in ScreenCaptureKit's window list and can be excluded.
        hasFinished = true
        guidePoint = nil
        needsDisplay = true
        NSCursor.arrow.set()
        onComplete(screenRect)
    }

    override func rightMouseDown(with event: NSEvent) {
        cancel()
    }

    override func keyDown(with event: NSEvent) {
        guard !hasFinished else { return }
        if event.keyCode == 53 {
            cancel()
        } else {
            super.keyDown(with: event)
        }
    }

    private func cancel() {
        guard !hasFinished else { return }
        hasFinished = true
        window?.orderOut(nil)
        NSCursor.arrow.set()
        onCancel()
    }

    /// Converts the selection from flipped view coordinates to Core Graphics
    /// global display coordinates (origin at the top-left of the main display,
    /// y increasing downward).
    private func screenRect(for viewRect: CGRect) -> CGRect? {
        guard let window else { return nil }
        let primaryScreen = NSScreen.screens.first
        let windowRect = convert(viewRect, to: nil)
        let appKitRect = window.convertToScreen(windowRect)
        return CGRect(
            x: appKitRect.minX,
            y: (primaryScreen?.frame.maxY ?? appKitRect.maxY) - appKitRect.maxY,
            width: appKitRect.width,
            height: appKitRect.height
        )
    }

    private var selectionRect: CGRect? {
        guard let startPoint, let currentPoint else { return nil }
        let rect = CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
        let clamped = rect.intersection(bounds)
        return clamped.isNull ? nil : clamped
    }
}

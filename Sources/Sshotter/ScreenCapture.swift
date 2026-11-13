import AppKit
import Combine
import ScreenCaptureKit

enum ScreenCapture {
    static func captureDisplay(id displayID: CGDirectDisplayID) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        let pixelScale = CGFloat(filter.pointPixelScale)
        configuration.width = Int(CGFloat(display.width) * pixelScale)
        configuration.height = Int(CGFloat(display.height) * pixelScale)
        configuration.showsCursor = false
        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
    }

    static func captureRegion(in rect: CGRect) async throws -> CGImage {
        if #available(macOS 15.2, *) {
            return try await SCScreenshotManager.captureImage(in: rect)
        }

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        let center = CGPoint(x: rect.midX, y: rect.midY)
        guard let display = content.displays.first(where: { $0.frame.contains(center) }) else {
            throw CaptureError.noDisplay
        }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        let scale = CGFloat(filter.pointPixelScale)
        configuration.width = Int(CGFloat(display.width) * scale)
        configuration.height = Int(CGFloat(display.height) * scale)
        let fullImage = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
        let localRect = CGRect(
            x: (rect.minX - display.frame.minX) * scale,
            y: (rect.minY - display.frame.minY) * scale,
            width: rect.width * scale,
            height: rect.height * scale
        ).integral.intersection(CGRect(x: 0, y: 0, width: fullImage.width, height: fullImage.height))
        guard let crop = fullImage.cropping(to: localRect) else {
            throw CaptureError.couldNotCrop
        }
        return crop
    }
}

@MainActor
final class CaptureModel: ObservableObject {
    static let shared = CaptureModel()

    @Published private(set) var errorMessage: String?
    private var activeOverlay: RegionCaptureWindow?
    private var editorWindow: AnnotationEditorWindow?

    func beginRegionCapture() {
        errorMessage = nil
        Task {
            do {
                guard let screen = NSScreen.main,
                      let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                    throw CaptureError.noDisplay
                }
                let displayID = CGDirectDisplayID(screenNumber.uint32Value)
                let image = try await ScreenCapture.captureDisplay(id: displayID)
                let onComplete: (CGRect) -> Void = { [weak self] rect in
                    Task { @MainActor in
                        do {
                            let crop = try await ScreenCapture.captureRegion(in: rect)
                            self?.showEditor(with: crop)
                        } catch {
                            self?.showError(error)
                        }
                    }
                }

                if let activeOverlay {
                    activeOverlay.prepare(screen: screen, image: image, onComplete: onComplete)
                } else {
                    activeOverlay = RegionCaptureWindow(screen: screen, image: image, onComplete: onComplete)
                }
                activeOverlay?.show()
            } catch {
                showError(error)
            }
        }
    }

    private func showEditor(with image: CGImage) {
        if let editorWindow {
            editorWindow.present(image: image)
        } else {
            let editor = AnnotationEditorWindow { [weak self] image in
                self?.copyToClipboard(image)
            }
            editorWindow = editor
            editor.present(image: image)
        }
    }

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
        errorMessage = error.localizedDescription
        let alert = NSAlert()
        alert.messageText = "Couldn’t capture the screen"
        alert.informativeText = error.localizedDescription + "\n\nCheck System Settings → Privacy & Security → Screen & System Audio Recording, then try again."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

}

private enum CaptureError: LocalizedError {
    case noDisplay
    case couldNotEncode
    case couldNotCrop

    var errorDescription: String? {
        switch self {
        case .noDisplay: "No display was available to capture."
        case .couldNotEncode: "The selected area couldn’t be saved as a PNG."
        case .couldNotCrop: "The selected area was outside the captured display."
        }
    }
}

@MainActor
private final class RegionCaptureWindow: NSWindow {
    private let selectionView: RegionSelectionView

    init(
        screen: NSScreen,
        image: CGImage,
        onComplete: @escaping (CGRect) -> Void
    ) {
        selectionView = RegionSelectionView(image: image, size: screen.frame.size, onComplete: onComplete)
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
        contentView = selectionView
    }

    func prepare(screen: NSScreen, image: CGImage, onComplete: @escaping (CGRect) -> Void) {
        setFrame(screen.frame, display: false)
        selectionView.configure(image: image, size: screen.frame.size, onComplete: onComplete)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
        invalidateCursorRects(for: selectionView)
        NSCursor.crosshair.set()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
private final class RegionSelectionView: NSView {
    private var image: CGImage
    private var screenImage: NSImage
    private var onComplete: (CGRect) -> Void
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?

    init(image: CGImage, size: NSSize, onComplete: @escaping (CGRect) -> Void) {
        self.image = image
        self.screenImage = NSImage(cgImage: image, size: size)
        self.onComplete = onComplete
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
        NSCursor.crosshair.set()
    }

    override func mouseMoved(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    func configure(image: CGImage, size: NSSize, onComplete: @escaping (CGRect) -> Void) {
        self.image = image
        screenImage = NSImage(cgImage: image, size: size)
        self.onComplete = onComplete
        startPoint = nil
        currentPoint = nil
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        screenImage.draw(in: bounds)

        NSColor.black.withAlphaComponent(0.32).setFill()
        bounds.fill()

        guard let selection = selectionRect, !selection.isEmpty else { return }
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: selection).addClip()
        screenImage.draw(in: bounds)
        NSGraphicsContext.restoreGraphicsState()

        NSColor.white.setStroke()
        let border = NSBezierPath(rect: selection)
        border.lineWidth = 1.5
        border.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        startPoint = point
        currentPoint = point
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        guard let rect = selectionRect, rect.width >= 2, rect.height >= 2 else {
            window?.orderOut(nil)
            return
        }

        let displayID = (window?.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)
            .map { CGDirectDisplayID($0.uint32Value) } ?? CGMainDisplayID()
        let displayBounds = CGDisplayBounds(displayID)
        let screenRect = CGRect(
            x: displayBounds.minX + rect.minX,
            y: displayBounds.minY + rect.minY,
            width: rect.width,
            height: rect.height
        )
        window?.orderOut(nil)
        onComplete(screenRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            window?.orderOut(nil)
        } else {
            super.keyDown(with: event)
        }
    }

    private var selectionRect: CGRect? {
        guard let startPoint, let currentPoint else { return nil }
        return CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
    }
}

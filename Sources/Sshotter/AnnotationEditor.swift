import AppKit
import CoreGraphics

@MainActor
final class AnnotationEditorWindow: NSWindow, NSToolbarDelegate {
    private static let arrowToolID = NSToolbarItem.Identifier("sshooter.arrowTool")
    private static let copyToolID = NSToolbarItem.Identifier("sshooter.copyTool")

    private let canvas = AnnotationCanvasView()
    private let onCopy: (NSImage) -> Void

    init(onCopy: @escaping (NSImage) -> Void) {
        self.onCopy = onCopy
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        title = "Screenshot"
        minSize = NSSize(width: 560, height: 380)
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        canvas.autoresizingMask = [.width, .height]
        contentView = canvas

        let toolbar = NSToolbar(identifier: "sshooter.annotationToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false
        self.toolbar = toolbar
    }

    func present(image: CGImage) {
        canvas.setImage(image)
        center()
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        makeFirstResponder(canvas)
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.arrowToolID, .flexibleSpace, Self.copyToolID]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.arrowToolID, .flexibleSpace, Self.copyToolID]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        if itemIdentifier == Self.arrowToolID {
            item.label = "Arrow"
            item.paletteLabel = "Arrow"
            item.toolTip = "Click a start point, move, then click an end point."
            item.image = NSImage(systemSymbolName: "arrow.up.right", accessibilityDescription: "Arrow tool")
            item.target = self
            item.action = #selector(selectArrowTool)
            return item
        }
        if itemIdentifier == Self.copyToolID {
            item.label = "Copy"
            item.paletteLabel = "Copy Screenshot"
            item.toolTip = "Copy the annotated image and close this window (⌘C)."
            item.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy")
            item.target = self
            item.action = #selector(copyImage)
            return item
        }
        return nil
    }

    @objc private func selectArrowTool() {
        canvas.selectArrowTool()
    }

    @objc private func copyImage() {
        guard let image = canvas.imageWithAnnotations() else { return }
        onCopy(image)
        orderOut(nil)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "c" {
            copyImage()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

@MainActor
private final class AnnotationCanvasView: NSView {
    private struct Arrow {
        let start: CGPoint
        let end: CGPoint
    }

    private var screenshot: CGImage?
    private var screenshotImage: NSImage?
    private var arrows: [Arrow] = []
    private var arrowStart: CGPoint?
    private var pointerPosition: CGPoint?
    private var arrowToolIsSelected = true

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    func setImage(_ image: CGImage) {
        screenshot = image
        screenshotImage = NSImage(
            cgImage: image,
            size: NSSize(width: image.width, height: image.height)
        )
        arrows.removeAll()
        arrowStart = nil
        pointerPosition = nil
        needsDisplay = true
    }

    func selectArrowTool() {
        arrowToolIsSelected = true
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()

        guard screenshot != nil, let screenshotImage else { return }
        screenshotImage.draw(in: imageRect)

        for arrow in arrows {
            drawArrow(from: viewPoint(for: arrow.start), to: viewPoint(for: arrow.end))
        }
        if let arrowStart, let pointerPosition {
            drawArrow(from: viewPoint(for: arrowStart), to: viewPoint(for: pointerPosition))
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard arrowToolIsSelected, let point = imagePoint(for: convert(event.locationInWindow, from: nil)) else { return }
        if let arrowStart {
            arrows.append(Arrow(start: arrowStart, end: point))
            self.arrowStart = nil
            pointerPosition = nil
        } else {
            arrowStart = point
            pointerPosition = point
        }
        needsDisplay = true
    }

    override func mouseMoved(with event: NSEvent) {
        updatePointer(from: event)
    }

    override func mouseDragged(with event: NSEvent) {
        updatePointer(from: event)
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "c" {
            window?.performKeyEquivalent(with: event)
        } else {
            super.keyDown(with: event)
        }
    }

    private func updatePointer(from event: NSEvent) {
        guard arrowStart != nil,
              let point = imagePoint(for: convert(event.locationInWindow, from: nil)) else { return }
        pointerPosition = point
        needsDisplay = true
    }

    private var imageRect: CGRect {
        guard let screenshot else { return .zero }
        let imageSize = CGSize(width: screenshot.width, height: screenshot.height)
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let fitted = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (bounds.width - fitted.width) / 2,
            y: (bounds.height - fitted.height) / 2,
            width: fitted.width,
            height: fitted.height
        )
    }

    private func imagePoint(for viewPoint: CGPoint) -> CGPoint? {
        guard let screenshot else { return nil }
        let rect = imageRect
        guard rect.contains(viewPoint) else { return nil }
        return CGPoint(
            x: (viewPoint.x - rect.minX) * CGFloat(screenshot.width) / rect.width,
            y: (viewPoint.y - rect.minY) * CGFloat(screenshot.height) / rect.height
        )
    }

    private func viewPoint(for imagePoint: CGPoint) -> CGPoint {
        guard let screenshot else { return .zero }
        let rect = imageRect
        return CGPoint(
            x: rect.minX + imagePoint.x * rect.width / CGFloat(screenshot.width),
            y: rect.minY + imagePoint.y * rect.height / CGFloat(screenshot.height)
        )
    }

    private func drawArrow(from start: CGPoint, to end: CGPoint) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let angle = atan2(dy, dx)
        let headLength: CGFloat = 12
        let headAngle: CGFloat = .pi / 6
        let left = CGPoint(
            x: end.x - headLength * cos(angle - headAngle),
            y: end.y - headLength * sin(angle - headAngle)
        )
        let right = CGPoint(
            x: end.x - headLength * cos(angle + headAngle),
            y: end.y - headLength * sin(angle + headAngle)
        )

        let path = NSBezierPath()
        path.lineWidth = 3
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: start)
        path.line(to: end)
        path.move(to: end)
        path.line(to: left)
        path.move(to: end)
        path.line(to: right)
        NSColor.systemRed.setStroke()
        path.stroke()
    }

    func imageWithAnnotations() -> NSImage? {
        guard let screenshot else { return nil }
        let width = screenshot.width
        let height = screenshot.height
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: width * 4,
            bitsPerPixel: 32
        ), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        graphics.imageInterpolation = .high
        let imageSize = NSSize(width: width, height: height)
        NSImage(cgImage: screenshot, size: imageSize).draw(
            in: NSRect(origin: .zero, size: imageSize),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        let lineWidth = max(3, CGFloat(min(width, height)) * 0.003)
        for arrow in arrows {
            Self.drawArrow(arrow, imageHeight: height, lineWidth: lineWidth)
        }
        graphics.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        let result = NSImage(size: imageSize)
        result.addRepresentation(bitmap)
        return result
    }

    private static func drawArrow(_ arrow: Arrow, imageHeight: Int, lineWidth: CGFloat) {
        let start = CGPoint(x: arrow.start.x, y: CGFloat(imageHeight) - arrow.start.y)
        let end = CGPoint(x: arrow.end.x, y: CGFloat(imageHeight) - arrow.end.y)
        let dx = end.x - start.x
        let dy = end.y - start.y
        let angle = atan2(dy, dx)
        let headLength = max(14, lineWidth * 4)
        let headAngle = CGFloat.pi / 6
        let left = CGPoint(
            x: end.x - headLength * cos(angle - headAngle),
            y: end.y - headLength * sin(angle - headAngle)
        )
        let right = CGPoint(
            x: end.x - headLength * cos(angle + headAngle),
            y: end.y - headLength * sin(angle + headAngle)
        )

        let path = NSBezierPath()
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: start)
        path.line(to: end)
        path.move(to: end)
        path.line(to: left)
        path.move(to: end)
        path.line(to: right)
        NSColor.systemRed.setStroke()
        path.stroke()
    }
}

import AppKit
import CoreGraphics

@MainActor
final class AnnotationEditorWindow: NSWindow, NSToolbarDelegate, NSWindowDelegate {
    private static let arrowToolID = NSToolbarItem.Identifier("sshooter.arrowTool")
    private static let saveToolID = NSToolbarItem.Identifier("sshooter.saveTool")
    private static let copyToolID = NSToolbarItem.Identifier("sshooter.copyTool")

    private let canvas = AnnotationCanvasView()
    private let onCopy: @MainActor (NSImage) -> Void
    private let onSave: @MainActor (Data) throws -> URL?
    private let onClose: @MainActor () -> Void
    private var hasPositionedWindow = false

    init(
        onCopy: @escaping @MainActor (NSImage) -> Void,
        onSave: @escaping @MainActor (Data) throws -> URL?,
        onClose: @escaping @MainActor () -> Void
    ) {
        self.onCopy = onCopy
        self.onSave = onSave
        self.onClose = onClose
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
        delegate = self
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
        title = "Screenshot"

        let isOnScreen = NSScreen.screens.contains { $0.visibleFrame.intersects(frame) }
        if !hasPositionedWindow || !isOnScreen {
            center()
            hasPositionedWindow = true
        }

        NSApp.activate()
        makeKeyAndOrderFront(nil)
        makeFirstResponder(canvas)
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.arrowToolID, .flexibleSpace, Self.saveToolID, Self.copyToolID]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.arrowToolID, .flexibleSpace, Self.saveToolID, Self.copyToolID]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        switch itemIdentifier {
        case Self.arrowToolID:
            item.label = "Arrow"
            item.paletteLabel = "Arrow"
            item.toolTip = "Click a start point, move, then click an end point."
            item.image = NSImage(systemSymbolName: "arrow.up.right", accessibilityDescription: "Arrow tool")
            item.target = self
            item.action = #selector(selectArrowTool)
        case Self.saveToolID:
            item.label = "Save"
            item.paletteLabel = "Save Screenshot"
            item.toolTip = "Save a PNG to your chosen folder (⌘S)."
            item.image = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: "Save")
            item.target = self
            item.action = #selector(saveScreenshot(_:))
        case Self.copyToolID:
            item.label = "Copy"
            item.paletteLabel = "Copy Screenshot"
            item.toolTip = "Copy the annotated image and close this window (⌘C)."
            item.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy")
            item.target = self
            item.action = #selector(copyScreenshot(_:))
        default:
            return nil
        }
        return item
    }

    @objc private func selectArrowTool() {
        canvas.selectArrowTool()
    }

    @objc func copyScreenshot(_ sender: Any?) {
        guard let image = canvas.imageWithAnnotations() else { return }
        onCopy(image)
        close()
    }

    @objc func saveScreenshot(_ sender: Any?) {
        guard let data = canvas.pngDataWithAnnotations() else {
            presentSaveError(ScreenshotStoreError.encodingFailed)
            return
        }

        do {
            guard let url = try onSave(data) else { return }
            title = "Saved: \(url.lastPathComponent)"
        } catch {
            presentSaveError(error)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.keyCode == 53 {
            if canvas.cancelCurrentAction() { return true }
            close()
            return true
        }

        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        if modifiers == .command, let key = event.charactersIgnoringModifiers?.lowercased() {
            if key == "c" {
                copyScreenshot(nil)
                return true
            }
            if key == "s" {
                saveScreenshot(nil)
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    func windowWillClose(_ notification: Notification) {
        canvas.clear()
        title = "Screenshot"
        onClose()
    }

    private func presentSaveError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Couldn’t save the screenshot"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        if isVisible {
            alert.beginSheetModal(for: self)
        } else {
            alert.runModal()
        }
    }
}

@MainActor
private final class AnnotationCanvasView: NSView {
    private struct Arrow {
        let start: CGPoint
        let end: CGPoint
    }

    private enum ArrowStyle {
        static let minimumLineWidth: CGFloat = 3
        static let lineWidthRatio: CGFloat = 0.003
        static let minimumHeadLength: CGFloat = 14
        static let headLengthRatio: CGFloat = 4

        static func lineWidth(forImageSize size: CGSize) -> CGFloat {
            max(minimumLineWidth, min(size.width, size.height) * lineWidthRatio)
        }

        static func headLength(forLineWidth lineWidth: CGFloat) -> CGFloat {
            max(minimumHeadLength, lineWidth * headLengthRatio)
        }
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

    func clear() {
        screenshot = nil
        screenshotImage = nil
        arrows.removeAll()
        arrowStart = nil
        pointerPosition = nil
        needsDisplay = true
    }

    @discardableResult
    func cancelCurrentAction() -> Bool {
        guard arrowStart != nil else { return false }
        arrowStart = nil
        pointerPosition = nil
        needsDisplay = true
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()

        guard let screenshot, let screenshotImage else { return }
        screenshotImage.draw(in: imageRect)

        let style = previewStyle(for: screenshot)
        for arrow in arrows {
            drawArrow(
                from: viewPoint(for: arrow.start),
                to: viewPoint(for: arrow.end),
                lineWidth: style.lineWidth,
                headLength: style.headLength
            )
        }
        if let arrowStart, let pointerPosition {
            drawArrow(
                from: viewPoint(for: arrowStart),
                to: viewPoint(for: pointerPosition),
                lineWidth: style.lineWidth,
                headLength: style.headLength
            )
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard arrowToolIsSelected else { return }
        guard let point = imagePoint(for: convert(event.locationInWindow, from: nil)) else {
            cancelCurrentAction()
            return
        }

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
        if event.keyCode == 53 {
            if !cancelCurrentAction() {
                window?.performKeyEquivalent(with: event)
            }
        } else if event.modifierFlags.contains(.command) {
            if window?.performKeyEquivalent(with: event) != true {
                super.keyDown(with: event)
            }
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

    private func previewStyle(for screenshot: CGImage) -> (lineWidth: CGFloat, headLength: CGFloat) {
        let imageSize = CGSize(width: screenshot.width, height: screenshot.height)
        let imageLineWidth = ArrowStyle.lineWidth(forImageSize: imageSize)
        let imageHeadLength = ArrowStyle.headLength(forLineWidth: imageLineWidth)
        let scale = imageSize.width > 0 ? imageRect.width / imageSize.width : 1
        return (imageLineWidth * scale, imageHeadLength * scale)
    }

    private func drawArrow(from start: CGPoint, to end: CGPoint, lineWidth: CGFloat, headLength: CGFloat) {
        let path = Self.arrowPath(from: start, to: end, lineWidth: lineWidth, headLength: headLength)
        NSColor.systemRed.setStroke()
        path.stroke()
    }

    func imageWithAnnotations() -> NSImage? {
        guard let image = renderCGImage() else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }

    func pngDataWithAnnotations() -> Data? {
        guard let image = renderCGImage() else { return nil }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    private func renderCGImage() -> CGImage? {
        guard let screenshot else { return nil }
        let width = screenshot.width
        let height = screenshot.height
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }

        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        context.interpolationQuality = .high
        context.draw(screenshot, in: bounds)

        let imageSize = CGSize(width: width, height: height)
        let lineWidth = ArrowStyle.lineWidth(forImageSize: imageSize)
        let headLength = ArrowStyle.headLength(forLineWidth: lineWidth)
        let strokeColor = (NSColor.systemRed.usingColorSpace(.sRGB) ?? NSColor.systemRed).cgColor
        context.setStrokeColor(strokeColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        for arrow in arrows {
            let path = Self.arrowPath(
                from: flipped(arrow.start, imageHeight: height),
                to: flipped(arrow.end, imageHeight: height),
                lineWidth: lineWidth,
                headLength: headLength
            )
            context.addPath(path.cgPath)
            context.strokePath()
        }

        return context.makeImage()
    }

    private func flipped(_ point: CGPoint, imageHeight: Int) -> CGPoint {
        CGPoint(x: point.x, y: CGFloat(imageHeight) - point.y)
    }

    private static func arrowPath(
        from start: CGPoint,
        to end: CGPoint,
        lineWidth: CGFloat,
        headLength: CGFloat
    ) -> NSBezierPath {
        let angle = atan2(end.y - start.y, end.x - start.x)
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
        return path
    }
}

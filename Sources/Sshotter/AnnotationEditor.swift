import AppKit
import CoreGraphics

// MARK: - Arrow style

enum ArrowLineWidth: Int, CaseIterable {
    case thin
    case regular
    case bold
    case extraBold

    var title: String {
        switch self {
        case .thin: "Thin"
        case .regular: "Regular"
        case .bold: "Bold"
        case .extraBold: "Extra Bold"
        }
    }

    var multiplier: CGFloat {
        switch self {
        case .thin: 0.6
        case .regular: 1
        case .bold: 1.7
        case .extraBold: 2.6
        }
    }
}

enum ArrowHeadSize: Int, CaseIterable {
    case small
    case medium
    case large

    var title: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }

    var multiplier: CGFloat {
        switch self {
        case .small: 2.6
        case .medium: 4
        case .large: 6
        }
    }
}

enum ArrowPreferences {
    private static let lineWidthKey = "arrowLineWidth"
    private static let headSizeKey = "arrowHeadSize"

    static var lineWidth: ArrowLineWidth {
        get {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: lineWidthKey) != nil,
                  let value = ArrowLineWidth(rawValue: defaults.integer(forKey: lineWidthKey)) else {
                return .regular
            }
            return value
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: lineWidthKey)
        }
    }

    static var headSize: ArrowHeadSize {
        get {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: headSizeKey) != nil,
                  let value = ArrowHeadSize(rawValue: defaults.integer(forKey: headSizeKey)) else {
                return .medium
            }
            return value
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: headSizeKey)
        }
    }
}

enum ArrowGeometry {
    static func lineWidth(forImageSize size: CGSize, thickness: ArrowLineWidth) -> CGFloat {
        let base = max(3, min(size.width, size.height) * 0.003)
        return base * thickness.multiplier
    }

    static func headLength(forLineWidth lineWidth: CGFloat, headSize: ArrowHeadSize) -> CGFloat {
        max(10, lineWidth * headSize.multiplier)
    }

    static func path(
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

// MARK: - Editor window

@MainActor
final class AnnotationEditorWindow: NSWindow, NSToolbarDelegate, NSWindowDelegate {
    private static let arrowToolID = NSToolbarItem.Identifier("sshooter.arrowTool")
    private static let thicknessToolID = NSToolbarItem.Identifier("sshooter.thicknessTool")
    private static let headSizeToolID = NSToolbarItem.Identifier("sshooter.headSizeTool")
    private static let saveToolID = NSToolbarItem.Identifier("sshooter.saveTool")
    private static let copyToolID = NSToolbarItem.Identifier("sshooter.copyTool")

    private let canvas = AnnotationCanvasView()
    private let onCopy: @MainActor (NSImage) -> Void
    private let onSave: @MainActor (Data) throws -> URL?
    private let onClose: @MainActor () -> Void
    private var hasPositionedWindow = false

    private var lineWidth = ArrowPreferences.lineWidth
    private var headSize = ArrowPreferences.headSize
    private var thicknessMenu: NSMenu?
    private var headSizeMenu: NSMenu?
    private var thicknessItem: NSMenuToolbarItem?
    private var headSizeItem: NSMenuToolbarItem?

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
        canvas.setLineWidth(lineWidth)
        canvas.setHeadSize(headSize)
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
        [
            Self.arrowToolID,
            Self.thicknessToolID,
            Self.headSizeToolID,
            .flexibleSpace,
            Self.saveToolID,
            Self.copyToolID
        ]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            Self.arrowToolID,
            Self.thicknessToolID,
            Self.headSizeToolID,
            .flexibleSpace,
            Self.saveToolID,
            Self.copyToolID
        ]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case Self.arrowToolID:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Arrow"
            item.paletteLabel = "Arrow"
            item.toolTip = "Click and drag on the image to draw an arrow."
            item.image = NSImage(systemSymbolName: "arrow.up.right", accessibilityDescription: "Arrow tool")
            item.target = self
            item.action = #selector(selectArrowTool)
            return item
        case Self.thicknessToolID:
            let item = NSMenuToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Thickness"
            item.paletteLabel = "Arrow Thickness"
            item.image = NSImage(systemSymbolName: "lineweight", accessibilityDescription: "Arrow thickness")
            let menu = makeLineWidthMenu()
            item.menu = menu
            thicknessMenu = menu
            thicknessItem = item
            updateStyleMenuStates()
            return item
        case Self.headSizeToolID:
            let item = NSMenuToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Head Size"
            item.paletteLabel = "Arrow Head Size"
            item.image = NSImage(systemSymbolName: "arrowtriangle.up", accessibilityDescription: "Arrow head size")
            let menu = makeHeadSizeMenu()
            item.menu = menu
            headSizeMenu = menu
            headSizeItem = item
            updateStyleMenuStates()
            return item
        case Self.saveToolID:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Save"
            item.paletteLabel = "Save Screenshot"
            item.toolTip = "Save a PNG to your chosen folder (⌘S)."
            item.image = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: "Save")
            item.target = self
            item.action = #selector(saveScreenshot(_:))
            return item
        case Self.copyToolID:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Copy"
            item.paletteLabel = "Copy Screenshot"
            item.toolTip = "Copy the annotated image and close this window (⌘C)."
            item.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy")
            item.target = self
            item.action = #selector(copyScreenshot(_:))
            return item
        default:
            return nil
        }
    }

    private func makeLineWidthMenu() -> NSMenu {
        let menu = NSMenu()
        for value in ArrowLineWidth.allCases {
            let item = NSMenuItem(
                title: value.title,
                action: #selector(selectLineWidth(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = value.rawValue
            menu.addItem(item)
        }
        return menu
    }

    private func makeHeadSizeMenu() -> NSMenu {
        let menu = NSMenu()
        for value in ArrowHeadSize.allCases {
            let item = NSMenuItem(
                title: value.title,
                action: #selector(selectHeadSize(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = value.rawValue
            menu.addItem(item)
        }
        return menu
    }

    private func updateStyleMenuStates() {
        for item in thicknessMenu?.items ?? [] {
            item.state = item.tag == lineWidth.rawValue ? .on : .off
        }
        for item in headSizeMenu?.items ?? [] {
            item.state = item.tag == headSize.rawValue ? .on : .off
        }
        thicknessItem?.toolTip = "Arrow thickness: \(lineWidth.title)"
        headSizeItem?.toolTip = "Arrow head size: \(headSize.title)"
    }

    @objc private func selectArrowTool() {
        canvas.activateArrowTool()
        makeFirstResponder(canvas)
    }

    @objc private func selectLineWidth(_ sender: NSMenuItem) {
        guard let value = ArrowLineWidth(rawValue: sender.tag) else { return }
        lineWidth = value
        ArrowPreferences.lineWidth = value
        canvas.setLineWidth(value)
        updateStyleMenuStates()
        makeFirstResponder(canvas)
    }

    @objc private func selectHeadSize(_ sender: NSMenuItem) {
        guard let value = ArrowHeadSize(rawValue: sender.tag) else { return }
        headSize = value
        ArrowPreferences.headSize = value
        canvas.setHeadSize(value)
        updateStyleMenuStates()
        makeFirstResponder(canvas)
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
            if canvas.handleEscape() { return true }
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

// MARK: - Canvas

@MainActor
private final class AnnotationCanvasView: NSView {
    private struct Arrow {
        var start: CGPoint
        var end: CGPoint
    }

    private enum DragMode {
        case drawing(start: CGPoint)
        case moving(index: Int, original: Arrow, grabOffset: CGPoint)
        case resizingStart(index: Int)
        case resizingEnd(index: Int)
    }

    private enum HitTarget {
        case start(Int)
        case end(Int)
        case body(Int)
    }

    private let handleRadius: CGFloat = 6
    private let minimumDragDistance: CGFloat = 4

    private var screenshot: CGImage?
    private var screenshotImage: NSImage?
    private var arrows: [Arrow] = []
    private var selectedArrowIndex: Int?
    private var dragMode: DragMode?
    private var pointerPosition: CGPoint?
    private var lineWidthSetting: ArrowLineWidth = .regular
    private var headSizeSetting: ArrowHeadSize = .medium
    private var trackingArea: NSTrackingArea?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    func setImage(_ image: CGImage) {
        screenshot = image
        screenshotImage = NSImage(
            cgImage: image,
            size: NSSize(width: image.width, height: image.height)
        )
        arrows.removeAll()
        selectedArrowIndex = nil
        dragMode = nil
        pointerPosition = nil
        needsDisplay = true
    }

    func clear() {
        screenshot = nil
        screenshotImage = nil
        arrows.removeAll()
        selectedArrowIndex = nil
        dragMode = nil
        pointerPosition = nil
        needsDisplay = true
    }

    func setLineWidth(_ value: ArrowLineWidth) {
        lineWidthSetting = value
        needsDisplay = true
    }

    func setHeadSize(_ value: ArrowHeadSize) {
        headSizeSetting = value
        needsDisplay = true
    }

    func activateArrowTool() {
        selectedArrowIndex = nil
        dragMode = nil
        pointerPosition = nil
        needsDisplay = true
    }

    /// Handles Esc: first an in-progress drag, then the current selection.
    /// Returns false when there is nothing left to cancel.
    @discardableResult
    func handleEscape() -> Bool {
        if dragMode != nil {
            dragMode = nil
            pointerPosition = nil
            needsDisplay = true
            return true
        }
        if selectedArrowIndex != nil {
            selectedArrowIndex = nil
            needsDisplay = true
            return true
        }
        return false
    }

    @discardableResult
    func deleteSelectedArrow() -> Bool {
        guard let index = selectedArrowIndex, arrows.indices.contains(index) else { return false }
        arrows.remove(at: index)
        selectedArrowIndex = nil
        needsDisplay = true
        return true
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()

        guard let screenshot, let screenshotImage else { return }
        screenshotImage.draw(in: imageRect)

        let style = imageStyle(for: screenshot)
        let scale = imageScale(for: screenshot)
        let viewLineWidth = style.lineWidth * scale
        let viewHeadLength = style.headLength * scale

        for (index, arrow) in arrows.enumerated() {
            drawArrow(
                from: viewPoint(for: arrow.start),
                to: viewPoint(for: arrow.end),
                lineWidth: viewLineWidth,
                headLength: viewHeadLength
            )
            if index == selectedArrowIndex {
                drawHandles(for: arrow)
            }
        }

        if case .drawing(let start)? = dragMode, let pointerPosition {
            drawArrow(
                from: viewPoint(for: start),
                to: viewPoint(for: pointerPosition),
                lineWidth: viewLineWidth,
                headLength: viewHeadLength
            )
        }
    }

    private func drawArrow(from start: CGPoint, to end: CGPoint, lineWidth: CGFloat, headLength: CGFloat) {
        let path = ArrowGeometry.path(
            from: start,
            to: end,
            lineWidth: lineWidth,
            headLength: headLength
        )
        NSColor.systemRed.setStroke()
        path.stroke()
    }

    private func drawHandles(for arrow: Arrow) {
        for point in [viewPoint(for: arrow.start), viewPoint(for: arrow.end)] {
            let rect = NSRect(
                x: point.x - handleRadius,
                y: point.y - handleRadius,
                width: handleRadius * 2,
                height: handleRadius * 2
            )
            let path = NSBezierPath(ovalIn: rect)
            NSColor.white.setFill()
            path.fill()
            NSColor.systemRed.setStroke()
            path.lineWidth = 2
            path.stroke()
        }
    }

    // MARK: Mouse handling

    override func mouseDown(with event: NSEvent) {
        let viewPoint = convert(event.locationInWindow, from: nil)
        guard screenshot != nil, let imagePoint = imagePoint(for: viewPoint) else {
            selectedArrowIndex = nil
            dragMode = nil
            needsDisplay = true
            return
        }

        if let target = hitTest(at: viewPoint) {
            switch target {
            case .start(let index):
                selectedArrowIndex = index
                dragMode = .resizingStart(index: index)
            case .end(let index):
                selectedArrowIndex = index
                dragMode = .resizingEnd(index: index)
            case .body(let index):
                let arrow = arrows[index]
                selectedArrowIndex = index
                dragMode = .moving(
                    index: index,
                    original: arrow,
                    grabOffset: CGPoint(
                        x: imagePoint.x - arrow.start.x,
                        y: imagePoint.y - arrow.start.y
                    )
                )
            }
            NSCursor.closedHand.set()
        } else {
            selectedArrowIndex = nil
            dragMode = .drawing(start: imagePoint)
            pointerPosition = imagePoint
            NSCursor.crosshair.set()
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let screenshot, let mode = dragMode else { return }
        let viewPoint = convert(event.locationInWindow, from: nil)
        guard let point = clampedImagePoint(for: viewPoint) else { return }

        switch mode {
        case .drawing:
            pointerPosition = point
        case let .moving(index, original, grabOffset):
            let proposedStart = CGPoint(
                x: point.x - grabOffset.x,
                y: point.y - grabOffset.y
            )
            var dx = proposedStart.x - original.start.x
            var dy = proposedStart.y - original.start.y

            let minX = min(original.start.x, original.end.x)
            let maxX = max(original.start.x, original.end.x)
            let minY = min(original.start.y, original.end.y)
            let maxY = max(original.start.y, original.end.y)
            dx = min(max(dx, -minX), CGFloat(screenshot.width) - maxX)
            dy = min(max(dy, -minY), CGFloat(screenshot.height) - maxY)

            arrows[index].start = CGPoint(x: original.start.x + dx, y: original.start.y + dy)
            arrows[index].end = CGPoint(x: original.end.x + dx, y: original.end.y + dy)
        case .resizingStart(let index):
            arrows[index].start = point
        case .resizingEnd(let index):
            arrows[index].end = point
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let mode = dragMode else { return }
        dragMode = nil

        let pointInView = convert(event.locationInWindow, from: nil)
        if case .drawing(let start) = mode,
           let end = clampedImagePoint(for: pointInView) {
            let startInView = viewPoint(for: start)
            let endInView = viewPoint(for: end)
            if distance(from: startInView, to: endInView) >= minimumDragDistance {
                arrows.append(Arrow(start: start, end: end))
                selectedArrowIndex = arrows.count - 1
            } else {
                selectedArrowIndex = nil
            }
        }

        pointerPosition = nil
        updateCursor(at: pointInView)
        needsDisplay = true
    }

    override func mouseMoved(with event: NSEvent) {
        updateCursor(at: convert(event.locationInWindow, from: nil))
    }

    override func cursorUpdate(with event: NSEvent) {
        updateCursor(at: convert(event.locationInWindow, from: nil))
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .cursorUpdate, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        NSCursor.crosshair.set()
    }

    private func updateCursor(at viewPoint: CGPoint) {
        guard dragMode == nil else { return }
        if imagePoint(for: viewPoint) != nil, hitTest(at: viewPoint) != nil {
            NSCursor.openHand.set()
        } else {
            NSCursor.crosshair.set()
        }
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            if !handleEscape() {
                window?.performKeyEquivalent(with: event)
            }
            return
        }

        if event.keyCode == 51 || event.keyCode == 117 {
            if deleteSelectedArrow() { return }
        }

        if event.modifierFlags.contains(.command) {
            if window?.performKeyEquivalent(with: event) != true {
                super.keyDown(with: event)
            }
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: Hit testing

    private func hitTest(at point: CGPoint) -> HitTarget? {
        guard let screenshot else { return nil }
        let style = imageStyle(for: screenshot)
        let bodyTolerance = max(6, style.lineWidth * imageScale(for: screenshot) * 2.5)
        let endpointTolerance = handleRadius + 3

        for index in arrows.indices.reversed() {
            let start = viewPoint(for: arrows[index].start)
            let end = viewPoint(for: arrows[index].end)
            if distance(from: point, to: end) <= endpointTolerance {
                return .end(index)
            }
            if distance(from: point, to: start) <= endpointTolerance {
                return .start(index)
            }
        }

        for index in arrows.indices.reversed() {
            let start = viewPoint(for: arrows[index].start)
            let end = viewPoint(for: arrows[index].end)
            if distance(from: point, toSegmentFrom: start, to: end) <= bodyTolerance {
                return .body(index)
            }
        }

        return nil
    }

    private func distance(from a: CGPoint, to b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func distance(from point: CGPoint, toSegmentFrom start: CGPoint, to end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return distance(from: point, to: start) }

        var t = ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared
        t = min(max(t, 0), 1)
        let projection = CGPoint(x: start.x + t * dx, y: start.y + t * dy)
        return distance(from: point, to: projection)
    }

    // MARK: Geometry

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

    private func imageScale(for screenshot: CGImage) -> CGFloat {
        guard screenshot.width > 0 else { return 1 }
        return imageRect.width / CGFloat(screenshot.width)
    }

    private func imageStyle(for screenshot: CGImage) -> (lineWidth: CGFloat, headLength: CGFloat) {
        let size = CGSize(width: screenshot.width, height: screenshot.height)
        let lineWidth = ArrowGeometry.lineWidth(forImageSize: size, thickness: lineWidthSetting)
        let headLength = ArrowGeometry.headLength(forLineWidth: lineWidth, headSize: headSizeSetting)
        return (lineWidth, headLength)
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

    private func clampedImagePoint(for viewPoint: CGPoint) -> CGPoint? {
        guard let screenshot else { return nil }
        let rect = imageRect
        let x = min(max(viewPoint.x, rect.minX), rect.maxX)
        let y = min(max(viewPoint.y, rect.minY), rect.maxY)
        return CGPoint(
            x: (x - rect.minX) * CGFloat(screenshot.width) / rect.width,
            y: (y - rect.minY) * CGFloat(screenshot.height) / rect.height
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

    // MARK: Export

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

        let imageBounds = CGRect(x: 0, y: 0, width: width, height: height)
        context.interpolationQuality = .high
        context.draw(screenshot, in: imageBounds)

        let style = imageStyle(for: screenshot)
        let strokeColor = (NSColor.systemRed.usingColorSpace(.sRGB) ?? NSColor.systemRed).cgColor
        context.setStrokeColor(strokeColor)
        context.setLineWidth(style.lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        for arrow in arrows {
            let path = ArrowGeometry.path(
                from: flipped(arrow.start, imageHeight: height),
                to: flipped(arrow.end, imageHeight: height),
                lineWidth: style.lineWidth,
                headLength: style.headLength
            )
            context.addPath(path.cgPath)
            context.strokePath()
        }

        return context.makeImage()
    }

    private func flipped(_ point: CGPoint, imageHeight: Int) -> CGPoint {
        CGPoint(x: point.x, y: CGFloat(imageHeight) - point.y)
    }
}

import AppKit
import CoreGraphics
import CoreImage

// MARK: - Arrow style

enum ArrowColor: Int, CaseIterable {
    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    case black
    case white

    var title: String {
        switch self {
        case .red: "Red"
        case .orange: "Orange"
        case .yellow: "Yellow"
        case .green: "Green"
        case .blue: "Blue"
        case .purple: "Purple"
        case .black: "Black"
        case .white: "White"
        }
    }

    var nsColor: NSColor {
        switch self {
        case .red: .systemRed
        case .orange: .systemOrange
        case .yellow: .systemYellow
        case .green: .systemGreen
        case .blue: .systemBlue
        case .purple: .systemPurple
        case .black: .black
        case .white: .white
        }
    }

    var cgColor: CGColor {
        (nsColor.usingColorSpace(.sRGB) ?? nsColor).cgColor
    }
}

enum AnnotationTool {
    case arrow
    case square
    case blur
    case pencil
    case highlight
    case text
}

/// The two freehand tools share one stroke model and the same smoothing. They
/// differ only in how thick the base stroke is and how opaque the result is: a
/// pencil is a thin, solid line, a marker is a broad, translucent one.
enum FreehandStyle: Int {
    case pencil
    case highlight

    /// Base stroke width, as a fraction of the image's smaller dimension.
    var baseScale: CGFloat {
        switch self {
        case .pencil: 0.003
        case .highlight: 0.012
        }
    }

    /// Floor for the base stroke, so small captures still get a usable line.
    var baseMinimum: CGFloat {
        switch self {
        case .pencil: 3
        case .highlight: 8
        }
    }

    /// Pencils are solid; markers are translucent so what they cover stays
    /// readable.
    var alpha: CGFloat {
        switch self {
        case .pencil: 1
        case .highlight: 0.4
        }
    }

    var defaultColor: ArrowColor {
        switch self {
        case .pencil: .red
        case .highlight: .yellow
        }
    }
}

/// Fill levels for the square tool. `full` means fully transparent (outline
/// only); the border is always opaque regardless of this value.
enum SquareFill: Int, CaseIterable {
    case full
    case medium
    case opaque

    var title: String {
        switch self {
        case .full: "Full transparency"
        case .medium: "Medium transparency"
        case .opaque: "Opaque fill"
        }
    }

    var fillAlpha: CGFloat {
        switch self {
        case .full: 0
        case .medium: 0.5
        case .opaque: 1
        }
    }
}

enum SquarePreferences {
    private static let roundedKey = "squareRoundedCorners"
    private static let fillKey = "squareFillLevel"

    static var isRounded: Bool {
        get {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: roundedKey) != nil else { return false }
            return defaults.bool(forKey: roundedKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: roundedKey)
        }
    }

    static var fill: SquareFill {
        get {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: fillKey) != nil,
                  let value = SquareFill(rawValue: defaults.integer(forKey: fillKey)) else {
                return .medium
            }
            return value
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: fillKey)
        }
    }
}

enum ArrowPreferences {
    private static let colorKey = "arrowColor"
    private static let lineWidthKey = "arrowStrokeWidth"

    static var color: ArrowColor {
        get {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: colorKey) != nil,
                  let value = ArrowColor(rawValue: defaults.integer(forKey: colorKey)) else {
                return .red
            }
            return value
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: colorKey)
        }
    }

    /// Continuous stroke width, as a multiple of the base stroke. Clamped to
    /// the slider's range so hand-edited or stale values stay usable.
    static var lineWidth: CGFloat {
        get {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: lineWidthKey) != nil else {
                return ArrowGeometry.defaultMultiplier
            }
            let value = CGFloat(defaults.double(forKey: lineWidthKey))
            return min(
                max(value, ArrowGeometry.minimumMultiplier),
                ArrowGeometry.maximumMultiplier
            )
        }
        set {
            UserDefaults.standard.set(Double(newValue), forKey: lineWidthKey)
        }
    }
}

enum FreehandPreferences {
    private static func colorKey(for style: FreehandStyle) -> String {
        switch style {
        case .pencil: "pencilColor"
        case .highlight: "highlightColor"
        }
    }

    private static func widthKey(for style: FreehandStyle) -> String {
        switch style {
        case .pencil: "pencilStrokeWidth"
        case .highlight: "highlightStrokeWidth"
        }
    }

    static func color(for style: FreehandStyle) -> ArrowColor {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: colorKey(for: style)) != nil,
              let value = ArrowColor(rawValue: defaults.integer(forKey: colorKey(for: style))) else {
            return style.defaultColor
        }
        return value
    }

    static func setColor(_ color: ArrowColor, for style: FreehandStyle) {
        UserDefaults.standard.set(color.rawValue, forKey: colorKey(for: style))
    }

    /// Continuous width, as a multiple of the base stroke. Clamped to the
    /// slider's range so hand-edited or stale values stay usable.
    static func lineWidth(for style: FreehandStyle) -> CGFloat {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: widthKey(for: style)) != nil else {
            return FreehandGeometry.defaultMultiplier
        }
        let value = CGFloat(defaults.double(forKey: widthKey(for: style)))
        return min(
            max(value, FreehandGeometry.minimumMultiplier),
            FreehandGeometry.maximumMultiplier
        )
    }

    static func setLineWidth(_ width: CGFloat, for style: FreehandStyle) {
        UserDefaults.standard.set(Double(width), forKey: widthKey(for: style))
    }
}

/// Fill choices for the text tool. `clear` renders plain text without a
/// background; every other case fills a rectangle behind the text.
enum TextBackground: Int, CaseIterable {
    case clear
    case white
    case yellow
    case black
    case blue

    var title: String {
        switch self {
        case .clear: "No background"
        case .white: "White background"
        case .yellow: "Yellow background"
        case .black: "Black background"
        case .blue: "Blue background"
        }
    }

    var nsColor: NSColor? {
        switch self {
        case .clear: nil
        case .white: .white
        case .yellow: .systemYellow
        case .black: .black
        case .blue: .systemBlue
        }
    }
}

enum TextPreferences {
    static let minimumScale: CGFloat = 0.75
    static let maximumScale: CGFloat = 16
    private static let colorKey = "textColor"
    private static let backgroundKey = "textBackground"
    private static let scaleKey = "textScale"

    static var color: ArrowColor {
        get {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: colorKey) != nil,
                  let value = ArrowColor(rawValue: defaults.integer(forKey: colorKey)) else {
                return .black
            }
            return value
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: colorKey)
        }
    }

    static var background: TextBackground {
        get {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: backgroundKey) != nil,
                  let value = TextBackground(rawValue: defaults.integer(forKey: backgroundKey)) else {
                return .white
            }
            return value
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: backgroundKey)
        }
    }

    /// Multiplier applied to the image-relative base font size.
    static var scale: CGFloat {
        get {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: scaleKey) != nil else { return 1 }
            let value = defaults.double(forKey: scaleKey)
            return min(max(value, Double(minimumScale)), Double(maximumScale))
        }
        set {
            let clampedValue = min(max(newValue, minimumScale), maximumScale)
            UserDefaults.standard.set(Double(clampedValue), forKey: scaleKey)
        }
    }
}

enum ArrowGeometry {
    /// Continuous stroke-width range, as multiples of the base stroke. Arrows
    /// and squares share it. The narrow end is twice the old thinnest preset and
    /// the wide end is three times the old thickest, so the slider reaches well
    /// past the old presets on the thick side.
    static let minimumMultiplier: CGFloat = 1.2
    static let maximumMultiplier: CGFloat = 7.8
    static let defaultMultiplier: CGFloat = 1.7

    static func lineWidth(forImageSize size: CGSize, multiplier: CGFloat) -> CGFloat {
        let base = max(3, min(size.width, size.height) * 0.003)
        return base * multiplier
    }

    /// The head scales with the line, so thicker arrows get proportionally
    /// larger heads without a separate setting.
    static func headLength(forLineWidth lineWidth: CGFloat) -> CGFloat {
        max(10, lineWidth * 4)
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

enum FreehandGeometry {
    /// Continuous width range, as multiples of the base stroke. Both freehand
    /// tools use it; the base stroke itself differs per style.
    static let minimumMultiplier: CGFloat = 1.2
    static let maximumMultiplier: CGFloat = 7.8
    static let defaultMultiplier: CGFloat = 1.7

    /// The marker's base is deliberately chunkier than the pencil's, so a
    /// marker stays broad and a pencil stays fine at the same multiplier.
    static func lineWidth(
        forImageSize size: CGSize,
        style: FreehandStyle,
        multiplier: CGFloat
    ) -> CGFloat {
        let base = max(style.baseMinimum, min(size.width, size.height) * style.baseScale)
        return base * multiplier
    }

    /// A smoothed freehand path through the sampled points. Consecutive
    /// midpoints become quadratic curve endpoints, which removes the polyline
    /// look without pulling the stroke away from where the pointer went.
    static func path(points: [CGPoint], transform: (CGPoint) -> CGPoint) -> NSBezierPath {
        let path = NSBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        guard let first = points.first else { return path }
        path.move(to: transform(first))

        guard points.count > 2 else {
            if let last = points.last, points.count == 2 {
                path.line(to: transform(last))
            }
            return path
        }

        for index in 1..<(points.count - 1) {
            let current = points[index]
            let next = points[index + 1]
            let midpoint = CGPoint(
                x: (current.x + next.x) / 2,
                y: (current.y + next.y) / 2
            )
            path.curve(to: transform(midpoint), controlPoint: transform(current))
        }
        if let last = points.last {
            path.line(to: transform(last))
        }
        return path
    }
}

// MARK: - Editor window

@MainActor
final class AnnotationEditorWindow: NSWindow, NSWindowDelegate {
    private let container = EditorContainerView()
    private let toolStrip = EditorToolStrip()
    private let canvas = AnnotationCanvasView()
    private let onCopy: @MainActor (NSImage) -> Void
    private let onSave: @MainActor (Data) throws -> URL?
    private let onClose: @MainActor () -> Void
    private var hasPositionedWindow = false

    private let copyButton = ToolStripButton(
        symbolName: "doc.on.doc",
        toolTip: "Copy the annotated image and close this window (⌘C)"
    )
    private let saveButton = ToolStripButton(
        symbolName: "square.and.arrow.down",
        toolTip: "Save a PNG to your chosen folder (⌘S)"
    )
    private let pointerButton = ToolStripButton(
        symbolName: "cursorarrow",
        toolTip: "Pointer tool: clicking the image does nothing."
    )
    private let arrowButton = ToolStripButton(
        symbolName: "arrow.up.right",
        toolTip: "Arrow tool: drag on the canvas to draw. Click again to stop drawing."
    )
    private let squareButton = ToolStripButton(
        symbolName: "square",
        toolTip: "Square tool: drag on the canvas to mark an area. Click again to stop drawing."
    )
    private let blurButton = ToolStripButton(
        resourceName: "BlurToolIcon",
        toolTip: "Blur tool: drag over an area to blur it. Click again to stop drawing."
    )
    private let pencilButton = ToolStripButton(
        symbolName: "pencil.and.scribble",
        toolTip: "Pencil tool: drag to draw a solid freehand line. Click again to stop drawing."
    )
    private let highlightButton = ToolStripButton(
        symbolName: "highlighter",
        toolTip: "Highlight tool: drag to draw a translucent marker stroke. Click again to stop drawing."
    )
    private let textButton = ToolStripButton(
        symbolName: "character.cursor.ibeam",
        toolTip: "Text tool: click the canvas to add text. Drag text to move it; double-click to edit."
    )
    private let cropButton = ToolStripButton(
        symbolName: "crop",
        toolTip: "Crop tool: drag to choose the area to keep, then press Return to crop."
    )

    init(
        onCopy: @escaping @MainActor (NSImage) -> Void,
        onSave: @escaping @MainActor (Data) throws -> URL?,
        onClose: @escaping @MainActor () -> Void
    ) {
        self.onCopy = onCopy
        self.onSave = onSave
        self.onClose = onClose
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        title = "sShooter"
        minSize = NSSize(width: 600, height: 420)
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        delegate = self

        contentView = container
        configureToolStrip()
        configureCanvas()

        canvas.onCropSessionChanged = { [weak self] in
            guard let self else { return }
            if !self.canvas.isCropping {
                // Applying or cancelling a crop returns to the Pointer tool.
                self.canvas.setTool(nil)
            }
            self.updateToolButtons(active: self.canvas.activeTool)
        }

        canvas.setTool(nil)
        updateToolButtons(active: nil)
    }

    // MARK: Setup

    private func configureToolStrip() {
        toolStrip.translatesAutoresizingMaskIntoConstraints = false

        copyButton.frame = NSRect(x: 12, y: 8, width: 32, height: 32)
        copyButton.target = self
        copyButton.action = #selector(copyScreenshot(_:))
        toolStrip.addSubview(copyButton)

        saveButton.frame = NSRect(x: 52, y: 8, width: 32, height: 32)
        saveButton.target = self
        saveButton.action = #selector(saveScreenshot(_:))
        toolStrip.addSubview(saveButton)

        pointerButton.frame = NSRect(x: 106, y: 8, width: 40, height: 32)
        pointerButton.target = self
        pointerButton.action = #selector(selectPointerTool(_:))
        toolStrip.addSubview(pointerButton)

        arrowButton.frame = NSRect(x: 150, y: 8, width: 40, height: 32)
        arrowButton.target = self
        arrowButton.action = #selector(toggleArrowTool(_:))
        toolStrip.addSubview(arrowButton)

        squareButton.frame = NSRect(x: 194, y: 8, width: 40, height: 32)
        squareButton.target = self
        squareButton.action = #selector(toggleSquareTool(_:))
        toolStrip.addSubview(squareButton)

        blurButton.frame = NSRect(x: 238, y: 8, width: 40, height: 32)
        blurButton.target = self
        blurButton.action = #selector(toggleBlurTool(_:))
        toolStrip.addSubview(blurButton)

        pencilButton.frame = NSRect(x: 282, y: 8, width: 40, height: 32)
        pencilButton.target = self
        pencilButton.action = #selector(togglePencilTool(_:))
        toolStrip.addSubview(pencilButton)

        highlightButton.frame = NSRect(x: 326, y: 8, width: 40, height: 32)
        highlightButton.target = self
        highlightButton.action = #selector(toggleHighlightTool(_:))
        toolStrip.addSubview(highlightButton)

        textButton.frame = NSRect(x: 370, y: 8, width: 40, height: 32)
        textButton.target = self
        textButton.action = #selector(toggleTextTool(_:))
        toolStrip.addSubview(textButton)

        cropButton.frame = NSRect(x: 414, y: 8, width: 40, height: 32)
        cropButton.target = self
        cropButton.action = #selector(toggleCropTool(_:))
        toolStrip.addSubview(cropButton)

        container.addSubview(toolStrip)
        NSLayoutConstraint.activate([
            toolStrip.topAnchor.constraint(equalTo: container.topAnchor),
            toolStrip.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            toolStrip.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            toolStrip.heightAnchor.constraint(equalToConstant: EditorToolStrip.height)
        ])
    }

    private func configureCanvas() {
        canvas.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(canvas)
        NSLayoutConstraint.activate([
            canvas.topAnchor.constraint(equalTo: toolStrip.bottomAnchor),
            canvas.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            canvas.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }

    // MARK: Presentation

    func present(image: CGImage) {
        canvas.setImage(image)
        title = "sShooter"

        let isOnScreen = NSScreen.screens.contains { $0.visibleFrame.intersects(frame) }
        if !hasPositionedWindow || !isOnScreen {
            center()
            hasPositionedWindow = true
        }

        selectPointerTool(nil)
        NSApp.activate()
        makeKeyAndOrderFront(nil)
        makeFirstResponder(canvas)
    }

    /// Whether there is still a capture with its annotations to show again.
    var hasContent: Bool { canvas.hasImage }

    /// Brings the previously closed editor back with its content and camera
    /// exactly as they were.
    func reopen() {
        guard hasContent else { return }
        makeKeyAndOrderFront(nil)
        makeFirstResponder(canvas)
    }

    // MARK: Actions

    @objc private func toggleArrowTool(_ sender: Any?) {
        toggleTool(.arrow)
    }

    @objc private func toggleSquareTool(_ sender: Any?) {
        toggleTool(.square)
    }

    @objc private func toggleBlurTool(_ sender: Any?) {
        toggleTool(.blur)
    }

    @objc private func togglePencilTool(_ sender: Any?) {
        toggleTool(.pencil)
    }

    @objc private func toggleHighlightTool(_ sender: Any?) {
        toggleTool(.highlight)
    }

    @objc private func toggleTextTool(_ sender: Any?) {
        toggleTool(.text)
    }

    @objc private func toggleCropTool(_ sender: Any?) {
        if canvas.isCropping {
            canvas.cancelCropSession()
        } else {
            canvas.beginCropSession()
        }
        makeFirstResponder(canvas)
    }

    @objc func undoAnnotation(_ sender: Any?) {
        canvas.undoAnnotationOrTextEdit(redo: false)
    }

    @objc func redoAnnotation(_ sender: Any?) {
        canvas.undoAnnotationOrTextEdit(redo: true)
    }

    @objc private func selectPointerTool(_ sender: Any?) {
        canvas.setTool(nil)
        updateToolButtons(active: nil)
        makeFirstResponder(canvas)
    }

    private func toggleTool(_ tool: AnnotationTool) {
        if canvas.activeTool == tool {
            canvas.setTool(nil)
            updateToolButtons(active: nil)
        } else {
            selectTool(tool)
        }
        makeFirstResponder(canvas)
    }

    private func selectTool(_ tool: AnnotationTool) {
        canvas.setTool(tool)
        updateToolButtons(active: tool)
    }

    /// Highlights the toolstrip button for the active tool, or the pointer
    /// button when no tool is active. A crop session takes over the strip, so
    /// the tool buttons stay dimmed until it ends.
    private func updateToolButtons(active tool: AnnotationTool?) {
        let cropping = canvas.isCropping
        pointerButton.setActive(tool == nil && !cropping)
        arrowButton.setActive(tool == .arrow && !cropping)
        squareButton.setActive(tool == .square && !cropping)
        blurButton.setActive(tool == .blur && !cropping)
        pencilButton.setActive(tool == .pencil && !cropping)
        highlightButton.setActive(tool == .highlight && !cropping)
        textButton.setActive(tool == .text && !cropping)
        cropButton.setActive(cropping)
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

    // MARK: Keyboard

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.keyCode == 53 {
            if canvas.isEditingText {
                canvas.commitActiveTextEditing()
                return true
            }
            if canvas.handleEscape() { return true }
            close()
            return true
        }

        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        if let key = event.charactersIgnoringModifiers?.lowercased(),
           key == "z",
           modifiers == .command || modifiers == [.command, .shift] {
            canvas.undoAnnotationOrTextEdit(redo: modifiers.contains(.shift))
            return true
        }
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

    // MARK: Window delegate

    func windowWillClose(_ notification: Notification) {
        // Keep the capture, annotations, title, and camera intact so the status
        // menu can reopen the editor exactly where it was left.
        canvas.commitTextEditing()
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

// MARK: - Editor chrome

@MainActor
private final class EditorContainerView: NSView {}

@MainActor
private final class EditorToolStrip: NSView {
    static let height: CGFloat = 48
    private static let dividerX: CGFloat = 94

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()

        NSColor.separatorColor.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 1).fill()
        NSRect(x: Self.dividerX, y: 12, width: 1, height: bounds.height - 24).fill()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .arrow)
    }
}

// MARK: - Buttons

@MainActor
private class HoverButton: NSButton {
    private var trackingArea: NSTrackingArea?
    private(set) var isHovered = false {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
        title = ""
        focusRingType = .none
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .arrow)
    }
}

@MainActor
private final class ToolStripButton: HoverButton {
    private(set) var isActive = false {
        didSet { needsDisplay = true }
    }
    private var isPressed = false

    init(symbolName: String, toolTip: String) {
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: toolTip)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        super.init(frame: .zero)
        configure(image: image, toolTip: toolTip)
    }

    init(resourceName: String, toolTip: String) {
        let image = Self.toolbarImage(named: resourceName) ?? Self.fallbackBlurImage(toolTip: toolTip)
        super.init(frame: .zero)
        configure(image: image, toolTip: toolTip)
    }

    private static func toolbarImage(named name: String) -> NSImage? {
        let url = Bundle.main.url(forResource: name, withExtension: "png")
            ?? Bundle.module.url(forResource: name, withExtension: "png")
        guard let url,
              let source = NSImage(contentsOf: url),
              let bitmap = source.representations.first as? NSBitmapImageRep,
              let cgImage = bitmap.cgImage else { return nil }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: 15, height: 15))
        image.isTemplate = true
        return image
    }

    private static func fallbackBlurImage(toolTip: String) -> NSImage? {
        let image = NSImage(systemSymbolName: "camera.filters", accessibilityDescription: toolTip)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 15, weight: .regular))
        image?.isTemplate = true
        return image
    }

    private func configure(image: NSImage?, toolTip: String) {
        self.toolTip = toolTip
        self.image = image
        imageScaling = .scaleProportionallyDown
        imagePosition = .imageOnly
        contentTintColor = .labelColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setActive(_ active: Bool) {
        isActive = active
    }

    override func highlight(_ flag: Bool) {
        isPressed = flag
        needsDisplay = true
        super.highlight(flag)
    }

    override func draw(_ dirtyRect: NSRect) {
        if isActive || isHovered || isPressed {
            let color: NSColor
            if isActive {
                color = NSColor.controlAccentColor.withAlphaComponent(0.16)
            } else if isPressed {
                color = NSColor.labelColor.withAlphaComponent(0.14)
            } else {
                color = NSColor.labelColor.withAlphaComponent(0.07)
            }
            color.setFill()
            NSBezierPath(
                roundedRect: bounds.insetBy(dx: 1, dy: 1),
                xRadius: 8,
                yRadius: 8
            ).fill()
        }
        super.draw(dirtyRect)
    }
}

@MainActor
private final class ColorSwatchButton: HoverButton {
    let arrowColor: ArrowColor
    private(set) var isSelected = false {
        didSet { needsDisplay = true }
    }

    init(color: ArrowColor) {
        arrowColor = color
        super.init(frame: .zero)
        toolTip = color.title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSelected(_ selected: Bool) {
        isSelected = selected
    }

    override func draw(_ dirtyRect: NSRect) {
        if isHovered {
            NSColor.labelColor.withAlphaComponent(0.08).setFill()
            NSBezierPath(ovalIn: bounds.insetBy(dx: 0.5, dy: 0.5)).fill()
        }

        let dot = NSBezierPath(ovalIn: bounds.insetBy(dx: 3.5, dy: 3.5))
        arrowColor.nsColor.setFill()
        dot.fill()
        NSColor.separatorColor.setStroke()
        dot.lineWidth = 1
        dot.stroke()

        if isSelected {
            let ring = NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1))
            NSColor.controlAccentColor.setStroke()
            ring.lineWidth = 2
            ring.stroke()
        }
    }
}

/// A short diagonal stroke preview, tilted so the line weight reads clearly at
/// a glance. The narrow and wide versions flank the stroke-width slider as its
/// labels.
@MainActor
private final class StrokeWidthGlyph: NSView {
    /// Tilt away from horizontal, in degrees. A slash reads better than a flat
    /// line for showing how thick a stroke is.
    private static let angleDegrees: CGFloat = 35
    private let previewWidth: CGFloat

    init(previewWidth: CGFloat) {
        self.previewWidth = previewWidth
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        let angle = Self.angleDegrees * .pi / 180
        let halfLength: CGFloat = 8
        let dx = halfLength * cos(angle)
        let dy = halfLength * sin(angle)

        let path = NSBezierPath()
        path.move(to: NSPoint(x: bounds.midX - dx, y: bounds.midY - dy))
        path.line(to: NSPoint(x: bounds.midX + dx, y: bounds.midY + dy))
        path.lineWidth = previewWidth
        path.lineCapStyle = .round
        NSColor.labelColor.setStroke()
        path.stroke()
    }
}

/// Draws a solid accent-coloured knob with a darker rim. The stock slider knob
/// is a very light grey that is hard to pick out against the panel, especially
/// at the small control size this slider uses.
private final class StrokeWidthSliderCell: NSSliderCell {
    override func drawKnob(_ knobRect: NSRect) {
        let diameter = min(knobRect.width, knobRect.height)
        let rect = NSRect(
            x: knobRect.midX - diameter / 2,
            y: knobRect.midY - diameter / 2,
            width: diameter,
            height: diameter
        ).insetBy(dx: 0.5, dy: 0.5)

        let path = NSBezierPath(ovalIn: rect)
        NSColor.controlAccentColor.setFill()
        path.fill()

        let rim = NSColor.controlAccentColor.blended(withFraction: 0.45, of: .black) ?? .black
        rim.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

/// An `NSSlider` that reports when a drag begins and ends, so the canvas can
/// register a single undo step for a whole drag instead of one per tick.
@MainActor
private final class StrokeWidthSlider: NSSlider {
    var onTrackingBegan: (() -> Void)?
    var onTrackingEnded: (() -> Void)?

    init() {
        super.init(frame: .zero)
        cell = StrokeWidthSliderCell()
        isContinuous = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        onTrackingBegan?()
        super.mouseDown(with: event)
        onTrackingEnded?()
    }
}

@MainActor
private final class RoundedCornerButton: HoverButton {
    private(set) var isSelected = false {
        didSet { needsDisplay = true }
    }

    init() {
        super.init(frame: .zero)
        toolTip = "Rounded corners"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSelected(_ selected: Bool) {
        isSelected = selected
    }

    override func draw(_ dirtyRect: NSRect) {
        if isSelected || isHovered {
            let color: NSColor = isSelected
                ? NSColor.controlAccentColor.withAlphaComponent(0.16)
                : NSColor.labelColor.withAlphaComponent(0.07)
            color.setFill()
            NSBezierPath(
                roundedRect: bounds.insetBy(dx: 1, dy: 1),
                xRadius: 6,
                yRadius: 6
            ).fill()
        }

        let glyph = bounds.insetBy(dx: 7, dy: 7)
        let path = isSelected
            ? NSBezierPath(roundedRect: glyph, xRadius: 4, yRadius: 4)
            : NSBezierPath(rect: glyph)
        (isSelected ? NSColor.controlAccentColor : NSColor.labelColor).setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }
}

@MainActor
private final class FillLevelButton: HoverButton {
    let fill: SquareFill
    private(set) var isSelected = false {
        didSet { needsDisplay = true }
    }

    init(fill: SquareFill) {
        self.fill = fill
        super.init(frame: .zero)
        toolTip = fill.title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSelected(_ selected: Bool) {
        isSelected = selected
    }

    override func draw(_ dirtyRect: NSRect) {
        if isSelected || isHovered {
            let color: NSColor = isSelected
                ? NSColor.controlAccentColor.withAlphaComponent(0.16)
                : NSColor.labelColor.withAlphaComponent(0.07)
            color.setFill()
            NSBezierPath(
                roundedRect: bounds.insetBy(dx: 1, dy: 1),
                xRadius: 6,
                yRadius: 6
            ).fill()
        }

        let glyph = bounds.insetBy(dx: 6, dy: 6)
        let path = NSBezierPath(rect: glyph)
        if fill.fillAlpha > 0 {
            NSColor.labelColor.withAlphaComponent(fill.fillAlpha).setFill()
            path.fill()
        }
        (isSelected ? NSColor.controlAccentColor : NSColor.labelColor).setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }
}

@MainActor
private final class BackgroundSwatchButton: HoverButton {
    let background: TextBackground
    private(set) var isSelected = false {
        didSet { needsDisplay = true }
    }

    init(background: TextBackground) {
        self.background = background
        super.init(frame: .zero)
        toolTip = background.title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSelected(_ selected: Bool) {
        isSelected = selected
    }

    override func draw(_ dirtyRect: NSRect) {
        if isHovered {
            NSColor.labelColor.withAlphaComponent(0.08).setFill()
            NSBezierPath(ovalIn: bounds.insetBy(dx: 0.5, dy: 0.5)).fill()
        }

        let dot = NSBezierPath(ovalIn: bounds.insetBy(dx: 3.5, dy: 3.5))
        if let color = background.nsColor {
            color.setFill()
            dot.fill()
        }
        NSColor.separatorColor.setStroke()
        dot.lineWidth = 1
        dot.stroke()

        if background.nsColor == nil {
            // A slash marks the "no background" choice.
            let slash = NSBezierPath()
            slash.move(to: NSPoint(x: bounds.minX + 6, y: bounds.maxY - 6))
            slash.line(to: NSPoint(x: bounds.maxX - 6, y: bounds.minY + 6))
            slash.lineWidth = 1.5
            NSColor.labelColor.setStroke()
            slash.stroke()
        }

        if isSelected {
            let ring = NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1))
            NSColor.controlAccentColor.setStroke()
            ring.lineWidth = 2
            ring.stroke()
        }
    }
}

@MainActor
private final class TextSizeButton: HoverButton {
    let increases: Bool

    init(increase: Bool) {
        increases = increase
        super.init(frame: .zero)
        toolTip = increase ? "Increase text size" : "Decrease text size"
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        image = NSImage(
            systemSymbolName: increase ? "textformat.size.larger" : "textformat.size.smaller",
            accessibilityDescription: toolTip
        )?.withSymbolConfiguration(configuration)
        imageScaling = .scaleProportionallyDown
        imagePosition = .imageOnly
        contentTintColor = .labelColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        if isHovered {
            NSColor.labelColor.withAlphaComponent(0.07).setFill()
            NSBezierPath(
                roundedRect: bounds.insetBy(dx: 1, dy: 1),
                xRadius: 6,
                yRadius: 6
            ).fill()
        }
        super.draw(dirtyRect)
    }
}

// MARK: - Options panel

@MainActor
private final class ArrowOptionsPanel: NSView {
    enum Mode {
        case arrow
        case square
        case pencil
        case highlight
        case text
    }

    private static let swatchSize: CGFloat = 22
    private static let swatchSpacing: CGFloat = 6
    private static let thicknessSize: CGFloat = 28
    private static let thicknessSpacing: CGFloat = 2
    private static let widthSliderWidth: CGFloat = 118
    private static let widthGlyphSize: CGFloat = 22
    /// Preview stroke widths for the slider's flanking glyphs.
    private static let thinPreviewWidth: CGFloat = 1.5
    private static let thickPreviewWidth: CGFloat = 6
    private static let horizontalPadding: CGFloat = 10
    private static let dividerGap: CGFloat = 12
    private static let roundedGap: CGFloat = 6
    private static let panelHeight: CGFloat = 44

    var onColorSelected: (@MainActor (ArrowColor) -> Void)?
    var onRoundedChanged: (@MainActor (Bool) -> Void)?
    var onFillChanged: (@MainActor (SquareFill) -> Void)?
    var onStrokeWidthChanged: (@MainActor (CGFloat) -> Void)?
    var onStrokeWidthEditBegan: (@MainActor () -> Void)?
    var onStrokeWidthEditEnded: (@MainActor () -> Void)?
    var onHighlightColorSelected: (@MainActor (ArrowColor) -> Void)?
    var onPencilColorSelected: (@MainActor (ArrowColor) -> Void)?
    var onTextColorSelected: (@MainActor (ArrowColor) -> Void)?
    var onBackgroundSelected: (@MainActor (TextBackground) -> Void)?
    var onTextSizeChanged: (@MainActor (Bool) -> Void)?

    private(set) var mode: Mode = .arrow
    private var swatchButtons: [ColorSwatchButton] = []
    private let colorDivider = NSBox()
    private let squareDivider = NSBox()
    private let textDivider = NSBox()
    private let roundedButton = RoundedCornerButton()
    private var fillButtons: [FillLevelButton] = []
    private var backgroundButtons: [BackgroundSwatchButton] = []
    private var sizeDecreaseButton = TextSizeButton(increase: false)
    private var sizeIncreaseButton = TextSizeButton(increase: true)
    private let widthSlider = StrokeWidthSlider()
    private let thinGlyph = StrokeWidthGlyph(previewWidth: ArrowOptionsPanel.thinPreviewWidth)
    private let thickGlyph = StrokeWidthGlyph(previewWidth: ArrowOptionsPanel.thickPreviewWidth)
    private var isAdjustingWidth = false
    private var isRounded = SquarePreferences.isRounded
    private var fill = SquarePreferences.fill
    private var arrowColor = ArrowPreferences.color
    private var arrowWidth = ArrowPreferences.lineWidth
    private var pencilColor = FreehandPreferences.color(for: .pencil)
    private var pencilWidth = FreehandPreferences.lineWidth(for: .pencil)
    private var highlightColor = FreehandPreferences.color(for: .highlight)
    private var highlightWidth = FreehandPreferences.lineWidth(for: .highlight)
    private var textColor = TextPreferences.color
    private var textBackground = TextPreferences.background

    override var isFlipped: Bool { false }

    convenience init() {
        self.init(frame: NSRect(origin: .zero, size: NSSize(width: 0, height: Self.panelHeight)))
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .arrow)
    }

    func setMode(_ mode: Mode) {
        guard self.mode != mode else { return }
        self.mode = mode
        syncSliderToMode()
        syncSwatchSelection()
        layoutControls()
        needsDisplay = true
    }

    /// Points the colour swatches at the colour belonging to the current mode.
    /// The swatch state is otherwise only touched by the mode that owns it, so
    /// switching tools always shows the right selection.
    private func syncSwatchSelection() {
        let color: ArrowColor
        switch mode {
        case .text:
            color = textColor
        case .pencil:
            color = pencilColor
        case .highlight:
            color = highlightColor
        case .arrow, .square:
            color = arrowColor
        }
        for button in swatchButtons {
            button.setSelected(button.tag == color.rawValue)
        }
    }

    /// Points the shared slider at the active tool's own range and value. Arrows
    /// and squares share one range; each freehand tool keeps its own width on a
    /// base of its own, so the pencil and the marker stay distinct.
    private func syncSliderToMode() {
        switch mode {
        case .arrow, .square:
            widthSlider.minValue = Double(ArrowGeometry.minimumMultiplier)
            widthSlider.maxValue = Double(ArrowGeometry.maximumMultiplier)
            widthSlider.doubleValue = Double(arrowWidth)
        case .pencil:
            widthSlider.minValue = Double(FreehandGeometry.minimumMultiplier)
            widthSlider.maxValue = Double(FreehandGeometry.maximumMultiplier)
            widthSlider.doubleValue = Double(pencilWidth)
        case .highlight:
            widthSlider.minValue = Double(FreehandGeometry.minimumMultiplier)
            widthSlider.maxValue = Double(FreehandGeometry.maximumMultiplier)
            widthSlider.doubleValue = Double(highlightWidth)
        case .text:
            break
        }
    }

    private func buildSubviews() {
        for color in ArrowColor.allCases {
            let button = ColorSwatchButton(color: color)
            button.tag = color.rawValue
            button.target = self
            button.action = #selector(selectColor(_:))
            addSubview(button)
            swatchButtons.append(button)
        }

        colorDivider.boxType = .separator
        addSubview(colorDivider)

        widthSlider.controlSize = .small
        widthSlider.toolTip = "Stroke thickness"
        widthSlider.target = self
        widthSlider.action = #selector(widthSliderChanged(_:))
        widthSlider.onTrackingBegan = { [weak self] in
            self?.isAdjustingWidth = true
            self?.onStrokeWidthEditBegan?()
        }
        widthSlider.onTrackingEnded = { [weak self] in
            self?.isAdjustingWidth = false
            self?.onStrokeWidthEditEnded?()
        }
        addSubview(widthSlider)
        addSubview(thinGlyph)
        addSubview(thickGlyph)
        syncSliderToMode()

        squareDivider.boxType = .separator
        addSubview(squareDivider)

        roundedButton.target = self
        roundedButton.action = #selector(toggleRounded(_:))
        addSubview(roundedButton)

        for fill in SquareFill.allCases {
            let button = FillLevelButton(fill: fill)
            button.target = self
            button.action = #selector(selectFill(_:))
            addSubview(button)
            fillButtons.append(button)
        }

        textDivider.boxType = .separator
        addSubview(textDivider)

        for background in TextBackground.allCases {
            let button = BackgroundSwatchButton(background: background)
            button.target = self
            button.action = #selector(selectBackground(_:))
            addSubview(button)
            backgroundButtons.append(button)
        }

        sizeDecreaseButton.target = self
        sizeDecreaseButton.action = #selector(changeTextSize(_:))
        addSubview(sizeDecreaseButton)

        sizeIncreaseButton.target = self
        sizeIncreaseButton.action = #selector(changeTextSize(_:))
        addSubview(sizeIncreaseButton)

        updateSquareSelection(isRounded: isRounded, fill: fill)
        updatePencilSelection(color: pencilColor, width: pencilWidth)
        updateHighlightSelection(color: highlightColor, width: highlightWidth)
        updateTextSelection(color: textColor, background: textBackground)
        layoutControls()
    }

    /// Lays out the controls for the current mode and resizes the panel to fit.
    /// Arrow and square modes show color and a stroke-width slider; square mode
    /// adds the corners and fill levels; the freehand modes show their own colour
    /// swatches and slider; text mode shows text color, background, and size.
    private func layoutControls() {
        let showsWidthSlider = mode == .arrow || mode == .square
            || mode == .pencil || mode == .highlight
        let showsSquareControls = mode == .square
        let showsTextControls = mode == .text

        widthSlider.isHidden = !showsWidthSlider
        thinGlyph.isHidden = !showsWidthSlider
        thickGlyph.isHidden = !showsWidthSlider
        squareDivider.isHidden = !showsSquareControls
        roundedButton.isHidden = !showsSquareControls
        for button in fillButtons {
            button.isHidden = !showsSquareControls
        }
        textDivider.isHidden = !showsTextControls
        for button in backgroundButtons {
            button.isHidden = !showsTextControls
        }
        sizeDecreaseButton.isHidden = !showsTextControls
        sizeIncreaseButton.isHidden = !showsTextControls

        var x = Self.horizontalPadding

        for button in swatchButtons {
            button.frame = NSRect(
                x: x,
                y: (Self.panelHeight - Self.swatchSize) / 2,
                width: Self.swatchSize,
                height: Self.swatchSize
            )
            x += Self.swatchSize + Self.swatchSpacing
        }

        x += Self.dividerGap - Self.swatchSpacing
        colorDivider.frame = NSRect(x: x, y: 10, width: 1, height: Self.panelHeight - 20)
        x += 1 + Self.dividerGap

        if showsWidthSlider {
            let glyphY = (Self.panelHeight - Self.widthGlyphSize) / 2
            thinGlyph.frame = NSRect(
                x: x,
                y: glyphY,
                width: Self.widthGlyphSize,
                height: Self.widthGlyphSize
            )
            x += Self.widthGlyphSize

            widthSlider.frame = NSRect(
                x: x,
                y: (Self.panelHeight - widthSlider.intrinsicContentSize.height) / 2,
                width: Self.widthSliderWidth,
                height: widthSlider.intrinsicContentSize.height
            )
            x += Self.widthSliderWidth

            thickGlyph.frame = NSRect(
                x: x,
                y: glyphY,
                width: Self.widthGlyphSize,
                height: Self.widthGlyphSize
            )
            x += Self.widthGlyphSize + Self.thicknessSpacing
        }

        if showsSquareControls {
            x += Self.dividerGap - Self.thicknessSpacing
            squareDivider.frame = NSRect(x: x, y: 10, width: 1, height: Self.panelHeight - 20)
            x += 1 + Self.dividerGap

            roundedButton.frame = NSRect(
                x: x,
                y: (Self.panelHeight - Self.thicknessSize) / 2,
                width: Self.thicknessSize,
                height: Self.thicknessSize
            )
            x += Self.thicknessSize + Self.roundedGap

            for button in fillButtons {
                button.frame = NSRect(
                    x: x,
                    y: (Self.panelHeight - Self.thicknessSize) / 2,
                    width: Self.thicknessSize,
                    height: Self.thicknessSize
                )
                x += Self.thicknessSize + Self.thicknessSpacing
            }
        }

        if showsTextControls {
            for button in backgroundButtons {
                button.frame = NSRect(
                    x: x,
                    y: (Self.panelHeight - Self.swatchSize) / 2,
                    width: Self.swatchSize,
                    height: Self.swatchSize
                )
                x += Self.swatchSize + Self.swatchSpacing
            }

            x += Self.dividerGap - Self.swatchSpacing
            textDivider.frame = NSRect(x: x, y: 10, width: 1, height: Self.panelHeight - 20)
            x += 1 + Self.dividerGap

            for button in [sizeDecreaseButton, sizeIncreaseButton] {
                button.frame = NSRect(
                    x: x,
                    y: (Self.panelHeight - Self.thicknessSize) / 2,
                    width: Self.thicknessSize,
                    height: Self.thicknessSize
                )
                x += Self.thicknessSize + Self.thicknessSpacing
            }
        }

        // `x` ends one spacing past the last control; trim it before padding.
        let width = x - Self.thicknessSpacing + Self.horizontalPadding
        frame = NSRect(origin: frame.origin, size: NSSize(width: width, height: Self.panelHeight))
    }

    /// Arrow and square mode: strokes the chosen colour and points the shared
    /// slider at the chosen width.
    func updateSelection(color: ArrowColor, width: CGFloat) {
        arrowColor = color
        arrowWidth = width
        if mode == .arrow || mode == .square {
            for button in swatchButtons {
                button.setSelected(button.tag == color.rawValue)
            }
            widthSlider.doubleValue = Double(width)
        }
    }

    func updateSquareSelection(isRounded: Bool, fill: SquareFill) {
        self.isRounded = isRounded
        self.fill = fill
        roundedButton.setSelected(isRounded)
        for button in fillButtons {
            button.setSelected(button.fill == fill)
        }
    }

    func updatePencilSelection(color: ArrowColor, width: CGFloat) {
        pencilColor = color
        pencilWidth = width
        if mode == .pencil {
            for button in swatchButtons {
                button.setSelected(button.tag == color.rawValue)
            }
            widthSlider.doubleValue = Double(width)
        }
    }

    func updateHighlightSelection(color: ArrowColor, width: CGFloat) {
        highlightColor = color
        highlightWidth = width
        if mode == .highlight {
            for button in swatchButtons {
                button.setSelected(button.tag == color.rawValue)
            }
            widthSlider.doubleValue = Double(width)
        }
    }

    func updateTextSelection(color: ArrowColor, background: TextBackground) {
        textColor = color
        textBackground = background
        guard mode == .text else { return }
        for button in swatchButtons {
            button.setSelected(button.tag == color.rawValue)
        }
        for button in backgroundButtons {
            button.setSelected(button.background == background)
        }
    }

    @objc private func toggleRounded(_ sender: Any?) {
        isRounded.toggle()
        roundedButton.setSelected(isRounded)
        onRoundedChanged?(isRounded)
    }

    @objc private func selectFill(_ sender: FillLevelButton) {
        fill = sender.fill
        for button in fillButtons {
            button.setSelected(button.fill == fill)
        }
        onFillChanged?(fill)
    }

    @objc private func selectColor(_ sender: NSButton) {
        guard let color = ArrowColor(rawValue: sender.tag) else { return }
        if mode == .text {
            updateTextSelection(color: color, background: textBackground)
            onTextColorSelected?(color)
        } else if mode == .pencil {
            updatePencilSelection(color: color, width: pencilWidth)
            onPencilColorSelected?(color)
        } else if mode == .highlight {
            updateHighlightSelection(color: color, width: highlightWidth)
            onHighlightColorSelected?(color)
        } else {
            updateSelection(color: color, width: arrowWidth)
            onColorSelected?(color)
        }
    }

    @objc private func selectBackground(_ sender: BackgroundSwatchButton) {
        updateTextSelection(color: textColor, background: sender.background)
        onBackgroundSelected?(sender.background)
    }

    @objc private func changeTextSize(_ sender: TextSizeButton) {
        onTextSizeChanged?(sender.increases)
    }

    @objc private func widthSliderChanged(_ sender: NSSlider) {
        let width = CGFloat(sender.doubleValue)
        switch mode {
        case .arrow, .square:
            arrowWidth = width
        case .pencil:
            pencilWidth = width
        case .highlight:
            highlightWidth = width
        case .text:
            break
        }
        if isAdjustingWidth {
            onStrokeWidthChanged?(width)
        } else {
            // Keyboard or accessibility changes fire without a tracking loop.
            onStrokeWidthEditBegan?()
            onStrokeWidthChanged?(width)
            onStrokeWidthEditEnded?()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 1, dy: 1),
            xRadius: 12,
            yRadius: 12
        )

        NSColor.controlBackgroundColor.setFill()
        path.fill()

        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    override func layout() {
        super.layout()
        wantsLayer = true
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.18
        layer?.shadowRadius = 8
        layer?.shadowOffset = NSSize(width: 0, height: -2)
        layer?.shadowPath = CGPath(
            roundedRect: bounds.insetBy(dx: 1, dy: 1),
            cornerWidth: 12,
            cornerHeight: 12,
            transform: nil
        )
    }
}

// MARK: - Canvas

@MainActor
private final class AnnotationCanvasView: NSView, NSTextFieldDelegate {
    private struct Arrow: Equatable {
        var start: CGPoint
        var end: CGPoint
        var color: ArrowColor
        var thickness: CGFloat
    }

    private struct Square: Equatable {
        var rect: CGRect
        var color: ArrowColor
        var thickness: CGFloat
        var isRounded: Bool
        var fill: SquareFill
    }

    private struct BlurRegion: Equatable {
        var rect: CGRect
    }

    /// A freehand stroke drawn with the pencil or the marker. `points` are in
    /// image units; the width comes from `thickness` (a multiple of the base
    /// stroke for `style`), and `alpha` is captured per stroke so a pencil and a
    /// marker can be mixed in one image.
    private struct FreehandStroke: Equatable {
        var points: [CGPoint]
        var color: ArrowColor
        var thickness: CGFloat
        var alpha: CGFloat
        var style: FreehandStyle
    }

    /// A text annotation. `origin` is the top-left of the text in image units;
    /// the optional background rectangle is derived from the text metrics at
    /// draw time.
    private struct TextNote: Equatable {
        var origin: CGPoint
        var text: String
        var fontSize: CGFloat
        var color: ArrowColor
        var background: TextBackground
    }

    private struct AnnotationSnapshot: Equatable {
        var arrows: [Arrow]
        var squares: [Square]
        var blurRegions: [BlurRegion]
        var strokes: [FreehandStroke]
        var textNotes: [TextNote]
        var cropRect: CGRect?
    }

    private enum Selection {
        case arrow(Int)
        case square(Int)
        case blur(Int)
        case stroke(Int)
        case text(Int)
    }

    private enum SquareCorner {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }

    /// The eight grab points on the crop frame: four corners and four edges.
    private enum CropHandle: CaseIterable {
        case topLeft
        case top
        case topRight
        case right
        case bottomRight
        case bottom
        case bottomLeft
        case left
    }

    /// A live crop-editing session. While one exists the canvas shows the whole
    /// image with everything outside `rect` dimmed. Applying it stores `rect` as
    /// the canvas's non-destructive crop; cancelling leaves the crop untouched.
    private struct CropSession {
        var rect: CGRect
        var drag: CropDrag?
        var originalRect: CGRect
        var grabOffset: CGPoint
    }

    private enum CropDrag {
        case move
        case resize(CropHandle)
        case create(start: CGPoint)
    }

    private enum DragMode {
        case drawingArrow(start: CGPoint)
        case drawingSquare(start: CGPoint)
        case drawingBlur(start: CGPoint)
        case drawingStroke
        case moving(index: Int, original: Arrow, grabOffset: CGPoint)
        case movingSquare(index: Int, original: Square, grabOffset: CGPoint)
        case movingBlur(index: Int, original: BlurRegion, grabOffset: CGPoint)
        case movingStroke(index: Int, original: FreehandStroke, grabOffset: CGPoint)
        case resizingStart(index: Int)
        case resizingEnd(index: Int)
        case resizingSquare(index: Int, original: CGRect, corner: SquareCorner)
        case resizingBlur(index: Int, original: CGRect, corner: SquareCorner)
        case movingText(index: Int, original: TextNote, grabOffset: CGPoint)
    }

    private enum HitTarget {
        case arrowStart(Int)
        case arrowEnd(Int)
        case arrowBody(Int)
        case squareCorner(Int, SquareCorner)
        case squareBody(Int)
        case blurCorner(Int, SquareCorner)
        case blurBody(Int)
        case strokeBody(Int)
        case textBody(Int)
    }

    private let handleRadius: CGFloat = 6
    private let minimumDragDistance: CGFloat = 4
    private let optionsMargin: CGFloat = 20

    private var screenshot: CGImage?
    private var screenshotImage: NSImage?
    /// Non-destructive crop frame in image units. `nil` means the whole image.
    private var cropRect: CGRect?
    private var cropSession: CropSession?
    private var arrows: [Arrow] = []
    private var squares: [Square] = []
    private var blurRegions: [BlurRegion] = []
    private var strokes: [FreehandStroke] = []
    private var textNotes: [TextNote] = []
    private var selection: Selection?
    private var dragMode: DragMode?
    private var pointerPosition: CGPoint?
    private var drawingStrokePoints: [CGPoint] = []
    private var strokeWidthUndoSnapshot: AnnotationSnapshot?
    private var currentColor = ArrowPreferences.color
    private var currentThickness = ArrowPreferences.lineWidth
    private var currentRounded = SquarePreferences.isRounded
    private var currentFill = SquarePreferences.fill
    private var currentPencilColor = FreehandPreferences.color(for: .pencil)
    private var currentPencilWidth = FreehandPreferences.lineWidth(for: .pencil)
    private var currentHighlightColor = FreehandPreferences.color(for: .highlight)
    private var currentHighlightWidth = FreehandPreferences.lineWidth(for: .highlight)
    private var currentTextColor = TextPreferences.color
    private var currentTextBackground = TextPreferences.background
    private var currentTextScale = TextPreferences.scale
    private var textEditor: NSTextField?
    private var editingTextIndex: Int?
    private var lastObservedEditingText = ""
    private var textCreationUndoSnapshot: AnnotationSnapshot?
    private var ignoreNextMouseDownAfterTextCommit = false
    private var isPreparingTextEditor = false
    private let annotationUndoManager = UndoManager()
    private var dragUndoSnapshot: AnnotationSnapshot?
    private var didDragAnnotation = false
    private var trackingArea: NSTrackingArea?
    private let optionsPanel = ArrowOptionsPanel()
    private var blurredScreenshot: CGImage?
    private var blurredScreenshotImage: NSImage?
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// View transform: `cameraCenter` is the content point at the viewport
    /// center, and `cameraScale` is view points per content unit. Content is
    /// the original screenshot plus every annotation. See `fitCameraToContent`.
    private var cameraCenter: CGPoint = .zero
    private var cameraScale: CGFloat = 1
    private var hasCamera = false
    private let minimumCameraScale: CGFloat = 0.02
    private let maximumCameraScale: CGFloat = 4

    /// Fires when a crop session starts or ends, so the window can refresh its
    /// tool-strip buttons.
    var onCropSessionChanged: (@MainActor () -> Void)?

    private(set) var activeTool: AnnotationTool? = .arrow

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        annotationUndoManager.groupsByEvent = false
        optionsPanel.isHidden = true
        optionsPanel.onColorSelected = { [weak self] color in
            self?.applyColor(color)
        }
        optionsPanel.onRoundedChanged = { [weak self] rounded in
            self?.applyRounded(rounded)
        }
        optionsPanel.onFillChanged = { [weak self] fill in
            self?.applyFill(fill)
        }
        optionsPanel.onStrokeWidthChanged = { [weak self] width in
            self?.applyStrokeWidth(width)
        }
        optionsPanel.onStrokeWidthEditBegan = { [weak self] in
            self?.beginStrokeWidthEdit()
        }
        optionsPanel.onStrokeWidthEditEnded = { [weak self] in
            self?.endStrokeWidthEdit()
        }
        optionsPanel.onHighlightColorSelected = { [weak self] color in
            self?.applyFreehandColor(color, style: .highlight)
        }
        optionsPanel.onPencilColorSelected = { [weak self] color in
            self?.applyFreehandColor(color, style: .pencil)
        }
        optionsPanel.onTextColorSelected = { [weak self] color in
            self?.applyTextColor(color)
        }
        optionsPanel.onBackgroundSelected = { [weak self] background in
            self?.applyTextBackground(background)
        }
        optionsPanel.onTextSizeChanged = { [weak self] increase in
            self?.adjustTextSize(increase: increase)
        }
        optionsPanel.updateSelection(color: currentColor, width: currentThickness)
        optionsPanel.updateSquareSelection(isRounded: currentRounded, fill: currentFill)
        optionsPanel.updatePencilSelection(color: currentPencilColor, width: currentPencilWidth)
        optionsPanel.updateHighlightSelection(color: currentHighlightColor, width: currentHighlightWidth)
        optionsPanel.updateTextSelection(color: currentTextColor, background: currentTextBackground)
        addSubview(optionsPanel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Content

    var hasImage: Bool { screenshot != nil }

    func setImage(_ image: CGImage) {
        commitTextEditing()
        annotationUndoManager.removeAllActions()
        screenshot = image
        screenshotImage = NSImage(
            cgImage: image,
            size: NSSize(width: image.width, height: image.height)
        )
        currentColor = ArrowPreferences.color
        currentThickness = ArrowPreferences.lineWidth
        currentRounded = SquarePreferences.isRounded
        currentFill = SquarePreferences.fill
        currentPencilColor = FreehandPreferences.color(for: .pencil)
        currentPencilWidth = FreehandPreferences.lineWidth(for: .pencil)
        currentHighlightColor = FreehandPreferences.color(for: .highlight)
        currentHighlightWidth = FreehandPreferences.lineWidth(for: .highlight)
        currentTextColor = TextPreferences.color
        currentTextBackground = TextPreferences.background
        currentTextScale = TextPreferences.scale
        arrows.removeAll()
        squares.removeAll()
        blurRegions.removeAll()
        strokes.removeAll()
        textNotes.removeAll()
        blurredScreenshot = nil
        blurredScreenshotImage = nil
        selection = nil
        cropRect = nil
        cropSession = nil
        dragMode = nil
        pointerPosition = nil
        drawingStrokePoints = []
        hasCamera = false
        optionsPanel.updateSelection(color: currentColor, width: currentThickness)
        optionsPanel.updateSquareSelection(isRounded: currentRounded, fill: currentFill)
        optionsPanel.updatePencilSelection(color: currentPencilColor, width: currentPencilWidth)
        optionsPanel.updateHighlightSelection(color: currentHighlightColor, width: currentHighlightWidth)
        optionsPanel.updateTextSelection(color: currentTextColor, background: currentTextBackground)
        updateOptionsVisibility(animated: false)
        fitCameraToContent()
        needsDisplay = true
    }

    private func annotationSnapshot() -> AnnotationSnapshot {
        AnnotationSnapshot(
            arrows: arrows,
            squares: squares,
            blurRegions: blurRegions,
            strokes: strokes,
            textNotes: textNotes,
            cropRect: cropRect
        )
    }

    private func restoreAnnotations(_ snapshot: AnnotationSnapshot) {
        if editingTextIndex != nil {
            endTextEditing(makeCanvasFirstResponder: false)
        }
        let cropChanged = snapshot.cropRect != cropRect
        arrows = snapshot.arrows
        squares = snapshot.squares
        blurRegions = snapshot.blurRegions
        strokes = snapshot.strokes
        textNotes = snapshot.textNotes
        cropRect = snapshot.cropRect
        cropSession = nil
        selection = nil
        dragMode = nil
        drawingStrokePoints = []
        blurredScreenshot = nil
        blurredScreenshotImage = nil
        optionsPanel.updateSelection(color: currentColor, width: currentThickness)
        optionsPanel.updateSquareSelection(isRounded: currentRounded, fill: currentFill)
        optionsPanel.updatePencilSelection(color: currentPencilColor, width: currentPencilWidth)
        optionsPanel.updateHighlightSelection(color: currentHighlightColor, width: currentHighlightWidth)
        optionsPanel.updateTextSelection(color: currentTextColor, background: currentTextBackground)
        updateOptionsVisibility()
        if cropChanged {
            fitCameraToContent()
        }
        needsDisplay = true
    }

    private func registerAnnotationUndo(
        restoring snapshot: AnnotationSnapshot,
        actionName: String
    ) {
        annotationUndoManager.beginUndoGrouping()
        annotationUndoManager.registerUndo(withTarget: self) { target in
            let current = target.annotationSnapshot()
            target.restoreAnnotations(snapshot)
            target.registerAnnotationUndo(restoring: current, actionName: actionName)
        }
        annotationUndoManager.setActionName(actionName)
        annotationUndoManager.endUndoGrouping()
    }

    func undoAnnotationOrTextEdit(redo: Bool) {
        if redo {
            if annotationUndoManager.canRedo { annotationUndoManager.redo() }
        } else if annotationUndoManager.canUndo {
            annotationUndoManager.undo()
        } else if editingTextIndex != nil {
            commitTextEditing()
        }
    }

    func setTool(_ tool: AnnotationTool?) {
        commitTextEditing()
        activeTool = tool
        dragMode = nil
        pointerPosition = nil
        drawingStrokePoints = []
        selection = nil
        if tool == .blur {
            ensureBlurredScreenshot()
        }
        optionsPanel.updateSelection(color: currentColor, width: currentThickness)
        optionsPanel.updateSquareSelection(isRounded: currentRounded, fill: currentFill)
        optionsPanel.updatePencilSelection(color: currentPencilColor, width: currentPencilWidth)
        optionsPanel.updateHighlightSelection(color: currentHighlightColor, width: currentHighlightWidth)
        optionsPanel.updateTextSelection(color: currentTextColor, background: currentTextBackground)
        updateOptionsVisibility()
        window?.invalidateCursorRects(for: self)
        updateCursor(at: .zero)
        needsDisplay = true
    }

    // MARK: Crop

    var isCropping: Bool { cropSession != nil }

    /// Starts a crop session, seeded with the current crop (or the whole image).
    /// The camera fits the full content so nothing the user might want to keep
    /// is hidden behind the applied crop.
    func beginCropSession() {
        guard screenshot != nil, cropSession == nil else { return }
        commitTextEditing()
        selection = nil
        dragMode = nil
        pointerPosition = nil
        drawingStrokePoints = []
        let initial = cropRect ?? imageBounds
        cropSession = CropSession(
            rect: initial,
            drag: nil,
            originalRect: initial,
            grabOffset: .zero
        )
        // Set the session before refreshing the options bar so it hides.
        updateOptionsVisibility()
        fitCameraToContent()
        window?.invalidateCursorRects(for: self)
        updateCursor(at: .zero)
        needsDisplay = true
        onCropSessionChanged?()
    }

    func cancelCropSession() {
        guard cropSession != nil else { return }
        cropSession = nil
        fitCameraToContent()
        window?.invalidateCursorRects(for: self)
        updateCursor(at: .zero)
        needsDisplay = true
        onCropSessionChanged?()
    }

    func applyCropSession() {
        guard let session = cropSession else { return }
        let rect = integralCropRect(session.rect)
        guard rect.width >= 8, rect.height >= 8 else {
            // Too small to be useful; keep the session open so the user can
            // adjust it instead of silently cropping to a sliver.
            NSSound.beep()
            return
        }
        cropSession = nil
        let before = annotationSnapshot()
        cropRect = rect == imageBounds ? nil : rect
        registerAnnotationUndo(restoring: before, actionName: "Crop")
        fitCameraToContent()
        window?.invalidateCursorRects(for: self)
        updateCursor(at: .zero)
        needsDisplay = true
        onCropSessionChanged?()
    }

    /// The whole captured image, in image units.
    private var imageBounds: CGRect {
        guard let screenshot else { return .zero }
        return CGRect(
            x: 0,
            y: 0,
            width: CGFloat(screenshot.width),
            height: CGFloat(screenshot.height)
        )
    }

    /// The region a crop session may select within: the current crop when one is
    /// applied, otherwise the whole image. Cropping only ever shrinks, so the
    /// pixels discarded by an earlier crop cannot be brought back by re-cropping.
    private var cropBounds: CGRect { cropRect ?? imageBounds }

    /// Rounds a crop frame to whole pixels and clamps it inside the selectable
    /// region, so the exported result lands on exact pixel boundaries.
    private func integralCropRect(_ rect: CGRect) -> CGRect {
        let bounds = cropBounds
        let minX = floor(min(max(rect.minX, bounds.minX), bounds.maxX))
        let minY = floor(min(max(rect.minY, bounds.minY), bounds.maxY))
        let maxX = ceil(min(max(rect.maxX, bounds.minX), bounds.maxX))
        let maxY = ceil(min(max(rect.maxY, bounds.minY), bounds.maxY))
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Clamps each edge of a crop frame to the selectable region, so the frame
    /// never leaves the pixels that survive the crop while it is being dragged.
    private func clampCropToBounds(_ rect: CGRect) -> CGRect {
        let bounds = cropBounds
        let minX = min(max(rect.minX, bounds.minX), bounds.maxX)
        let maxX = min(max(rect.maxX, bounds.minX), bounds.maxX)
        let minY = min(max(rect.minY, bounds.minY), bounds.maxY)
        let maxY = min(max(rect.maxY, bounds.minY), bounds.maxY)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Resizes the crop frame by moving the edges owned by `handle`, keeping a
    /// minimum size so the frame cannot collapse or invert.
    private func resizedCropRect(_ rect: CGRect, handle: CropHandle, to point: CGPoint) -> CGRect {
        let minSize: CGFloat = 16
        var minX = rect.minX
        var maxX = rect.maxX
        var minY = rect.minY
        var maxY = rect.maxY

        switch handle {
        case .topLeft:
            minX = point.x
            minY = point.y
        case .top:
            minY = point.y
        case .topRight:
            maxX = point.x
            minY = point.y
        case .right:
            maxX = point.x
        case .bottomRight:
            maxX = point.x
            maxY = point.y
        case .bottom:
            maxY = point.y
        case .bottomLeft:
            minX = point.x
            maxY = point.y
        case .left:
            minX = point.x
        }

        if maxX - minX < minSize {
            if handle == .left || handle == .topLeft || handle == .bottomLeft {
                minX = maxX - minSize
            } else {
                maxX = minX + minSize
            }
        }
        if maxY - minY < minSize {
            if handle == .top || handle == .topLeft || handle == .topRight {
                minY = maxY - minSize
            } else {
                maxY = minY + minSize
            }
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func cropHandlePoints(for frame: CGRect) -> [(CropHandle, CGPoint)] {
        [
            (.topLeft, CGPoint(x: frame.minX, y: frame.minY)),
            (.top, CGPoint(x: frame.midX, y: frame.minY)),
            (.topRight, CGPoint(x: frame.maxX, y: frame.minY)),
            (.right, CGPoint(x: frame.maxX, y: frame.midY)),
            (.bottomRight, CGPoint(x: frame.maxX, y: frame.maxY)),
            (.bottom, CGPoint(x: frame.midX, y: frame.maxY)),
            (.bottomLeft, CGPoint(x: frame.minX, y: frame.maxY)),
            (.left, CGPoint(x: frame.minX, y: frame.midY))
        ]
    }

    private func cropHandle(at point: CGPoint, in rect: CGRect) -> CropHandle? {
        let tolerance = handleRadius + 3
        for (handle, handlePoint) in cropHandlePoints(for: viewRect(for: rect)) {
            if distance(from: point, to: handlePoint) <= tolerance {
                return handle
            }
        }
        return nil
    }

    /// A canvas point clamped to the selectable region, used while editing the
    /// crop frame.
    private func clampedCropPoint(_ pointInView: CGPoint) -> CGPoint {
        let content = viewToContent(clampedViewPoint(pointInView))
        let bounds = cropBounds
        return CGPoint(
            x: min(max(content.x, bounds.minX), bounds.maxX),
            y: min(max(content.y, bounds.minY), bounds.maxY)
        )
    }

    private func cropMouseDown(with event: NSEvent) {
        guard var session = cropSession else { return }
        ensureCamera()
        let pointInView = convert(event.locationInWindow, from: nil)
        let contentPoint = clampedCropPoint(pointInView)

        if let handle = cropHandle(at: pointInView, in: session.rect) {
            session.drag = .resize(handle)
            session.originalRect = session.rect
        } else if viewRect(for: session.rect).contains(pointInView) {
            session.drag = .move
            session.originalRect = session.rect
            session.grabOffset = CGPoint(
                x: contentPoint.x - session.rect.minX,
                y: contentPoint.y - session.rect.minY
            )
        } else {
            // Dragging outside the frame starts a brand-new selection.
            session.drag = .create(start: contentPoint)
            session.originalRect = session.rect
            session.rect = CGRect(origin: contentPoint, size: .zero)
        }
        cropSession = session
        needsDisplay = true
    }

    private func cropMouseDragged(with event: NSEvent) {
        guard var session = cropSession, let drag = session.drag else { return }
        let contentPoint = clampedCropPoint(
            clampedViewPoint(convert(event.locationInWindow, from: nil))
        )

        switch drag {
        case .create(let start):
            session.rect = clampCropToBounds(normalizedRect(from: start, to: contentPoint))
        case .move:
            let origin = CGPoint(
                x: contentPoint.x - session.grabOffset.x,
                y: contentPoint.y - session.grabOffset.y
            )
            session.rect = clampCropToBounds(
                CGRect(origin: origin, size: session.originalRect.size)
            )
        case .resize(let handle):
            session.rect = clampCropToBounds(
                resizedCropRect(session.originalRect, handle: handle, to: contentPoint)
            )
        }
        cropSession = session
        needsDisplay = true
    }

    private func cropMouseUp() {
        guard var session = cropSession else { return }
        session.drag = nil
        cropSession = session
        needsDisplay = true
    }

    private func drawCropOverlay() {
        guard let session = cropSession else { return }
        let frame = viewRect(for: session.rect)

        // Dim everything outside the frame with an even-odd hole.
        let mask = NSBezierPath(rect: bounds)
        mask.appendRect(frame)
        mask.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.45).setFill()
        mask.fill()

        // Rule-of-thirds guides, so the frame is easy to line up.
        let thirds = NSBezierPath()
        for fraction in [1.0 / 3.0, 2.0 / 3.0] {
            let x = frame.minX + frame.width * fraction
            let y = frame.minY + frame.height * fraction
            thirds.move(to: CGPoint(x: x, y: frame.minY))
            thirds.line(to: CGPoint(x: x, y: frame.maxY))
            thirds.move(to: CGPoint(x: frame.minX, y: y))
            thirds.line(to: CGPoint(x: frame.maxX, y: y))
        }
        thirds.lineWidth = 1
        NSColor.white.withAlphaComponent(0.35).setStroke()
        thirds.stroke()

        NSColor.white.setStroke()
        let border = NSBezierPath(rect: frame)
        border.lineWidth = 1.5
        border.stroke()

        for (_, point) in cropHandlePoints(for: frame) {
            let handle = NSRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
            let path = NSBezierPath(roundedRect: handle, xRadius: 2, yRadius: 2)
            NSColor.white.setFill()
            path.fill()
            NSColor.black.withAlphaComponent(0.35).setStroke()
            path.lineWidth = 1
            path.stroke()
        }

        // A brief, unobtrusive reminder of the two ways out of a crop session.
        let hint = NSAttributedString(
            string: "Return to crop    ·    Esc to cancel",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(0.92)
            ]
        )
        let hintSize = hint.size()
        let hintPadding = NSSize(width: 12, height: 6)
        let pill = NSRect(
            x: bounds.midX - (hintSize.width + hintPadding.width * 2) / 2,
            y: bounds.maxY - (hintSize.height + hintPadding.height * 2) - 16,
            width: ceil(hintSize.width) + hintPadding.width * 2,
            height: ceil(hintSize.height) + hintPadding.height * 2
        )
        let pillPath = NSBezierPath(
            roundedRect: pill,
            xRadius: pill.height / 2,
            yRadius: pill.height / 2
        )
        NSColor.black.withAlphaComponent(0.55).setFill()
        pillPath.fill()
        NSColor.white.withAlphaComponent(0.18).setStroke()
        pillPath.lineWidth = 1
        pillPath.stroke()
        hint.draw(
            in: NSRect(
                x: pill.minX + hintPadding.width,
                y: pill.minY + hintPadding.height,
                width: hintSize.width,
                height: hintSize.height
            )
        )
    }

    // MARK: Layout

    override func layout() {
        super.layout()
        let size = optionsPanel.frame.size
        let x = max(optionsMargin, bounds.width - size.width - optionsMargin)
        optionsPanel.frame = NSRect(
            x: x,
            y: optionsMargin,
            width: size.width,
            height: size.height
        )

        positionTextEditor()

        // Fit once, as soon as the canvas has a real size. After that the
        // camera only moves through manual zoom/pan or an explicit fit, so
        // resizing the window or adding arrows never changes the zoom.
        if screenshot != nil, !hasCamera {
            fitCameraToContent()
        }
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        drawWorkArea()

        guard let screenshot, let screenshotImage else { return }
        ensureCamera()
        let destination = imageRect
        let imageSize = CGSize(width: screenshot.width, height: screenshot.height)
        let scale = cameraScale

        // The content is always clipped to an applied crop, so pixels discarded
        // by a crop stay gone — including while re-cropping. During a session
        // the crop frame is drawn as an adjustable overlay on top of the clip.
        let cropClip = cropRect.map { viewRect(for: $0) }
        if let cropClip {
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: cropClip).addClip()
        }

        screenshotImage.draw(in: destination)

        NSColor.black.withAlphaComponent(0.18).setStroke()
        let border = NSBezierPath(rect: (cropClip ?? destination).insetBy(dx: -0.5, dy: -0.5))
        border.lineWidth = 1
        border.stroke()

        // Blur affects the image itself, so it renders directly over the
        // screenshot and underneath every annotation.
        for region in blurRegions {
            drawBlur(region)
        }
        if let pointerPosition, case .drawingBlur(let start)? = dragMode {
            drawBlur(BlurRegion(rect: normalizedRect(from: start, to: pointerPosition)))
        }

        // Freehand strokes tint the content but stay below the sharper
        // annotations, so squares and arrows remain easy to read and select.
        for stroke in strokes {
            drawStroke(stroke, imageSize: imageSize, scale: scale)
        }
        if case .drawingStroke? = dragMode {
            let style = drawingStyle
            drawStroke(
                FreehandStroke(
                    points: drawingStrokePoints,
                    color: freehandColor(for: style),
                    thickness: freehandWidth(for: style),
                    alpha: style.alpha,
                    style: style
                ),
                imageSize: imageSize,
                scale: scale
            )
        }

        // Squares sit behind arrows so arrows stay easy to read and select.
        for square in squares {
            drawSquare(square, imageSize: imageSize, scale: scale)
        }

        if let pointerPosition, case .drawingSquare(let start)? = dragMode {
            drawSquare(
                Square(
                    rect: normalizedRect(from: start, to: pointerPosition),
                    color: currentColor,
                    thickness: currentThickness,
                    isRounded: currentRounded,
                    fill: currentFill
                ),
                imageSize: imageSize,
                scale: scale
            )
        }

        for arrow in arrows {
            let lineWidth = ArrowGeometry.lineWidth(
                forImageSize: imageSize,
                multiplier: arrow.thickness
            )
            let headLength = ArrowGeometry.headLength(forLineWidth: lineWidth)
            drawArrow(
                from: contentToView(arrow.start),
                to: contentToView(arrow.end),
                lineWidth: lineWidth * scale,
                headLength: headLength * scale,
                color: arrow.color.nsColor
            )
        }

        if let pointerPosition, case .drawingArrow(let start)? = dragMode {
            let lineWidth = ArrowGeometry.lineWidth(
                forImageSize: imageSize,
                multiplier: currentThickness
            )
            let headLength = ArrowGeometry.headLength(forLineWidth: lineWidth)
            drawArrow(
                from: contentToView(start),
                to: contentToView(pointerPosition),
                lineWidth: lineWidth * scale,
                headLength: headLength * scale,
                color: currentColor.nsColor
            )
        }

        // Text sits above every shape annotation so it stays legible.
        for (index, note) in textNotes.enumerated() where index != editingTextIndex {
            drawTextNote(
                note,
                transform: { self.contentToView($0) },
                scale: scale
            )
        }

        if cropClip != nil {
            NSGraphicsContext.restoreGraphicsState()
        }

        // Selection handles always stay visible above every annotation.
        if case .square(let index)? = selection, squares.indices.contains(index) {
            drawHandles(for: squares[index])
        } else if case .arrow(let index)? = selection, arrows.indices.contains(index) {
            drawHandles(for: arrows[index])
        } else if case .blur(let index)? = selection, blurRegions.indices.contains(index) {
            drawHandles(for: blurRegions[index])
        } else if case .stroke(let index)? = selection, strokes.indices.contains(index) {
            drawHandles(for: strokes[index])
        } else if case .text(let index)? = selection, textNotes.indices.contains(index),
                  index != editingTextIndex {
            drawHandles(for: textNotes[index])
        }

        if cropSession != nil {
            drawCropOverlay()
        }
    }

    private func drawWorkArea() {
        NSColor.controlBackgroundColor.setFill()
        bounds.fill()

        let tile: CGFloat = 12
        NSColor.labelColor.withAlphaComponent(0.07).setFill()
        let columns = Int(ceil(bounds.width / tile))
        let rows = Int(ceil(bounds.height / tile))
        for row in 0..<rows {
            for column in 0..<columns where (row + column) % 2 == 0 {
                NSRect(
                    x: bounds.minX + CGFloat(column) * tile,
                    y: bounds.minY + CGFloat(row) * tile,
                    width: tile,
                    height: tile
                ).fill()
            }
        }
    }

    private func drawArrow(
        from start: CGPoint,
        to end: CGPoint,
        lineWidth: CGFloat,
        headLength: CGFloat,
        color: NSColor
    ) {
        let path = ArrowGeometry.path(
            from: start,
            to: end,
            lineWidth: lineWidth,
            headLength: headLength
        )
        color.setStroke()
        path.stroke()
    }

    private func drawSquare(_ square: Square, imageSize: CGSize, scale: CGFloat) {
        let lineWidth = ArrowGeometry.lineWidth(
            forImageSize: imageSize,
            multiplier: square.thickness
        ) * scale
        let path = squarePath(
            in: viewRect(for: square.rect),
            rounded: square.isRounded,
            lineWidth: lineWidth
        )
        let fillAlpha = square.fill.fillAlpha
        if fillAlpha > 0 {
            square.color.nsColor.withAlphaComponent(fillAlpha).setFill()
            path.fill()
        }
        // The border stays fully opaque regardless of the fill level.
        square.color.nsColor.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }

    private func drawBlur(_ region: BlurRegion) {
        ensureBlurredScreenshot()
        guard let blurredScreenshotImage else { return }
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: viewRect(for: region.rect)).addClip()
        blurredScreenshotImage.draw(in: imageRect)
        NSGraphicsContext.restoreGraphicsState()
    }

    /// The freehand style the active tool draws with. Freehand previews and
    /// newly created strokes both read their base width and opacity here.
    private var drawingStyle: FreehandStyle {
        activeTool == .pencil ? .pencil : .highlight
    }

    private func freehandColor(for style: FreehandStyle) -> ArrowColor {
        switch style {
        case .pencil: currentPencilColor
        case .highlight: currentHighlightColor
        }
    }

    private func freehandWidth(for style: FreehandStyle) -> CGFloat {
        switch style {
        case .pencil: currentPencilWidth
        case .highlight: currentHighlightWidth
        }
    }

    private func drawStroke(_ stroke: FreehandStroke, imageSize: CGSize, scale: CGFloat) {
        guard stroke.points.count >= 2 else { return }
        let lineWidth = FreehandGeometry.lineWidth(
            forImageSize: imageSize,
            style: stroke.style,
            multiplier: stroke.thickness
        ) * scale
        let path = FreehandGeometry.path(
            points: stroke.points,
            transform: { self.contentToView($0) }
        )
        path.lineWidth = lineWidth
        stroke.color.nsColor.withAlphaComponent(stroke.alpha).setStroke()
        path.stroke()
    }

    private func blurRadius(for imageSize: CGSize) -> CGFloat {
        let base = min(imageSize.width, imageSize.height)
        return min(max(base * 0.012, 8), 48)
    }

    @discardableResult
    private func ensureBlurredScreenshot() -> CGImage? {
        if let blurredScreenshot { return blurredScreenshot }
        guard let screenshot else { return nil }
        let source = CIImage(cgImage: screenshot)
        let radius = blurRadius(for: CGSize(width: screenshot.width, height: screenshot.height))
        let output = source
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
            .cropped(to: source.extent)
        guard let image = ciContext.createCGImage(output, from: source.extent) else {
            return nil
        }
        blurredScreenshot = image
        blurredScreenshotImage = NSImage(
            cgImage: image,
            size: NSSize(width: image.width, height: image.height)
        )
        return image
    }

    private func squarePath(in rect: CGRect, rounded: Bool, lineWidth: CGFloat) -> NSBezierPath {
        let inset = lineWidth / 2
        let base = rect.insetBy(dx: inset, dy: inset)
        guard base.width > 0, base.height > 0 else { return NSBezierPath() }
        guard rounded else { return NSBezierPath(rect: base) }
        let radius = min(base.width, base.height) * 0.16
        return NSBezierPath(roundedRect: base, xRadius: radius, yRadius: radius)
    }

    private func viewRect(for rect: CGRect) -> CGRect {
        let origin = contentToView(rect.origin)
        return CGRect(
            x: origin.x,
            y: origin.y,
            width: rect.width * cameraScale,
            height: rect.height * cameraScale
        )
    }

    private func normalizedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    /// Adds a sample to the in-progress freehand stroke, dropping points that
    /// are too close together so the path stays light and smooth.
    private func appendStrokePoint(_ point: CGPoint) {
        guard let last = drawingStrokePoints.last else {
            drawingStrokePoints = [point]
            return
        }
        let threshold = max(1, 1.5 / cameraScale)
        guard distance(from: point, to: last) >= threshold else { return }
        drawingStrokePoints.append(point)
    }

    private func polylineLength(_ points: [CGPoint]) -> CGFloat {
        guard points.count >= 2 else { return 0 }
        var length: CGFloat = 0
        for index in 0..<(points.count - 1) {
            length += distance(from: points[index], to: points[index + 1])
        }
        return length
    }

    private func resizedRect(_ rect: CGRect, corner: SquareCorner, to point: CGPoint) -> CGRect {
        var minX = rect.minX
        var maxX = rect.maxX
        var minY = rect.minY
        var maxY = rect.maxY

        switch corner {
        case .topLeft:
            minX = point.x
            minY = point.y
        case .topRight:
            maxX = point.x
            minY = point.y
        case .bottomLeft:
            minX = point.x
            maxY = point.y
        case .bottomRight:
            maxX = point.x
            maxY = point.y
        }

        return CGRect(
            x: min(minX, maxX),
            y: min(minY, maxY),
            width: abs(maxX - minX),
            height: abs(maxY - minY)
        )
    }

    private func cornerPoints(for rect: CGRect) -> [(SquareCorner, CGPoint)] {
        [
            (.topLeft, CGPoint(x: rect.minX, y: rect.minY)),
            (.topRight, CGPoint(x: rect.maxX, y: rect.minY)),
            (.bottomLeft, CGPoint(x: rect.minX, y: rect.maxY)),
            (.bottomRight, CGPoint(x: rect.maxX, y: rect.maxY))
        ]
    }

    private func drawHandles(for arrow: Arrow) {
        for point in [contentToView(arrow.start), contentToView(arrow.end)] {
            let rect = NSRect(
                x: point.x - handleRadius,
                y: point.y - handleRadius,
                width: handleRadius * 2,
                height: handleRadius * 2
            )
            let path = NSBezierPath(ovalIn: rect)
            NSColor.white.setFill()
            path.fill()
            arrow.color.nsColor.setStroke()
            path.lineWidth = 2
            path.stroke()
        }
    }

    private func drawHandles(for square: Square) {
        for (_, point) in cornerPoints(for: viewRect(for: square.rect)) {
            let rect = NSRect(
                x: point.x - handleRadius,
                y: point.y - handleRadius,
                width: handleRadius * 2,
                height: handleRadius * 2
            )
            let path = NSBezierPath(ovalIn: rect)
            NSColor.white.setFill()
            path.fill()
            square.color.nsColor.setStroke()
            path.lineWidth = 2
            path.stroke()
        }
    }

    private func drawHandles(for blur: BlurRegion) {
        let rect = viewRect(for: blur.rect)
        let outline = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
        NSColor.controlAccentColor.withAlphaComponent(0.9).setStroke()
        outline.lineWidth = 1
        outline.stroke()

        for (_, point) in cornerPoints(for: rect) {
            let handle = NSRect(
                x: point.x - handleRadius,
                y: point.y - handleRadius,
                width: handleRadius * 2,
                height: handleRadius * 2
            )
            let path = NSBezierPath(ovalIn: handle)
            NSColor.white.setFill()
            path.fill()
            NSColor.controlAccentColor.setStroke()
            path.lineWidth = 2
            path.stroke()
        }
    }

    private func drawHandles(for note: TextNote) {
        let background = viewRect(for: textBackgroundRect(for: note))
        let outline = NSBezierPath(rect: background.insetBy(dx: -2, dy: -2))
        outline.setLineDash([4, 3], count: 2, phase: 0)
        NSColor.controlAccentColor.withAlphaComponent(0.9).setStroke()
        outline.lineWidth = 1
        outline.stroke()
    }

    private func drawHandles(for stroke: FreehandStroke) {
        guard let screenshot else { return }
        let imageSize = CGSize(width: screenshot.width, height: screenshot.height)
        let rect = viewRect(for: strokeBounds(for: stroke, imageSize: imageSize))
        let outline = NSBezierPath(rect: rect.insetBy(dx: -2, dy: -2))
        outline.setLineDash([4, 3], count: 2, phase: 0)
        NSColor.controlAccentColor.withAlphaComponent(0.9).setStroke()
        outline.lineWidth = 1
        outline.stroke()
    }

    /// Bounding box of a freehand stroke including its width, in image units.
    private func strokeBounds(for stroke: FreehandStroke, imageSize: CGSize) -> CGRect {
        guard let first = stroke.points.first else { return .zero }
        var minX = first.x
        var maxX = first.x
        var minY = first.y
        var maxY = first.y
        for point in stroke.points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        let lineWidth = FreehandGeometry.lineWidth(
            forImageSize: imageSize,
            style: stroke.style,
            multiplier: stroke.thickness
        )
        let padding = lineWidth / 2 + 1
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            .insetBy(dx: -padding, dy: -padding)
    }

    // MARK: Text layout and drawing

    private func baseTextFontSize() -> CGFloat {
        guard let screenshot else { return 18 }
        let base = min(CGFloat(screenshot.width), CGFloat(screenshot.height)) * 0.022
        return min(max(base, 12), 96)
    }

    private func textFont(for note: TextNote, scale: CGFloat = 1) -> NSFont {
        .systemFont(ofSize: note.fontSize * scale, weight: .semibold)
    }

    /// Rectangle around the text, in image units. It doubles as the optional
    /// background and as the click target for moving a note.
    private func textBackgroundRect(for note: TextNote) -> CGRect {
        let font = textFont(for: note)
        let metrics = textSize(for: note.text, font: font)
        let padding = note.fontSize * 0.45
        return CGRect(
            x: note.origin.x - padding,
            y: note.origin.y - padding,
            width: max(metrics.width, note.fontSize * 0.5) + padding * 2,
            height: metrics.height + padding * 2
        )
    }

    private func drawTextNote(
        _ note: TextNote,
        transform: (CGPoint) -> CGPoint,
        scale: CGFloat
    ) {
        guard !note.text.isEmpty else { return }

        if let background = note.background.nsColor {
            let rect = transformedRect(
                textBackgroundRect(for: note),
                transform: transform,
                scale: scale
            )
            let radius = max(1, note.fontSize * 0.12 * scale)
            let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
            background.setFill()
            path.fill()
        }

        let font = textFont(for: note, scale: scale)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: note.color.nsColor
        ]
        let size = textSize(for: note.text, font: font)
        let origin = transform(note.origin)
        NSAttributedString(string: note.text, attributes: attributes).draw(
            in: CGRect(origin: origin, size: size)
        )
    }

    /// Measures explicit newlines as separate lines while preserving the
    /// font's line height for empty lines.
    private func textSize(for text: String, font: NSFont) -> CGSize {
        let lines = text.components(separatedBy: .newlines)
        let lineWidths = lines.map {
            ($0 as NSString).size(withAttributes: [.font: font]).width
        }
        let lineHeight = max(
            font.pointSize,
            font.ascender - font.descender + font.leading
        )
        return CGSize(
            width: ceil(lineWidths.max() ?? 0),
            height: ceil(lineHeight * CGFloat(max(lines.count, 1)))
        )
    }

    private func transformedRect(
        _ rect: CGRect,
        transform: (CGPoint) -> CGPoint,
        scale: CGFloat
    ) -> CGRect {
        let origin = transform(rect.origin)
        return CGRect(
            x: origin.x,
            y: origin.y,
            width: rect.width * scale,
            height: rect.height * scale
        )
    }

    private func textBounds(for note: TextNote) -> CGRect {
        textBackgroundRect(for: note).insetBy(dx: -2, dy: -2)
    }

    // MARK: Text editing

    private func createTextNote(at point: CGPoint) {
        let beforeCreation = annotationSnapshot()
        let note = TextNote(
            origin: point,
            text: "",
            fontSize: baseTextFontSize() * currentTextScale,
            color: currentTextColor,
            background: currentTextBackground
        )
        textNotes.append(note)
        let index = textNotes.count - 1
        selection = .text(index)
        updateOptionsVisibility()
        beginTextEditing(at: index)
        textCreationUndoSnapshot = beforeCreation
    }

    private func beginTextEditing(at index: Int) {
        guard textNotes.indices.contains(index) else { return }
        endTextEditing(makeCanvasFirstResponder: false)

        editingTextIndex = index
        lastObservedEditingText = textNotes[index].text
        textCreationUndoSnapshot = nil

        let field = NSTextField(frame: .zero)
        field.delegate = self
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = true
        field.focusRingType = .exterior
        // Return inserts a newline instead of committing, so a label can span
        // several lines. Clicking outside the field commits the text.
        field.usesSingleLineMode = false
        field.maximumNumberOfLines = 0
        field.cell?.wraps = true
        field.cell?.isScrollable = false
        field.cell?.truncatesLastVisibleLine = false
        field.stringValue = textNotes[index].text
        field.textColor = textNotes[index].color.nsColor
        field.backgroundColor = textNotes[index].background.nsColor
            ?? NSColor.textBackgroundColor.withAlphaComponent(0.12)
        field.font = textFont(for: textNotes[index], scale: cameraScale)
        textEditor = field
        addSubview(field)
        positionTextEditor()

        // Starting editing can post a spurious end-editing notification for the
        // field that is being set up. Ignore those so the new, still-empty note
        // is not committed and removed before the user can type.
        isPreparingTextEditor = true
        window?.makeFirstResponder(field)
        if let editor = field.currentEditor() as? NSTextView {
            editor.selectedRange = NSRange(location: 0, length: field.stringValue.count)
        }
        isPreparingTextEditor = false
        needsDisplay = true
    }

    private func positionTextEditor() {
        guard let index = editingTextIndex,
              textNotes.indices.contains(index),
              let field = textEditor else { return }
        let note = textNotes[index]
        let font = textFont(for: note, scale: cameraScale)
        field.font = font
        let measured = textSize(for: field.stringValue, font: font)
        let lineHeight = ceil(font.ascender - font.descender + font.leading + 8)
        let fieldWidth = max(measured.width + 22, 90)
        let textLayout = NSAttributedString(
            string: field.stringValue,
            attributes: [.font: font]
        ).boundingRect(
            with: NSSize(width: max(fieldWidth - 22, 1), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        field.frame = NSRect(
            x: contentToView(note.origin).x,
            y: contentToView(note.origin).y,
            width: fieldWidth,
            height: max(ceil(textLayout.height) + 8, lineHeight)
        )
    }

    func commitTextEditing() {
        guard let index = editingTextIndex,
              let field = textEditor,
              !isPreparingTextEditor else { return }
        let text = field.stringValue

        if textNotes.indices.contains(index) {
            if text.isEmpty {
                if textCreationUndoSnapshot == nil {
                    let beforeRemoval = annotationSnapshot()
                    textNotes.remove(at: index)
                    registerAnnotationUndo(restoring: beforeRemoval, actionName: "Remove Text")
                } else {
                    textNotes.remove(at: index)
                }
                selection = nil
            } else {
                textNotes[index].text = text
            }
        }

        textCreationUndoSnapshot = nil
        endTextEditing()
    }

    var isEditingText: Bool { editingTextIndex != nil }

    func commitActiveTextEditing() {
        commitTextEditing()
    }

    private func endTextEditing(makeCanvasFirstResponder: Bool = true) {
        editingTextIndex = nil
        lastObservedEditingText = ""
        textCreationUndoSnapshot = nil
        textEditor?.removeFromSuperview()
        textEditor = nil
        if makeCanvasFirstResponder {
            window?.makeFirstResponder(self)
        }
        updateOptionsVisibility()
        needsDisplay = true
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard !isPreparingTextEditor,
              let field = textEditor,
              (notification.object as? NSTextField) === field else { return }
        // AppKit can end field editing before forwarding the same outside
        // click to this canvas. Treat that click as the commit action only;
        // it must not also create another text note.
        if NSApp.currentEvent?.type == .leftMouseDown {
            ignoreNextMouseDownAfterTextCommit = true
        }
        commitTextEditing()
    }

    func controlTextDidChange(_ notification: Notification) {
        guard !isPreparingTextEditor,
              let field = textEditor,
              (notification.object as? NSTextField) === field else { return }
        let newText = field.stringValue
        if newText != lastObservedEditingText,
           let index = editingTextIndex,
           textNotes.indices.contains(index) {
            let previousText = lastObservedEditingText
            if !newText.isEmpty, let creationSnapshot = textCreationUndoSnapshot {
                registerAnnotationUndo(restoring: creationSnapshot, actionName: "Add Text")
                textCreationUndoSnapshot = nil
            }
            registerTextChange(from: previousText, to: newText, at: index)
            textNotes[index].text = newText
            lastObservedEditingText = newText
        }
        positionTextEditor()
        needsDisplay = true
    }

    private func registerTextChange(from oldText: String, to newText: String, at index: Int) {
        annotationUndoManager.beginUndoGrouping()
        annotationUndoManager.registerUndo(withTarget: self) { target in
            target.applyTextUndoValue(oldText, inverseValue: newText, at: index)
        }
        annotationUndoManager.setActionName("Typing")
        annotationUndoManager.endUndoGrouping()
    }

    private func applyTextUndoValue(_ text: String, inverseValue: String, at index: Int) {
        guard textNotes.indices.contains(index) else { return }
        annotationUndoManager.beginUndoGrouping()
        annotationUndoManager.registerUndo(withTarget: self) { target in
            target.applyTextUndoValue(inverseValue, inverseValue: text, at: index)
        }
        annotationUndoManager.setActionName("Typing")
        annotationUndoManager.endUndoGrouping()

        textNotes[index].text = text
        if editingTextIndex == index, let field = textEditor {
            lastObservedEditingText = text
            field.stringValue = text
            if let editor = field.currentEditor() as? NSTextView {
                editor.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
            }
            positionTextEditor()
        }
        needsDisplay = true
    }

    func control(
        _ control: NSControl,
        textView: NSTextView,
        doCommandBy commandSelector: Selector
    ) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            commitTextEditing()
            return true
        }
        // NSTextField ends editing on Return by default. Insert a newline
        // instead so labels can span several lines; clicking outside commits.
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            textView.insertNewlineIgnoringFieldEditor(self)
            return true
        }
        return false
    }

    // MARK: Mouse handling

    override func mouseDown(with event: NSEvent) {
        if ignoreNextMouseDownAfterTextCommit {
            ignoreNextMouseDownAfterTextCommit = false
            return
        }
        if editingTextIndex != nil {
            commitTextEditing()
            return
        }
        if cropSession != nil {
            cropMouseDown(with: event)
            return
        }
        guard activeTool != nil else { return }
        ensureCamera()
        let pointInView = convert(event.locationInWindow, from: nil)
        guard screenshot != nil, let contentPoint = clampedContentPoint(for: pointInView) else {
            selection = nil
            dragMode = nil
            needsDisplay = true
            return
        }

        dragUndoSnapshot = annotationSnapshot()
        didDragAnnotation = false
        if let target = hitTest(at: pointInView) {
            switch target {
            case .arrowStart(let index):
                selectArrow(at: index)
                dragMode = .resizingStart(index: index)
            case .arrowEnd(let index):
                selectArrow(at: index)
                dragMode = .resizingEnd(index: index)
            case .arrowBody(let index):
                let arrow = arrows[index]
                selectArrow(at: index)
                dragMode = .moving(
                    index: index,
                    original: arrow,
                    grabOffset: CGPoint(
                        x: contentPoint.x - arrow.start.x,
                        y: contentPoint.y - arrow.start.y
                    )
                )
            case let .squareCorner(index, corner):
                selectSquare(at: index)
                dragMode = .resizingSquare(
                    index: index,
                    original: squares[index].rect,
                    corner: corner
                )
            case .squareBody(let index):
                let square = squares[index]
                selectSquare(at: index)
                dragMode = .movingSquare(
                    index: index,
                    original: square,
                    grabOffset: CGPoint(
                        x: contentPoint.x - square.rect.minX,
                        y: contentPoint.y - square.rect.minY
                    )
                )
            case let .blurCorner(index, corner):
                selectBlur(at: index)
                dragMode = .resizingBlur(
                    index: index,
                    original: blurRegions[index].rect,
                    corner: corner
                )
            case .blurBody(let index):
                let region = blurRegions[index]
                selectBlur(at: index)
                dragMode = .movingBlur(
                    index: index,
                    original: region,
                    grabOffset: CGPoint(
                        x: contentPoint.x - region.rect.minX,
                        y: contentPoint.y - region.rect.minY
                    )
                )
            case .strokeBody(let index):
                guard let first = strokes[index].points.first else { break }
                let stroke = strokes[index]
                selectStroke(at: index)
                dragMode = .movingStroke(
                    index: index,
                    original: stroke,
                    grabOffset: CGPoint(
                        x: contentPoint.x - first.x,
                        y: contentPoint.y - first.y
                    )
                )
            case .textBody(let index):
                selectText(at: index)
                if event.clickCount >= 2 {
                    beginTextEditing(at: index)
                } else {
                    let note = textNotes[index]
                    dragMode = .movingText(
                        index: index,
                        original: note,
                        grabOffset: CGPoint(
                            x: contentPoint.x - note.origin.x,
                            y: contentPoint.y - note.origin.y
                        )
                    )
                }
            }
        } else {
            selection = nil
            optionsPanel.updateSelection(color: currentColor, width: currentThickness)
            optionsPanel.updateSquareSelection(isRounded: currentRounded, fill: currentFill)
            optionsPanel.updatePencilSelection(color: currentPencilColor, width: currentPencilWidth)
            optionsPanel.updateHighlightSelection(color: currentHighlightColor, width: currentHighlightWidth)
            optionsPanel.updateTextSelection(color: currentTextColor, background: currentTextBackground)
            updateOptionsVisibility()
            switch activeTool {
            case .some(.arrow):
                dragMode = .drawingArrow(start: contentPoint)
                pointerPosition = contentPoint
            case .some(.square):
                dragMode = .drawingSquare(start: contentPoint)
                pointerPosition = contentPoint
            case .some(.blur):
                dragMode = .drawingBlur(start: contentPoint)
                pointerPosition = contentPoint
            case .some(.pencil), .some(.highlight):
                dragMode = .drawingStroke
                drawingStrokePoints = [contentPoint]
                pointerPosition = contentPoint
            case .some(.text):
                dragMode = nil
                pointerPosition = nil
                createTextNote(at: contentPoint)
            case .none:
                dragMode = nil
            }
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        if cropSession != nil {
            cropMouseDragged(with: event)
            return
        }
        guard let mode = dragMode else { return }
        didDragAnnotation = true
        let pointInView = clampedViewPoint(convert(event.locationInWindow, from: nil))
        guard let point = clampedContentPoint(for: pointInView) else { return }

        switch mode {
        case .drawingArrow, .drawingSquare, .drawingBlur:
            pointerPosition = point
        case .drawingStroke:
            appendStrokePoint(point)
            pointerPosition = point
        case let .moving(index, original, grabOffset):
            let proposedStart = CGPoint(
                x: point.x - grabOffset.x,
                y: point.y - grabOffset.y
            )
            var dx = proposedStart.x - original.start.x
            var dy = proposedStart.y - original.start.y

            let limits = visibleContentRect
            let minX = min(original.start.x, original.end.x)
            let maxX = max(original.start.x, original.end.x)
            let minY = min(original.start.y, original.end.y)
            let maxY = max(original.start.y, original.end.y)
            dx = min(max(dx, limits.minX - minX), limits.maxX - maxX)
            dy = min(max(dy, limits.minY - minY), limits.maxY - maxY)

            arrows[index].start = CGPoint(x: original.start.x + dx, y: original.start.y + dy)
            arrows[index].end = CGPoint(x: original.end.x + dx, y: original.end.y + dy)
        case let .movingSquare(index, original, grabOffset):
            let proposedOrigin = CGPoint(
                x: point.x - grabOffset.x,
                y: point.y - grabOffset.y
            )
            var dx = proposedOrigin.x - original.rect.minX
            var dy = proposedOrigin.y - original.rect.minY

            let limits = visibleContentRect
            dx = min(max(dx, limits.minX - original.rect.minX), limits.maxX - original.rect.maxX)
            dy = min(max(dy, limits.minY - original.rect.minY), limits.maxY - original.rect.maxY)

            squares[index].rect = original.rect.offsetBy(dx: dx, dy: dy)
        case let .movingBlur(index, original, grabOffset):
            let proposedOrigin = CGPoint(
                x: point.x - grabOffset.x,
                y: point.y - grabOffset.y
            )
            var dx = proposedOrigin.x - original.rect.minX
            var dy = proposedOrigin.y - original.rect.minY

            let limits = visibleContentRect
            dx = min(max(dx, limits.minX - original.rect.minX), limits.maxX - original.rect.maxX)
            dy = min(max(dy, limits.minY - original.rect.minY), limits.maxY - original.rect.maxY)

            blurRegions[index].rect = original.rect.offsetBy(dx: dx, dy: dy)
        case let .movingStroke(index, original, grabOffset):
            guard strokes.indices.contains(index), let first = original.points.first else { break }
            let proposedOrigin = CGPoint(
                x: point.x - grabOffset.x,
                y: point.y - grabOffset.y
            )
            var dx = proposedOrigin.x - first.x
            var dy = proposedOrigin.y - first.y

            let limits = visibleContentRect
            let bounds = strokeBounds(
                for: original,
                imageSize: CGSize(width: screenshot?.width ?? 0, height: screenshot?.height ?? 0)
            )
            dx = min(max(dx, limits.minX - bounds.minX), limits.maxX - bounds.maxX)
            dy = min(max(dy, limits.minY - bounds.minY), limits.maxY - bounds.maxY)

            strokes[index].points = original.points.map {
                CGPoint(x: $0.x + dx, y: $0.y + dy)
            }
        case .resizingStart(let index):
            arrows[index].start = point
        case .resizingEnd(let index):
            arrows[index].end = point
        case let .resizingSquare(index, original, corner):
            squares[index].rect = resizedRect(original, corner: corner, to: point)
        case let .resizingBlur(index, original, corner):
            blurRegions[index].rect = resizedRect(original, corner: corner, to: point)
        case let .movingText(index, original, grabOffset):
            guard textNotes.indices.contains(index) else { break }
            let proposedOrigin = CGPoint(
                x: point.x - grabOffset.x,
                y: point.y - grabOffset.y
            )
            var dx = proposedOrigin.x - original.origin.x
            var dy = proposedOrigin.y - original.origin.y

            let limits = visibleContentRect
            let bounds = textBounds(for: original)
            dx = min(max(dx, limits.minX - bounds.minX), limits.maxX - bounds.maxX)
            dy = min(max(dy, limits.minY - bounds.minY), limits.maxY - bounds.maxY)

            textNotes[index].origin = CGPoint(
                x: original.origin.x + dx,
                y: original.origin.y + dy
            )
        }

        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if cropSession != nil {
            cropMouseUp()
            return
        }
        guard let mode = dragMode else { return }
        dragMode = nil
        var createdAnnotation = false

        let pointInView = clampedViewPoint(convert(event.locationInWindow, from: nil))
        switch mode {
        case .drawingArrow(let start):
            if let end = clampedContentPoint(for: pointInView) {
                let startInView = contentToView(start)
                let endInView = contentToView(end)
                if distance(from: startInView, to: endInView) >= minimumDragDistance {
                    arrows.append(Arrow(
                        start: start,
                        end: end,
                        color: currentColor,
                        thickness: currentThickness
                    ))
                    createdAnnotation = true
                    selection = .arrow(arrows.count - 1)
                    updateOptionsVisibility()
                } else {
                    selection = nil
                }
            }
        case .drawingSquare(let start):
            if let end = clampedContentPoint(for: pointInView) {
                let startInView = contentToView(start)
                let endInView = contentToView(end)
                if distance(from: startInView, to: endInView) >= minimumDragDistance {
                    squares.append(Square(
                        rect: normalizedRect(from: start, to: end),
                        color: currentColor,
                        thickness: currentThickness,
                        isRounded: currentRounded,
                        fill: currentFill
                    ))
                    createdAnnotation = true
                    selection = .square(squares.count - 1)
                    updateOptionsVisibility()
                } else {
                    selection = nil
                }
            }
        case .drawingBlur(let start):
            if let end = clampedContentPoint(for: pointInView) {
                let startInView = contentToView(start)
                let endInView = contentToView(end)
                if distance(from: startInView, to: endInView) >= minimumDragDistance {
                    blurRegions.append(BlurRegion(
                        rect: normalizedRect(from: start, to: end)
                    ))
                    createdAnnotation = true
                    selection = .blur(blurRegions.count - 1)
                    updateOptionsVisibility()
                } else {
                    selection = nil
                }
            }
        case .drawingStroke:
            if drawingStrokePoints.count >= 2,
               polylineLength(drawingStrokePoints) * cameraScale >= minimumDragDistance {
                let style = drawingStyle
                strokes.append(FreehandStroke(
                    points: drawingStrokePoints,
                    color: freehandColor(for: style),
                    thickness: freehandWidth(for: style),
                    alpha: style.alpha,
                    style: style
                ))
                createdAnnotation = true
                selection = .stroke(strokes.count - 1)
                updateOptionsVisibility()
            } else {
                selection = nil
            }
        default:
            break
        }

        pointerPosition = nil
        drawingStrokePoints = []
        if (createdAnnotation || didDragAnnotation), let dragUndoSnapshot {
            let actionName = createdAnnotation ? "Add Annotation" : "Edit Annotation"
            registerAnnotationUndo(restoring: dragUndoSnapshot, actionName: actionName)
        }
        dragUndoSnapshot = nil
        didDragAnnotation = false
        updateCursor(at: pointInView)
        needsDisplay = true
    }

    // MARK: Zooming and panning

    override func magnify(with event: NSEvent) {
        guard screenshot != nil else { return }
        let pointInView = convert(event.locationInWindow, from: nil)
        zoom(by: 1 + event.magnification, around: pointInView)
    }

    /// Two-finger double-tap (smart zoom) returns to the fitted view.
    override func smartMagnify(with event: NSEvent) {
        guard screenshot != nil else { return }
        fitCameraToContent()
        needsDisplay = true
    }

    override func scrollWheel(with event: NSEvent) {
        guard screenshot != nil else { return }
        ensureCamera()
        let pointInView = convert(event.locationInWindow, from: nil)
        if event.modifierFlags.contains(.command) {
            let factor = CGFloat(exp(Double(event.scrollingDeltaY) * 0.01))
            zoom(by: factor, around: pointInView)
        } else {
            // Two-finger scroll pans the content while keeping the
            // checkerboard fixed to the window.
            cameraCenter.x -= event.scrollingDeltaX / cameraScale
            cameraCenter.y -= event.scrollingDeltaY / cameraScale
            positionTextEditor()
            needsDisplay = true
        }
    }

    private func zoom(by factor: CGFloat, around pointInView: CGPoint) {
        guard screenshot != nil, factor.isFinite, factor > 0 else { return }
        ensureCamera()
        let anchor = viewToContent(pointInView)
        let newScale = min(
            max(cameraScale * factor, minimumCameraScale),
            maximumCameraScale
        )
        guard abs(newScale - cameraScale) > 0.0001 else { return }

        cameraScale = newScale
        cameraCenter = CGPoint(
            x: anchor.x - (pointInView.x - bounds.midX) / cameraScale,
            y: anchor.y - (pointInView.y - bounds.midY) / cameraScale
        )
        positionTextEditor()
        needsDisplay = true
    }

    override func mouseMoved(with event: NSEvent) {
        updateCursor(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        updateCursor(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
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
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .mouseMoved, .cursorUpdate, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        updateCursor(at: .zero)
    }

    private func updateCursor(at point: CGPoint) {
        if cropSession != nil {
            updateCropCursor(at: point)
            return
        }
        // The options panel floats inside the canvas and is full of regular
        // controls, so keep the standard arrow there even with the text tool.
        let overOptions = !optionsPanel.isHidden && optionsPanel.frame.contains(point)
        let overImage = imageRect.contains(point)
        if activeTool == .text, overImage, !overOptions {
            NSCursor.iBeam.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    private func updateCropCursor(at point: CGPoint) {
        guard let session = cropSession,
              let handle = cropHandle(at: point, in: session.rect) else {
            NSCursor.crosshair.set()
            return
        }
        switch handle {
        case .left, .right:
            NSCursor.resizeLeftRight.set()
        case .top, .bottom:
            NSCursor.resizeUpDown.set()
        case .topLeft, .topRight, .bottomLeft, .bottomRight:
            NSCursor.crosshair.set()
        }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if cropSession != nil {
            addCursorRect(bounds, cursor: .crosshair)
        } else if activeTool == .text, screenshot != nil {
            addCursorRect(imageRect, cursor: .iBeam)
        } else {
            addCursorRect(bounds, cursor: .arrow)
        }
    }

    // MARK: Selection and style

    private func selectArrow(at index: Int) {
        guard arrows.indices.contains(index) else { return }
        selection = .arrow(index)
        let arrow = arrows[index]
        currentColor = arrow.color
        currentThickness = arrow.thickness
        optionsPanel.updateSelection(color: currentColor, width: currentThickness)
        updateOptionsVisibility()
    }

    private func selectSquare(at index: Int) {
        guard squares.indices.contains(index) else { return }
        selection = .square(index)
        let square = squares[index]
        currentColor = square.color
        currentThickness = square.thickness
        currentRounded = square.isRounded
        currentFill = square.fill
        optionsPanel.updateSelection(color: currentColor, width: currentThickness)
        optionsPanel.updateSquareSelection(isRounded: currentRounded, fill: currentFill)
        updateOptionsVisibility()
    }

    private func selectBlur(at index: Int) {
        guard blurRegions.indices.contains(index) else { return }
        selection = .blur(index)
        updateOptionsVisibility()
    }

    private func selectStroke(at index: Int) {
        guard strokes.indices.contains(index) else { return }
        selection = .stroke(index)
        let stroke = strokes[index]
        switch stroke.style {
        case .pencil:
            currentPencilColor = stroke.color
            currentPencilWidth = stroke.thickness
            optionsPanel.updatePencilSelection(
                color: currentPencilColor,
                width: currentPencilWidth
            )
        case .highlight:
            currentHighlightColor = stroke.color
            currentHighlightWidth = stroke.thickness
            optionsPanel.updateHighlightSelection(
                color: currentHighlightColor,
                width: currentHighlightWidth
            )
        }
        updateOptionsVisibility()
    }

    private func selectText(at index: Int) {
        guard textNotes.indices.contains(index) else { return }
        selection = .text(index)
        let note = textNotes[index]
        currentTextColor = note.color
        currentTextBackground = note.background
        optionsPanel.updateTextSelection(color: currentTextColor, background: currentTextBackground)
        updateOptionsVisibility()
    }

    private func applyColor(_ color: ArrowColor) {
        let before = annotationSnapshot()
        var changedAnnotation = false
        currentColor = color
        ArrowPreferences.color = color
        if case .arrow(let index)? = selection, arrows.indices.contains(index) {
            arrows[index].color = color
            changedAnnotation = true
        } else if case .square(let index)? = selection, squares.indices.contains(index) {
            squares[index].color = color
            changedAnnotation = true
        }
        if changedAnnotation { registerAnnotationUndo(restoring: before, actionName: "Change Color") }
        needsDisplay = true
        window?.makeFirstResponder(self)
    }

    private func applyRounded(_ rounded: Bool) {
        let before = annotationSnapshot()
        var changedAnnotation = false
        currentRounded = rounded
        SquarePreferences.isRounded = rounded
        if case .square(let index)? = selection, squares.indices.contains(index) {
            squares[index].isRounded = rounded
            changedAnnotation = true
        }
        if changedAnnotation { registerAnnotationUndo(restoring: before, actionName: "Change Corner Style") }
        needsDisplay = true
        window?.makeFirstResponder(self)
    }

    private func applyFill(_ fill: SquareFill) {
        let before = annotationSnapshot()
        var changedAnnotation = false
        currentFill = fill
        SquarePreferences.fill = fill
        if case .square(let index)? = selection, squares.indices.contains(index) {
            squares[index].fill = fill
            changedAnnotation = true
        }
        if changedAnnotation { registerAnnotationUndo(restoring: before, actionName: "Change Fill") }
        needsDisplay = true
        window?.makeFirstResponder(self)
    }

    /// Applies a colour to the active freehand tool and to the selected stroke,
    /// if it belongs to that tool. The two freehand tools keep separate colours.
    private func applyFreehandColor(_ color: ArrowColor, style: FreehandStyle) {
        let before = annotationSnapshot()
        var changedAnnotation = false
        switch style {
        case .pencil:
            currentPencilColor = color
            FreehandPreferences.setColor(color, for: .pencil)
            if case .stroke(let index)? = selection, strokes.indices.contains(index),
               strokes[index].style == .pencil {
                strokes[index].color = color
                changedAnnotation = true
            }
        case .highlight:
            currentHighlightColor = color
            FreehandPreferences.setColor(color, for: .highlight)
            if case .stroke(let index)? = selection, strokes.indices.contains(index),
               strokes[index].style == .highlight {
                strokes[index].color = color
                changedAnnotation = true
            }
        }
        if changedAnnotation {
            let name = style == .pencil ? "Change Pencil Color" : "Change Highlight Color"
            registerAnnotationUndo(restoring: before, actionName: name)
        }
        needsDisplay = true
        window?.makeFirstResponder(self)
    }

    /// Captures the pre-drag state so a whole slider drag registers one undo.
    private func beginStrokeWidthEdit() {
        strokeWidthUndoSnapshot = annotationSnapshot()
    }

    /// Live preview while the slider moves: resizes the selected stroke, if any,
    /// and remembers the choice for the next one. No undo step is registered.
    /// The slider is shared, so the width is routed by the panel's current mode.
    private func applyStrokeWidth(_ width: CGFloat) {
        switch optionsMode {
        case .pencil?:
            currentPencilWidth = width
            if case .stroke(let index)? = selection, strokes.indices.contains(index),
               strokes[index].style == .pencil {
                strokes[index].thickness = width
            }
        case .highlight?:
            currentHighlightWidth = width
            if case .stroke(let index)? = selection, strokes.indices.contains(index),
               strokes[index].style == .highlight {
                strokes[index].thickness = width
            }
        case .arrow?, .square?:
            currentThickness = width
            if case .arrow(let index)? = selection, arrows.indices.contains(index) {
                arrows[index].thickness = width
            } else if case .square(let index)? = selection, squares.indices.contains(index) {
                squares[index].thickness = width
            }
        default:
            break
        }
        needsDisplay = true
    }

    /// Persists the width and registers a single undo step for the drag.
    private func endStrokeWidthEdit() {
        switch optionsMode {
        case .pencil?:
            FreehandPreferences.setLineWidth(currentPencilWidth, for: .pencil)
        case .highlight?:
            FreehandPreferences.setLineWidth(currentHighlightWidth, for: .highlight)
        case .arrow?, .square?:
            ArrowPreferences.lineWidth = currentThickness
        default:
            break
        }
        if let snapshot = strokeWidthUndoSnapshot, snapshot != annotationSnapshot() {
            registerAnnotationUndo(restoring: snapshot, actionName: "Change Thickness")
        }
        strokeWidthUndoSnapshot = nil
        window?.makeFirstResponder(self)
    }

    private func applyTextColor(_ color: ArrowColor) {
        let before = annotationSnapshot()
        var changedAnnotation = false
        currentTextColor = color
        TextPreferences.color = color
        if case .text(let index)? = selection, textNotes.indices.contains(index) {
            textNotes[index].color = color
            changedAnnotation = true
            if editingTextIndex == index {
                textEditor?.textColor = color.nsColor
            }
        }
        if changedAnnotation { registerAnnotationUndo(restoring: before, actionName: "Change Text Color") }
        needsDisplay = true
        window?.makeFirstResponder(self)
    }

    private func applyTextBackground(_ background: TextBackground) {
        let before = annotationSnapshot()
        var changedAnnotation = false
        currentTextBackground = background
        TextPreferences.background = background
        if case .text(let index)? = selection, textNotes.indices.contains(index) {
            textNotes[index].background = background
            changedAnnotation = true
            if editingTextIndex == index {
                textEditor?.backgroundColor = background.nsColor
                    ?? NSColor.textBackgroundColor.withAlphaComponent(0.12)
            }
        }
        if changedAnnotation { registerAnnotationUndo(restoring: before, actionName: "Change Text Background") }
        needsDisplay = true
        window?.makeFirstResponder(self)
    }

    private func adjustTextSize(increase: Bool) {
        let before = annotationSnapshot()
        var changedAnnotation = false
        currentTextScale = min(
            max(currentTextScale * (increase ? 1.15 : 1 / 1.15), TextPreferences.minimumScale),
            TextPreferences.maximumScale
        )
        TextPreferences.scale = currentTextScale
        if case .text(let index)? = selection, textNotes.indices.contains(index) {
            textNotes[index].fontSize = baseTextFontSize() * currentTextScale
            changedAnnotation = true
            positionTextEditor()
        }
        if changedAnnotation { registerAnnotationUndo(restoring: before, actionName: "Change Text Size") }
        needsDisplay = true
        window?.makeFirstResponder(self)
    }

    /// The options bar matches the active tool. When no tool is active it
    /// follows the selected annotation instead. Blur has no options, so it
    /// hides the bar.
    private var optionsMode: ArrowOptionsPanel.Mode? {
        guard screenshot != nil, cropSession == nil else { return nil }
        switch activeTool {
        case .some(.arrow):
            return .arrow
        case .some(.square):
            return .square
        case .some(.blur):
            return nil
        case .some(.pencil):
            return .pencil
        case .some(.highlight):
            return .highlight
        case .some(.text):
            return .text
        case .none:
            switch selection {
            case .some(.arrow):
                return .arrow
            case .some(.square):
                return .square
            case .some(.stroke(let index)) where strokes.indices.contains(index):
                return strokes[index].style == .pencil ? .pencil : .highlight
            case .some(.text):
                return .text
            default:
                return nil
            }
        }
    }

    private func updateOptionsVisibility(animated: Bool = true) {
        guard let mode = optionsMode else {
            optionsPanel.isHidden = true
            optionsPanel.alphaValue = 1
            return
        }
        optionsPanel.setMode(mode)
        needsLayout = true
        guard optionsPanel.isHidden else { return }
        optionsPanel.isHidden = false
        if animated {
            optionsPanel.alphaValue = 0
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                optionsPanel.animator().alphaValue = 1
            }
        } else {
            optionsPanel.alphaValue = 1
        }
    }

    // MARK: Keyboard

    /// Handles Esc: first an in-progress drag, then the current selection.
    /// Returns false when there is nothing left to cancel.
    @discardableResult
    func handleEscape() -> Bool {
        if cropSession != nil {
            cancelCropSession()
            return true
        }
        if dragMode != nil {
            dragMode = nil
            pointerPosition = nil
            needsDisplay = true
            return true
        }
        if selection != nil {
            selection = nil
            optionsPanel.updateSelection(color: currentColor, width: currentThickness)
            optionsPanel.updateSquareSelection(isRounded: currentRounded, fill: currentFill)
            updateOptionsVisibility()
            needsDisplay = true
            return true
        }
        return false
    }

    @discardableResult
    private func deleteSelection() -> Bool {
        guard let selection else { return false }
        let before = annotationSnapshot()
        switch selection {
        case .arrow(let index):
            guard arrows.indices.contains(index) else { return false }
            arrows.remove(at: index)
        case .square(let index):
            guard squares.indices.contains(index) else { return false }
            squares.remove(at: index)
        case .blur(let index):
            guard blurRegions.indices.contains(index) else { return false }
            blurRegions.remove(at: index)
        case .stroke(let index):
            guard strokes.indices.contains(index) else { return false }
            strokes.remove(at: index)
        case .text(let index):
            guard textNotes.indices.contains(index) else { return false }
            textNotes.remove(at: index)
        }
        registerAnnotationUndo(restoring: before, actionName: "Delete Annotation")
        self.selection = nil
        optionsPanel.updateSelection(color: currentColor, width: currentThickness)
        optionsPanel.updateSquareSelection(isRounded: currentRounded, fill: currentFill)
        optionsPanel.updatePencilSelection(color: currentPencilColor, width: currentPencilWidth)
        optionsPanel.updateHighlightSelection(color: currentHighlightColor, width: currentHighlightWidth)
        updateOptionsVisibility()
        needsDisplay = true
        return true
    }

    override func keyDown(with event: NSEvent) {
        if cropSession != nil, event.keyCode == 36 || event.keyCode == 76 {
            // Return or keypad Enter applies the crop.
            applyCropSession()
            return
        }
        if event.keyCode == 53 {
            if editingTextIndex != nil {
                commitTextEditing()
                return
            }
            if !handleEscape() {
                window?.performKeyEquivalent(with: event)
            }
            return
        }

        if event.keyCode == 51 || event.keyCode == 117 {
            if deleteSelection() { return }
        }

        if event.modifierFlags.contains(.command),
           let key = event.charactersIgnoringModifiers {
            let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
            if modifiers == .command || modifiers == [.command, .shift] {
                switch key {
                case "+", "=":
                    zoom(by: 1.25, around: viewportCenter)
                    return
                case "-", "_":
                    zoom(by: 0.8, around: viewportCenter)
                    return
                case "0":
                    fitCameraToContent()
                    needsDisplay = true
                    return
                default:
                    break
                }
            }
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
        ensureCamera()
        let scale = cameraScale
        let imageSize = CGSize(width: screenshot.width, height: screenshot.height)
        let endpointTolerance = handleRadius + 3

        // Text renders above every shape, so it receives clicks first. It only
        // captures clicks when no tool is active or the text tool is chosen, so
        // shapes can still be drawn over a note.
        if activeTool == nil || activeTool == .text {
            for index in textNotes.indices.reversed() where index != editingTextIndex {
                let background = viewRect(for: textBackgroundRect(for: textNotes[index]))
                if background.insetBy(dx: -3, dy: -3).contains(point) {
                    return .textBody(index)
                }
            }

            // With the text tool active, a click on empty space must always
            // create a new note instead of selecting what lies underneath.
            if activeTool == .text {
                return nil
            }
        }

        // Arrows sit in front of squares, so they win when they overlap.
        for index in arrows.indices.reversed() {
            let start = contentToView(arrows[index].start)
            let end = contentToView(arrows[index].end)
            if distance(from: point, to: end) <= endpointTolerance {
                return .arrowEnd(index)
            }
            if distance(from: point, to: start) <= endpointTolerance {
                return .arrowStart(index)
            }
        }

        for index in arrows.indices.reversed() {
            let lineWidth = ArrowGeometry.lineWidth(
                forImageSize: imageSize,
                multiplier: arrows[index].thickness
            )
            let bodyTolerance = max(6, lineWidth * scale * 2.5)
            let start = contentToView(arrows[index].start)
            let end = contentToView(arrows[index].end)
            if distance(from: point, toSegmentFrom: start, to: end) <= bodyTolerance {
                return .arrowBody(index)
            }
        }

        for index in squares.indices.reversed() {
            let rect = viewRect(for: squares[index].rect)
            for (corner, cornerPoint) in cornerPoints(for: rect) {
                if distance(from: point, to: cornerPoint) <= endpointTolerance {
                    return .squareCorner(index, corner)
                }
            }
        }

        for index in squares.indices.reversed() {
            let square = squares[index]
            let rect = viewRect(for: square.rect)
            let strokeWidth = ArrowGeometry.lineWidth(
                forImageSize: imageSize,
                multiplier: square.thickness
            ) * scale
            let tolerance = max(4, strokeWidth)
            let outer = rect.insetBy(dx: -tolerance, dy: -tolerance)
            guard outer.contains(point) else { continue }

            let isSelected: Bool
            if case .square(index)? = selection {
                isSelected = true
            } else {
                isSelected = false
            }

            // Outline-only squares only capture their border, so annotations
            // can still be drawn inside them. Filled, already selected, or
            // tool-off squares are draggable from anywhere.
            let inner = rect.insetBy(dx: tolerance, dy: tolerance)
            let nearBorder = inner.width <= 0
                || inner.height <= 0
                || !inner.contains(point)
            if activeTool == nil || square.fill.fillAlpha > 0 || isSelected || nearBorder {
                return .squareBody(index)
            }
        }

        // Freehand strokes sit between the squares and the blur regions, so
        // they are hit-tested in that order.
        for index in strokes.indices.reversed() {
            let stroke = strokes[index]
            guard stroke.points.count >= 2 else { continue }
            let lineWidth = FreehandGeometry.lineWidth(
                forImageSize: imageSize,
                style: stroke.style,
                multiplier: stroke.thickness
            )
            let tolerance = max(6, lineWidth * scale * 0.6)
            let points = stroke.points.map { contentToView($0) }
            for position in 0..<(points.count - 1) {
                if distance(from: point, toSegmentFrom: points[position], to: points[position + 1]) <= tolerance {
                    return .strokeBody(index)
                }
            }
        }

        // Blur regions sit underneath the visible annotations. They only
        // capture pointer events while selected, with the blur tool active,
        // or with every tool switched off, so arrows and squares can still be
        // drawn directly over blurred content.
        for index in blurRegions.indices.reversed() {
            let rect = viewRect(for: blurRegions[index].rect)
            let isSelected: Bool
            if case .blur(index)? = selection {
                isSelected = true
            } else {
                isSelected = false
            }
            guard isSelected || activeTool == nil || activeTool == .blur else { continue }

            for (corner, cornerPoint) in cornerPoints(for: rect) {
                if distance(from: point, to: cornerPoint) <= endpointTolerance {
                    return .blurCorner(index, corner)
                }
            }
            if rect.insetBy(dx: -4, dy: -4).contains(point) {
                return .blurBody(index)
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

    // MARK: Camera and geometry

    /// Content is the screenshot plus every annotation, with the arrow stroke
    /// and head included.
    private var contentBounds: CGRect {
        guard let screenshot else { return .zero }
        let imageSize = CGSize(width: screenshot.width, height: screenshot.height)
        var bounds = CGRect(origin: .zero, size: imageSize)
        for arrow in arrows {
            bounds = bounds.union(arrowBounds(for: arrow, imageSize: imageSize))
        }
        for square in squares {
            bounds = bounds.union(squareBounds(for: square, imageSize: imageSize))
        }
        for region in blurRegions {
            bounds = bounds.union(region.rect)
        }
        for stroke in strokes {
            bounds = bounds.union(strokeBounds(for: stroke, imageSize: imageSize))
        }
        for note in textNotes {
            bounds = bounds.union(textBounds(for: note))
        }
        return bounds
    }

    /// Includes the annotation currently being dragged out, before it is committed.
    private var contentBoundsForCamera: CGRect {
        guard let screenshot else { return .zero }
        var bounds = contentBounds
        let imageSize = CGSize(width: screenshot.width, height: screenshot.height)
        if let pointerPosition {
            switch dragMode {
            case .drawingArrow(let start)?:
                bounds = bounds.union(arrowBounds(
                    for: Arrow(
                        start: start,
                        end: pointerPosition,
                        color: currentColor,
                        thickness: currentThickness
                    ),
                    imageSize: imageSize
                ))
            case .drawingSquare(let start)?:
                bounds = bounds.union(squareBounds(
                    for: Square(
                        rect: normalizedRect(from: start, to: pointerPosition),
                        color: currentColor,
                        thickness: currentThickness,
                        isRounded: currentRounded,
                        fill: currentFill
                    ),
                    imageSize: imageSize
                ))
            case .drawingBlur(let start)?:
                bounds = bounds.union(normalizedRect(from: start, to: pointerPosition))
            case .drawingStroke?:
                if drawingStrokePoints.count >= 2 {
                    let style = drawingStyle
                    bounds = bounds.union(strokeBounds(
                        for: FreehandStroke(
                            points: drawingStrokePoints,
                            color: freehandColor(for: style),
                            thickness: freehandWidth(for: style),
                            alpha: style.alpha,
                            style: style
                        ),
                        imageSize: imageSize
                    ))
                }
            default:
                break
            }
        }
        return bounds
    }

    /// Hard limit for how far annotations can be drawn from the image. Keeps
    /// accidental endless zoom-outs from producing enormous exports. With a crop
    /// applied the limit is the crop frame, so nothing can be drawn into the
    /// clipped-away area.
    private var allowedContentRect: CGRect {
        guard let screenshot else { return .zero }
        if let cropRect { return cropRect }
        let imageSize = CGSize(width: screenshot.width, height: screenshot.height)
        let padding = max(2048, max(imageSize.width, imageSize.height))
        return CGRect(
            x: -padding,
            y: -padding,
            width: imageSize.width + padding * 2,
            height: imageSize.height + padding * 2
        )
    }

    /// Checkerboard border kept around the content, in view points.
    private var viewportMargin: CGFloat {
        max(48, min(bounds.width, bounds.height) * 0.12)
    }

    private func fittedScale(for content: CGRect) -> CGFloat {
        guard content.width > 0, content.height > 0 else { return 1 }
        let margin = viewportMargin
        let availableWidth = max(1, bounds.width - margin * 2)
        let availableHeight = max(1, bounds.height - margin * 2)
        let scale = min(availableWidth / content.width, availableHeight / content.height)
        // Never magnify image pixels beyond 1:1. Small captures simply get a
        // larger checkerboard area around them.
        return min(scale, 1)
    }

    /// Fits the content into the viewport with a border on every side. With a
    /// crop applied this fits the crop frame, whether or not a crop session is
    /// active, so re-cropping never reveals the discarded pixels. With no crop
    /// yet it fits the whole image plus annotations so nothing is hidden.
    private func fitCameraToContent() {
        guard screenshot != nil, bounds.width > 1, bounds.height > 1 else { return }
        let content: CGRect
        if let cropRect {
            content = cropRect
        } else {
            content = contentBoundsForCamera
        }
        guard content.width > 0, content.height > 0 else { return }
        cameraScale = max(minimumCameraScale, fittedScale(for: content))
        cameraCenter = CGPoint(x: content.midX, y: content.midY)
        hasCamera = true
    }

    private func ensureCamera() {
        if !hasCamera {
            fitCameraToContent()
        }
    }

    private var viewportCenter: CGPoint {
        CGPoint(x: bounds.midX, y: bounds.midY)
    }

    private func contentToView(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: viewportCenter.x + (point.x - cameraCenter.x) * cameraScale,
            y: viewportCenter.y + (point.y - cameraCenter.y) * cameraScale
        )
    }

    private func viewToContent(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: cameraCenter.x + (point.x - viewportCenter.x) / cameraScale,
            y: cameraCenter.y + (point.y - viewportCenter.y) / cameraScale
        )
    }

    private var imageRect: CGRect {
        guard let screenshot else { return .zero }
        let origin = contentToView(.zero)
        return CGRect(
            x: origin.x,
            y: origin.y,
            width: CGFloat(screenshot.width) * cameraScale,
            height: CGFloat(screenshot.height) * cameraScale
        )
    }

    /// Visible canvas expressed in content coordinates.
    private var visibleContentRect: CGRect {
        let topLeft = viewToContent(CGPoint(x: bounds.minX, y: bounds.minY))
        let bottomRight = viewToContent(CGPoint(x: bounds.maxX, y: bounds.maxY))
        return CGRect(
            x: min(topLeft.x, bottomRight.x),
            y: min(topLeft.y, bottomRight.y),
            width: abs(bottomRight.x - topLeft.x),
            height: abs(bottomRight.y - topLeft.y)
        )
    }

    private func clampedViewPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }

    /// Converts a canvas point to content coordinates, clamped to the hard
    /// drawing limits. Points outside the image but inside the grey area are
    /// valid and produce negative or oversized coordinates.
    private func clampedContentPoint(for pointInView: CGPoint) -> CGPoint? {
        guard screenshot != nil else { return nil }
        ensureCamera()
        let contentPoint = viewToContent(clampedViewPoint(pointInView))
        let limits = allowedContentRect
        return CGPoint(
            x: min(max(contentPoint.x, limits.minX), limits.maxX),
            y: min(max(contentPoint.y, limits.minY), limits.maxY)
        )
    }

    // MARK: Export

    func imageWithAnnotations() -> NSImage? {
        commitTextEditing()
        guard let image = renderCGImage() else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }

    func pngDataWithAnnotations() -> Data? {
        commitTextEditing()
        guard let image = renderCGImage() else { return nil }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    private func renderCGImage() -> CGImage? {
        guard let screenshot else { return nil }
        let imageWidth = screenshot.width
        let imageHeight = screenshot.height
        guard imageWidth > 0, imageHeight > 0 else { return nil }

        let imageSize = CGSize(width: imageWidth, height: imageHeight)
        var exportBounds: CGRect
        if let cropRect {
            // The crop frame is authoritative: annotations outside it are cut
            // off rather than growing the output.
            exportBounds = cropRect
        } else {
            exportBounds = CGRect(
                x: 0,
                y: 0,
                width: CGFloat(imageWidth),
                height: CGFloat(imageHeight)
            )
            for arrow in arrows {
                exportBounds = exportBounds.union(arrowBounds(for: arrow, imageSize: imageSize))
            }
            for square in squares {
                exportBounds = exportBounds.union(squareBounds(for: square, imageSize: imageSize))
            }
            for region in blurRegions {
                exportBounds = exportBounds.union(region.rect)
            }
            for stroke in strokes {
                exportBounds = exportBounds.union(strokeBounds(for: stroke, imageSize: imageSize))
            }
            for note in textNotes {
                exportBounds = exportBounds.union(textBounds(for: note))
            }
        }

        let originX = floor(exportBounds.minX)
        let originY = floor(exportBounds.minY)
        let exportWidth = max(1, Int(ceil(exportBounds.maxX) - originX))
        let exportHeight = max(1, Int(ceil(exportBounds.maxY) - originY))

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: exportWidth,
                  height: exportHeight,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }

        // The image keeps its pixel position inside the expanded canvas. The
        // added area stays transparent, matching the editor's checkerboard.
        context.interpolationQuality = .high
        let imageDestination = CGRect(
            x: -originX,
            y: CGFloat(exportHeight) + originY - CGFloat(imageHeight),
            width: CGFloat(imageWidth),
            height: CGFloat(imageHeight)
        )
        context.draw(screenshot, in: imageDestination)

        if !blurRegions.isEmpty, let blurred = ensureBlurredScreenshot() {
            for region in blurRegions {
                context.saveGState()
                context.clip(to: exportRect(
                    region.rect,
                    originX: originX,
                    originY: originY,
                    exportHeight: exportHeight
                ))
                context.draw(blurred, in: imageDestination)
                context.restoreGState()
            }
        }

        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Freehand strokes render below the squares and arrows, matching the
        // editor. Each stroke's alpha keeps the content underneath readable.
        for stroke in strokes {
            guard stroke.points.count >= 2 else { continue }
            let lineWidth = FreehandGeometry.lineWidth(
                forImageSize: imageSize,
                style: stroke.style,
                multiplier: stroke.thickness
            )
            let path = FreehandGeometry.path(
                points: stroke.points,
                transform: {
                    self.exportPoint($0, originX: originX, originY: originY, exportHeight: exportHeight)
                }
            )
            context.setStrokeColor(
                stroke.color.cgColor.copy(alpha: stroke.alpha)
                    ?? stroke.color.cgColor
            )
            context.setLineWidth(lineWidth)
            context.addPath(path.cgPath)
            context.strokePath()
        }

        // Squares render below arrows, matching the editor.
        for square in squares {
            let lineWidth = ArrowGeometry.lineWidth(
                forImageSize: imageSize,
                multiplier: square.thickness
            )
            let rect = exportRect(
                square.rect,
                originX: originX,
                originY: originY,
                exportHeight: exportHeight
            )
            let path = squareCGPath(
                for: rect,
                rounded: square.isRounded,
                lineWidth: lineWidth
            )
            let fillAlpha = square.fill.fillAlpha
            if fillAlpha > 0 {
                context.setFillColor(
                    square.color.cgColor.copy(alpha: fillAlpha) ?? square.color.cgColor
                )
                context.addPath(path)
                context.fillPath()
            }
            // The border is always drawn at full opacity.
            context.setLineJoin(square.isRounded ? .round : .miter)
            context.setStrokeColor(square.color.cgColor)
            context.setLineWidth(lineWidth)
            context.addPath(path)
            context.strokePath()
        }

        context.setLineJoin(.round)

        for arrow in arrows {
            let lineWidth = ArrowGeometry.lineWidth(
                forImageSize: imageSize,
                multiplier: arrow.thickness
            )
            let headLength = ArrowGeometry.headLength(forLineWidth: lineWidth)
            context.setStrokeColor(arrow.color.cgColor)
            context.setLineWidth(lineWidth)

            let path = ArrowGeometry.path(
                from: exportPoint(arrow.start, originX: originX, originY: originY, exportHeight: exportHeight),
                to: exportPoint(arrow.end, originX: originX, originY: originY, exportHeight: exportHeight),
                lineWidth: lineWidth,
                headLength: headLength
            )
            context.addPath(path.cgPath)
            context.strokePath()
        }

        // Text sits above every shape. The editor works in a flipped (y-down)
        // space, so flip the export context to reuse the same drawing code.
        if !textNotes.isEmpty {
            context.saveGState()
            context.translateBy(x: 0, y: CGFloat(exportHeight))
            context.scaleBy(x: 1, y: -1)

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
            for note in textNotes {
                drawTextNote(
                    note,
                    transform: { CGPoint(x: $0.x - originX, y: $0.y - originY) },
                    scale: 1
                )
            }
            NSGraphicsContext.restoreGraphicsState()

            context.restoreGState()
        }

        return context.makeImage()
    }

    /// Bounds of an arrow including its stroke and arrowhead, in image units.
    private func arrowBounds(for arrow: Arrow, imageSize: CGSize) -> CGRect {
        let lineWidth = ArrowGeometry.lineWidth(forImageSize: imageSize, multiplier: arrow.thickness)
        let headLength = ArrowGeometry.headLength(forLineWidth: lineWidth)
        let path = ArrowGeometry.path(
            from: arrow.start,
            to: arrow.end,
            lineWidth: lineWidth,
            headLength: headLength
        )
        let strokePadding = lineWidth / 2 + 1
        return path.bounds.insetBy(dx: -strokePadding, dy: -strokePadding)
    }

    /// Bounds of a square including its stroke, in image units.
    private func squareBounds(for square: Square, imageSize: CGSize) -> CGRect {
        let lineWidth = ArrowGeometry.lineWidth(forImageSize: imageSize, multiplier: square.thickness)
        let strokePadding = lineWidth / 2 + 1
        return square.rect.insetBy(dx: -strokePadding, dy: -strokePadding)
    }

    private func squareCGPath(for rect: CGRect, rounded: Bool, lineWidth: CGFloat) -> CGPath {
        let inset = lineWidth / 2
        let base = rect.insetBy(dx: inset, dy: inset)
        guard base.width > 0, base.height > 0 else { return CGMutablePath() }
        guard rounded else { return CGPath(rect: base, transform: nil) }
        let radius = min(base.width, base.height) * 0.16
        return CGPath(
            roundedRect: base,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )
    }

    private func exportRect(
        _ rect: CGRect,
        originX: CGFloat,
        originY: CGFloat,
        exportHeight: Int
    ) -> CGRect {
        CGRect(
            x: rect.minX - originX,
            y: CGFloat(exportHeight) + originY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    private func exportPoint(
        _ point: CGPoint,
        originX: CGFloat,
        originY: CGFloat,
        exportHeight: Int
    ) -> CGPoint {
        CGPoint(
            x: point.x - originX,
            y: CGFloat(exportHeight) + originY - point.y
        )
    }
}

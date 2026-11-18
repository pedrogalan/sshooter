import AppKit
import CoreGraphics
import CoreImage

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

    /// Stroke width used by the little preview glyphs in the options panel.
    var previewWidth: CGFloat {
        switch self {
        case .thin: 1.5
        case .regular: 2.5
        case .bold: 4
        case .extraBold: 6
        }
    }
}

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
    case highlight
    case text
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
    private static let lineWidthKey = "arrowLineWidth"

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
}

enum HighlightPreferences {
    private static let colorKey = "highlightColor"
    private static let lineWidthKey = "highlightLineWidth"

    /// Marker strokes are translucent so whatever they cover stays readable.
    static let alpha: CGFloat = 0.4

    static var color: ArrowColor {
        get {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: colorKey) != nil,
                  let value = ArrowColor(rawValue: defaults.integer(forKey: colorKey)) else {
                return .yellow
            }
            return value
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: colorKey)
        }
    }

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
    static func lineWidth(forImageSize size: CGSize, thickness: ArrowLineWidth) -> CGFloat {
        let base = max(3, min(size.width, size.height) * 0.003)
        return base * thickness.multiplier
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

enum HighlightGeometry {
    /// Marker strokes are deliberately chunkier than arrow strokes, which use
    /// the same thickness multipliers on a much thinner base.
    static func lineWidth(forImageSize size: CGSize, thickness: ArrowLineWidth) -> CGFloat {
        let base = max(8, min(size.width, size.height) * 0.012)
        return base * thickness.multiplier
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
        symbolName: "camera.filters",
        toolTip: "Blur tool: drag over an area to blur it. Click again to stop drawing."
    )
    private let highlightButton = ToolStripButton(
        symbolName: "highlighter",
        toolTip: "Highlight tool: drag to draw a translucent marker stroke. Click again to stop drawing."
    )
    private let textButton = ToolStripButton(
        symbolName: "character.cursor.ibeam",
        toolTip: "Text tool: click the canvas to add text. Drag text to move it; double-click to edit."
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

        title = "Screenshot"
        minSize = NSSize(width: 600, height: 420)
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        delegate = self

        contentView = container
        configureToolStrip()
        configureCanvas()

        canvas.setTool(nil)
        pointerButton.setActive(true)
        arrowButton.setActive(false)
        squareButton.setActive(false)
        blurButton.setActive(false)
        highlightButton.setActive(false)
        textButton.setActive(false)
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

        highlightButton.frame = NSRect(x: 282, y: 8, width: 40, height: 32)
        highlightButton.target = self
        highlightButton.action = #selector(toggleHighlightTool(_:))
        toolStrip.addSubview(highlightButton)

        textButton.frame = NSRect(x: 326, y: 8, width: 40, height: 32)
        textButton.target = self
        textButton.action = #selector(toggleTextTool(_:))
        toolStrip.addSubview(textButton)

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
        title = "Screenshot"

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

    @objc private func toggleHighlightTool(_ sender: Any?) {
        toggleTool(.highlight)
    }

    @objc private func toggleTextTool(_ sender: Any?) {
        toggleTool(.text)
    }

    @objc func undoAnnotation(_ sender: Any?) {
        canvas.undoAnnotationOrTextEdit(redo: false)
    }

    @objc func redoAnnotation(_ sender: Any?) {
        canvas.undoAnnotationOrTextEdit(redo: true)
    }

    @objc private func selectPointerTool(_ sender: Any?) {
        canvas.setTool(nil)
        pointerButton.setActive(true)
        arrowButton.setActive(false)
        squareButton.setActive(false)
        blurButton.setActive(false)
        highlightButton.setActive(false)
        textButton.setActive(false)
        makeFirstResponder(canvas)
    }

    private func toggleTool(_ tool: AnnotationTool) {
        if canvas.activeTool == tool {
            canvas.setTool(nil)
            pointerButton.setActive(true)
            arrowButton.setActive(false)
            squareButton.setActive(false)
            blurButton.setActive(false)
            highlightButton.setActive(false)
            textButton.setActive(false)
        } else {
            selectTool(tool)
        }
        makeFirstResponder(canvas)
    }

    private func selectTool(_ tool: AnnotationTool) {
        canvas.setTool(tool)
        pointerButton.setActive(false)
        arrowButton.setActive(tool == .arrow)
        squareButton.setActive(tool == .square)
        blurButton.setActive(tool == .blur)
        highlightButton.setActive(tool == .highlight)
        textButton.setActive(tool == .text)
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
        super.init(frame: .zero)
        self.toolTip = toolTip
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        image = NSImage(systemSymbolName: symbolName, accessibilityDescription: toolTip)?
            .withSymbolConfiguration(configuration)
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

@MainActor
private final class ThicknessButton: HoverButton {
    let thickness: ArrowLineWidth
    private(set) var isSelected = false {
        didSet { needsDisplay = true }
    }

    init(thickness: ArrowLineWidth) {
        self.thickness = thickness
        super.init(frame: .zero)
        toolTip = "\(thickness.title) stroke"
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

        let path = NSBezierPath()
        path.move(to: NSPoint(x: bounds.midX - 8, y: bounds.midY))
        path.line(to: NSPoint(x: bounds.midX + 8, y: bounds.midY))
        path.lineWidth = thickness.previewWidth
        path.lineCapStyle = .round
        (isSelected ? NSColor.controlAccentColor : NSColor.labelColor).setStroke()
        path.stroke()
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
        case highlight
        case text
    }

    private static let swatchSize: CGFloat = 22
    private static let swatchSpacing: CGFloat = 6
    private static let thicknessSize: CGFloat = 28
    private static let thicknessSpacing: CGFloat = 2
    private static let horizontalPadding: CGFloat = 10
    private static let dividerGap: CGFloat = 12
    private static let roundedGap: CGFloat = 6
    private static let panelHeight: CGFloat = 44

    var onColorSelected: (@MainActor (ArrowColor) -> Void)?
    var onThicknessSelected: (@MainActor (ArrowLineWidth) -> Void)?
    var onRoundedChanged: (@MainActor (Bool) -> Void)?
    var onFillChanged: (@MainActor (SquareFill) -> Void)?
    var onHighlightColorSelected: (@MainActor (ArrowColor) -> Void)?
    var onHighlightThicknessSelected: (@MainActor (ArrowLineWidth) -> Void)?
    var onTextColorSelected: (@MainActor (ArrowColor) -> Void)?
    var onBackgroundSelected: (@MainActor (TextBackground) -> Void)?
    var onTextSizeChanged: (@MainActor (Bool) -> Void)?

    private(set) var mode: Mode = .arrow
    private var swatchButtons: [ColorSwatchButton] = []
    private var thicknessButtons: [ThicknessButton] = []
    private let colorDivider = NSBox()
    private let squareDivider = NSBox()
    private let textDivider = NSBox()
    private let roundedButton = RoundedCornerButton()
    private var fillButtons: [FillLevelButton] = []
    private var backgroundButtons: [BackgroundSwatchButton] = []
    private var sizeDecreaseButton = TextSizeButton(increase: false)
    private var sizeIncreaseButton = TextSizeButton(increase: true)
    private var isRounded = SquarePreferences.isRounded
    private var fill = SquarePreferences.fill
    private var highlightColor = HighlightPreferences.color
    private var highlightThickness = HighlightPreferences.lineWidth
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
        layoutControls()
        needsDisplay = true
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

        for thickness in ArrowLineWidth.allCases {
            let button = ThicknessButton(thickness: thickness)
            button.tag = thickness.rawValue
            button.target = self
            button.action = #selector(selectThickness(_:))
            addSubview(button)
            thicknessButtons.append(button)
        }

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
        updateHighlightSelection(color: highlightColor, thickness: highlightThickness)
        updateTextSelection(color: textColor, background: textBackground)
        layoutControls()
    }

    /// Lays out the controls for the current mode and resizes the panel to fit.
    /// Arrow mode shows color and thickness; square mode adds the corners and
    /// fill levels; text mode shows text color, background color, and size.
    private func layoutControls() {
        let showsThickness = mode == .arrow || mode == .square || mode == .highlight
        let showsSquareControls = mode == .square
        let showsTextControls = mode == .text

        for button in thicknessButtons {
            button.isHidden = !showsThickness
        }
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

        if showsThickness {
            for button in thicknessButtons {
                button.frame = NSRect(
                    x: x,
                    y: (Self.panelHeight - Self.thicknessSize) / 2,
                    width: Self.thicknessSize,
                    height: Self.thicknessSize
                )
                x += Self.thicknessSize + Self.thicknessSpacing
            }
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

    func updateSelection(color: ArrowColor, thickness: ArrowLineWidth) {
        for button in swatchButtons {
            button.setSelected(button.tag == color.rawValue)
        }
        for button in thicknessButtons {
            button.setSelected(button.tag == thickness.rawValue)
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

    func updateHighlightSelection(color: ArrowColor, thickness: ArrowLineWidth) {
        highlightColor = color
        highlightThickness = thickness
        for button in swatchButtons {
            button.setSelected(button.tag == color.rawValue)
        }
        for button in thicknessButtons {
            button.setSelected(button.tag == thickness.rawValue)
        }
    }

    func updateTextSelection(color: ArrowColor, background: TextBackground) {
        textColor = color
        textBackground = background
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
        } else if mode == .highlight {
            updateHighlightSelection(color: color, thickness: currentThicknessFromButtons())
            onHighlightColorSelected?(color)
        } else {
            updateSelection(color: color, thickness: currentThicknessFromButtons())
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

    @objc private func selectThickness(_ sender: NSButton) {
        guard let thickness = ArrowLineWidth(rawValue: sender.tag) else { return }
        if mode == .highlight {
            updateHighlightSelection(color: currentColorFromButtons(), thickness: thickness)
            onHighlightThicknessSelected?(thickness)
        } else {
            updateSelection(color: currentColorFromButtons(), thickness: thickness)
            onThicknessSelected?(thickness)
        }
    }

    private func currentColorFromButtons() -> ArrowColor {
        guard let tag = swatchButtons.first(where: { $0.isSelected })?.tag,
              let color = ArrowColor(rawValue: tag) else { return .red }
        return color
    }

    private func currentThicknessFromButtons() -> ArrowLineWidth {
        guard let tag = thicknessButtons.first(where: { $0.isSelected })?.tag,
              let thickness = ArrowLineWidth(rawValue: tag) else { return .regular }
        return thickness
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
    private struct Arrow {
        var start: CGPoint
        var end: CGPoint
        var color: ArrowColor
        var thickness: ArrowLineWidth
    }

    private struct Square {
        var rect: CGRect
        var color: ArrowColor
        var thickness: ArrowLineWidth
        var isRounded: Bool
        var fill: SquareFill
    }

    private struct BlurRegion {
        var rect: CGRect
    }

    /// A freehand highlighter stroke. `points` are in image units; the marker
    /// width comes from `thickness` at draw and export time.
    private struct Highlight {
        var points: [CGPoint]
        var color: ArrowColor
        var thickness: ArrowLineWidth
    }

    /// A text annotation. `origin` is the top-left of the text in image units;
    /// the optional background rectangle is derived from the text metrics at
    /// draw time.
    private struct TextNote {
        var origin: CGPoint
        var text: String
        var fontSize: CGFloat
        var color: ArrowColor
        var background: TextBackground
    }

    private struct AnnotationSnapshot {
        var arrows: [Arrow]
        var squares: [Square]
        var blurRegions: [BlurRegion]
        var highlights: [Highlight]
        var textNotes: [TextNote]
    }

    private enum Selection {
        case arrow(Int)
        case square(Int)
        case blur(Int)
        case highlight(Int)
        case text(Int)
    }

    private enum SquareCorner {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }

    private enum DragMode {
        case drawingArrow(start: CGPoint)
        case drawingSquare(start: CGPoint)
        case drawingBlur(start: CGPoint)
        case drawingHighlight
        case moving(index: Int, original: Arrow, grabOffset: CGPoint)
        case movingSquare(index: Int, original: Square, grabOffset: CGPoint)
        case movingBlur(index: Int, original: BlurRegion, grabOffset: CGPoint)
        case movingHighlight(index: Int, original: Highlight, grabOffset: CGPoint)
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
        case highlightBody(Int)
        case textBody(Int)
    }

    private let handleRadius: CGFloat = 6
    private let minimumDragDistance: CGFloat = 4
    private let optionsMargin: CGFloat = 20

    private var screenshot: CGImage?
    private var screenshotImage: NSImage?
    private var arrows: [Arrow] = []
    private var squares: [Square] = []
    private var blurRegions: [BlurRegion] = []
    private var highlights: [Highlight] = []
    private var textNotes: [TextNote] = []
    private var selection: Selection?
    private var dragMode: DragMode?
    private var pointerPosition: CGPoint?
    private var drawingHighlightPoints: [CGPoint] = []
    private var currentColor = ArrowPreferences.color
    private var currentThickness = ArrowPreferences.lineWidth
    private var currentRounded = SquarePreferences.isRounded
    private var currentFill = SquarePreferences.fill
    private var currentHighlightColor = HighlightPreferences.color
    private var currentHighlightThickness = HighlightPreferences.lineWidth
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
        optionsPanel.onThicknessSelected = { [weak self] thickness in
            self?.applyThickness(thickness)
        }
        optionsPanel.onRoundedChanged = { [weak self] rounded in
            self?.applyRounded(rounded)
        }
        optionsPanel.onFillChanged = { [weak self] fill in
            self?.applyFill(fill)
        }
        optionsPanel.onHighlightColorSelected = { [weak self] color in
            self?.applyHighlightColor(color)
        }
        optionsPanel.onHighlightThicknessSelected = { [weak self] thickness in
            self?.applyHighlightThickness(thickness)
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
        optionsPanel.updateSelection(color: currentColor, thickness: currentThickness)
        optionsPanel.updateSquareSelection(isRounded: currentRounded, fill: currentFill)
        optionsPanel.updateHighlightSelection(color: currentHighlightColor, thickness: currentHighlightThickness)
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
        currentHighlightColor = HighlightPreferences.color
        currentHighlightThickness = HighlightPreferences.lineWidth
        currentTextColor = TextPreferences.color
        currentTextBackground = TextPreferences.background
        currentTextScale = TextPreferences.scale
        arrows.removeAll()
        squares.removeAll()
        blurRegions.removeAll()
        highlights.removeAll()
        textNotes.removeAll()
        blurredScreenshot = nil
        blurredScreenshotImage = nil
        selection = nil
        dragMode = nil
        pointerPosition = nil
        drawingHighlightPoints = []
        hasCamera = false
        optionsPanel.updateSelection(color: currentColor, thickness: currentThickness)
        optionsPanel.updateSquareSelection(isRounded: currentRounded, fill: currentFill)
        optionsPanel.updateHighlightSelection(color: currentHighlightColor, thickness: currentHighlightThickness)
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
            highlights: highlights,
            textNotes: textNotes
        )
    }

    private func restoreAnnotations(_ snapshot: AnnotationSnapshot) {
        if editingTextIndex != nil {
            endTextEditing(makeCanvasFirstResponder: false)
        }
        arrows = snapshot.arrows
        squares = snapshot.squares
        blurRegions = snapshot.blurRegions
        highlights = snapshot.highlights
        textNotes = snapshot.textNotes
        selection = nil
        dragMode = nil
        drawingHighlightPoints = []
        blurredScreenshot = nil
        blurredScreenshotImage = nil
        optionsPanel.updateSelection(color: currentColor, thickness: currentThickness)
        optionsPanel.updateSquareSelection(isRounded: currentRounded, fill: currentFill)
        optionsPanel.updateHighlightSelection(color: currentHighlightColor, thickness: currentHighlightThickness)
        optionsPanel.updateTextSelection(color: currentTextColor, background: currentTextBackground)
        updateOptionsVisibility()
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
        drawingHighlightPoints = []
        selection = nil
        if tool == .blur {
            ensureBlurredScreenshot()
        }
        optionsPanel.updateSelection(color: currentColor, thickness: currentThickness)
        optionsPanel.updateSquareSelection(isRounded: currentRounded, fill: currentFill)
        optionsPanel.updateHighlightSelection(color: currentHighlightColor, thickness: currentHighlightThickness)
        optionsPanel.updateTextSelection(color: currentTextColor, background: currentTextBackground)
        updateOptionsVisibility()
        window?.invalidateCursorRects(for: self)
        updateCursor(at: .zero)
        needsDisplay = true
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
        screenshotImage.draw(in: destination)

        NSColor.black.withAlphaComponent(0.18).setStroke()
        let border = NSBezierPath(rect: destination.insetBy(dx: -0.5, dy: -0.5))
        border.lineWidth = 1
        border.stroke()

        let imageSize = CGSize(width: screenshot.width, height: screenshot.height)
        let scale = cameraScale

        // Blur affects the image itself, so it renders directly over the
        // screenshot and underneath every annotation.
        for region in blurRegions {
            drawBlur(region)
        }
        if let pointerPosition, case .drawingBlur(let start)? = dragMode {
            drawBlur(BlurRegion(rect: normalizedRect(from: start, to: pointerPosition)))
        }

        // Highlighter strokes tint the content but stay below the sharper
        // annotations, so squares and arrows remain easy to read and select.
        for highlight in highlights {
            drawHighlight(highlight, imageSize: imageSize, scale: scale)
        }
        if case .drawingHighlight? = dragMode {
            drawHighlight(
                Highlight(
                    points: drawingHighlightPoints,
                    color: currentHighlightColor,
                    thickness: currentHighlightThickness
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
                thickness: arrow.thickness
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
                thickness: currentThickness
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

        // Selection handles always stay visible above every annotation.
        if case .square(let index)? = selection, squares.indices.contains(index) {
            drawHandles(for: squares[index])
        } else if case .arrow(let index)? = selection, arrows.indices.contains(index) {
            drawHandles(for: arrows[index])
        } else if case .blur(let index)? = selection, blurRegions.indices.contains(index) {
            drawHandles(for: blurRegions[index])
        } else if case .highlight(let index)? = selection, highlights.indices.contains(index) {
            drawHandles(for: highlights[index])
        } else if case .text(let index)? = selection, textNotes.indices.contains(index),
                  index != editingTextIndex {
            drawHandles(for: textNotes[index])
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
            thickness: square.thickness
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

    private func drawHighlight(_ highlight: Highlight, imageSize: CGSize, scale: CGFloat) {
        guard highlight.points.count >= 2 else { return }
        let lineWidth = HighlightGeometry.lineWidth(
            forImageSize: imageSize,
            thickness: highlight.thickness
        ) * scale
        let path = HighlightGeometry.path(
            points: highlight.points,
            transform: { self.contentToView($0) }
        )
        path.lineWidth = lineWidth
        highlight.color.nsColor.withAlphaComponent(HighlightPreferences.alpha).setStroke()
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

    /// Adds a sample to the in-progress marker stroke, dropping points that are
    /// too close together so the path stays light and smooth.
    private func appendHighlightPoint(_ point: CGPoint) {
        guard let last = drawingHighlightPoints.last else {
            drawingHighlightPoints = [point]
            return
        }
        let threshold = max(1, 1.5 / cameraScale)
        guard distance(from: point, to: last) >= threshold else { return }
        drawingHighlightPoints.append(point)
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

    private func drawHandles(for highlight: Highlight) {
        guard let screenshot else { return }
        let imageSize = CGSize(width: screenshot.width, height: screenshot.height)
        let rect = viewRect(for: highlightBounds(for: highlight, imageSize: imageSize))
        let outline = NSBezierPath(rect: rect.insetBy(dx: -2, dy: -2))
        outline.setLineDash([4, 3], count: 2, phase: 0)
        NSColor.controlAccentColor.withAlphaComponent(0.9).setStroke()
        outline.lineWidth = 1
        outline.stroke()
    }

    /// Bounding box of a marker stroke including its width, in image units.
    private func highlightBounds(for highlight: Highlight, imageSize: CGSize) -> CGRect {
        guard let first = highlight.points.first else { return .zero }
        var minX = first.x
        var maxX = first.x
        var minY = first.y
        var maxY = first.y
        for point in highlight.points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        let lineWidth = HighlightGeometry.lineWidth(
            forImageSize: imageSize,
            thickness: highlight.thickness
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
            case .highlightBody(let index):
                guard let first = highlights[index].points.first else { break }
                let highlight = highlights[index]
                selectHighlight(at: index)
                dragMode = .movingHighlight(
                    index: index,
                    original: highlight,
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
            optionsPanel.updateSelection(color: currentColor, thickness: currentThickness)
            optionsPanel.updateSquareSelection(isRounded: currentRounded, fill: currentFill)
            optionsPanel.updateHighlightSelection(color: currentHighlightColor, thickness: currentHighlightThickness)
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
            case .some(.highlight):
                dragMode = .drawingHighlight
                drawingHighlightPoints = [contentPoint]
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
        guard let mode = dragMode else { return }
        didDragAnnotation = true
        let pointInView = clampedViewPoint(convert(event.locationInWindow, from: nil))
        guard let point = clampedContentPoint(for: pointInView) else { return }

        switch mode {
        case .drawingArrow, .drawingSquare, .drawingBlur:
            pointerPosition = point
        case .drawingHighlight:
            appendHighlightPoint(point)
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
        case let .movingHighlight(index, original, grabOffset):
            guard highlights.indices.contains(index), let first = original.points.first else { break }
            let proposedOrigin = CGPoint(
                x: point.x - grabOffset.x,
                y: point.y - grabOffset.y
            )
            var dx = proposedOrigin.x - first.x
            var dy = proposedOrigin.y - first.y

            let limits = visibleContentRect
            let bounds = highlightBounds(
                for: original,
                imageSize: CGSize(width: screenshot?.width ?? 0, height: screenshot?.height ?? 0)
            )
            dx = min(max(dx, limits.minX - bounds.minX), limits.maxX - bounds.maxX)
            dy = min(max(dy, limits.minY - bounds.minY), limits.maxY - bounds.maxY)

            highlights[index].points = original.points.map {
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
        case .drawingHighlight:
            if drawingHighlightPoints.count >= 2,
               polylineLength(drawingHighlightPoints) * cameraScale >= minimumDragDistance {
                highlights.append(Highlight(
                    points: drawingHighlightPoints,
                    color: currentHighlightColor,
                    thickness: currentHighlightThickness
                ))
                createdAnnotation = true
                selection = .highlight(highlights.count - 1)
                updateOptionsVisibility()
            } else {
                selection = nil
            }
        default:
            break
        }

        pointerPosition = nil
        drawingHighlightPoints = []
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

    override func resetCursorRects() {
        super.resetCursorRects()
        if activeTool == .text, screenshot != nil {
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
        optionsPanel.updateSelection(color: currentColor, thickness: currentThickness)
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
        optionsPanel.updateSelection(color: currentColor, thickness: currentThickness)
        optionsPanel.updateSquareSelection(isRounded: currentRounded, fill: currentFill)
        updateOptionsVisibility()
    }

    private func selectBlur(at index: Int) {
        guard blurRegions.indices.contains(index) else { return }
        selection = .blur(index)
        updateOptionsVisibility()
    }

    private func selectHighlight(at index: Int) {
        guard highlights.indices.contains(index) else { return }
        selection = .highlight(index)
        let highlight = highlights[index]
        currentHighlightColor = highlight.color
        currentHighlightThickness = highlight.thickness
        optionsPanel.updateHighlightSelection(
            color: currentHighlightColor,
            thickness: currentHighlightThickness
        )
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

    private func applyThickness(_ thickness: ArrowLineWidth) {
        let before = annotationSnapshot()
        var changedAnnotation = false
        currentThickness = thickness
        ArrowPreferences.lineWidth = thickness
        if case .arrow(let index)? = selection, arrows.indices.contains(index) {
            arrows[index].thickness = thickness
            changedAnnotation = true
        } else if case .square(let index)? = selection, squares.indices.contains(index) {
            squares[index].thickness = thickness
            changedAnnotation = true
        }
        if changedAnnotation { registerAnnotationUndo(restoring: before, actionName: "Change Thickness") }
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

    private func applyHighlightColor(_ color: ArrowColor) {
        let before = annotationSnapshot()
        var changedAnnotation = false
        currentHighlightColor = color
        HighlightPreferences.color = color
        if case .highlight(let index)? = selection, highlights.indices.contains(index) {
            highlights[index].color = color
            changedAnnotation = true
        }
        if changedAnnotation { registerAnnotationUndo(restoring: before, actionName: "Change Highlight Color") }
        needsDisplay = true
        window?.makeFirstResponder(self)
    }

    private func applyHighlightThickness(_ thickness: ArrowLineWidth) {
        let before = annotationSnapshot()
        var changedAnnotation = false
        currentHighlightThickness = thickness
        HighlightPreferences.lineWidth = thickness
        if case .highlight(let index)? = selection, highlights.indices.contains(index) {
            highlights[index].thickness = thickness
            changedAnnotation = true
        }
        if changedAnnotation { registerAnnotationUndo(restoring: before, actionName: "Change Highlight Thickness") }
        needsDisplay = true
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
        guard screenshot != nil else { return nil }
        switch activeTool {
        case .some(.arrow):
            return .arrow
        case .some(.square):
            return .square
        case .some(.blur):
            return nil
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
            case .some(.highlight):
                return .highlight
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
        if dragMode != nil {
            dragMode = nil
            pointerPosition = nil
            needsDisplay = true
            return true
        }
        if selection != nil {
            selection = nil
            optionsPanel.updateSelection(color: currentColor, thickness: currentThickness)
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
        case .highlight(let index):
            guard highlights.indices.contains(index) else { return false }
            highlights.remove(at: index)
        case .text(let index):
            guard textNotes.indices.contains(index) else { return false }
            textNotes.remove(at: index)
        }
        registerAnnotationUndo(restoring: before, actionName: "Delete Annotation")
        self.selection = nil
        optionsPanel.updateSelection(color: currentColor, thickness: currentThickness)
        optionsPanel.updateSquareSelection(isRounded: currentRounded, fill: currentFill)
        optionsPanel.updateHighlightSelection(color: currentHighlightColor, thickness: currentHighlightThickness)
        updateOptionsVisibility()
        needsDisplay = true
        return true
    }

    override func keyDown(with event: NSEvent) {
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
                thickness: arrows[index].thickness
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
                thickness: square.thickness
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

        // Highlighter strokes sit between the squares and the blur regions, so
        // they are hit-tested in that order.
        for index in highlights.indices.reversed() {
            let highlight = highlights[index]
            guard highlight.points.count >= 2 else { continue }
            let lineWidth = HighlightGeometry.lineWidth(
                forImageSize: imageSize,
                thickness: highlight.thickness
            )
            let tolerance = max(6, lineWidth * scale * 0.6)
            let points = highlight.points.map { contentToView($0) }
            for position in 0..<(points.count - 1) {
                if distance(from: point, toSegmentFrom: points[position], to: points[position + 1]) <= tolerance {
                    return .highlightBody(index)
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
        for highlight in highlights {
            bounds = bounds.union(highlightBounds(for: highlight, imageSize: imageSize))
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
            case .drawingHighlight?:
                if drawingHighlightPoints.count >= 2 {
                    bounds = bounds.union(highlightBounds(
                        for: Highlight(
                            points: drawingHighlightPoints,
                            color: currentHighlightColor,
                            thickness: currentHighlightThickness
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
    /// accidental endless zoom-outs from producing enormous exports.
    private var allowedContentRect: CGRect {
        guard let screenshot else { return .zero }
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

    /// Fits the content into the viewport with a border on every side.
    private func fitCameraToContent() {
        guard screenshot != nil, bounds.width > 1, bounds.height > 1 else { return }
        let content = contentBoundsForCamera
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
        var exportBounds = CGRect(
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
        for highlight in highlights {
            exportBounds = exportBounds.union(highlightBounds(for: highlight, imageSize: imageSize))
        }
        for note in textNotes {
            exportBounds = exportBounds.union(textBounds(for: note))
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

        // Highlighter strokes render below the squares and arrows, matching
        // the editor. The alpha keeps the content underneath readable.
        for highlight in highlights {
            guard highlight.points.count >= 2 else { continue }
            let lineWidth = HighlightGeometry.lineWidth(
                forImageSize: imageSize,
                thickness: highlight.thickness
            )
            let path = HighlightGeometry.path(
                points: highlight.points,
                transform: {
                    self.exportPoint($0, originX: originX, originY: originY, exportHeight: exportHeight)
                }
            )
            context.setStrokeColor(
                highlight.color.cgColor.copy(alpha: HighlightPreferences.alpha)
                    ?? highlight.color.cgColor
            )
            context.setLineWidth(lineWidth)
            context.addPath(path.cgPath)
            context.strokePath()
        }

        // Squares render below arrows, matching the editor.
        for square in squares {
            let lineWidth = ArrowGeometry.lineWidth(
                forImageSize: imageSize,
                thickness: square.thickness
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
                thickness: arrow.thickness
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
        let lineWidth = ArrowGeometry.lineWidth(forImageSize: imageSize, thickness: arrow.thickness)
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
        let lineWidth = ArrowGeometry.lineWidth(forImageSize: imageSize, thickness: square.thickness)
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

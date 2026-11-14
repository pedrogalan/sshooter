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

/// Preset colors shown in the options panel. The raw values keep the order
/// used by earlier versions, so saved preferences still map to the same
/// colors; declaration order is the 3×3 grid order.
enum ArrowColor: Int, CaseIterable {
    case red = 0
    case orange = 1
    case yellow = 2
    case green = 3
    case teal = 7
    case blue = 4
    case purple = 5
    case black = 6
    case white = 8

    var title: String {
        switch self {
        case .red: "Red"
        case .orange: "Orange"
        case .yellow: "Yellow"
        case .green: "Green"
        case .teal: "Teal"
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
        case .teal: .systemTeal
        case .blue: .systemBlue
        case .purple: .systemPurple
        case .black: .black
        case .white: .white
        }
    }
}

extension NSColor {
    /// The same color in the sRGB space, which is what the canvas and the PNG
    /// exporter work in. Pattern colors cannot be converted and pass through.
    var sRGBResolved: NSColor {
        usingColorSpace(.sRGB) ?? self
    }

    /// Compares colors in sRGB, ignoring the color space they were created in.
    func matchesRGB(_ other: NSColor, tolerance: CGFloat = 0.004) -> Bool {
        let lhs = sRGBResolved
        let rhs = other.sRGBResolved
        guard lhs.numberOfComponents >= 3, rhs.numberOfComponents >= 3 else {
            return lhs == rhs
        }
        return abs(lhs.redComponent - rhs.redComponent) <= tolerance
            && abs(lhs.greenComponent - rhs.greenComponent) <= tolerance
            && abs(lhs.blueComponent - rhs.blueComponent) <= tolerance
            && abs(lhs.alphaComponent - rhs.alphaComponent) <= tolerance
    }
}

enum ArrowPreferences {
    private static let legacyColorKey = "arrowColor"
    private static let colorComponentsKey = "arrowColorComponents"
    private static let lineWidthKey = "arrowLineWidth"

    static var color: NSColor {
        get {
            let defaults = UserDefaults.standard
            if let stored = defaults.array(forKey: colorComponentsKey) as? [NSNumber],
               stored.count >= 3 {
                return NSColor(
                    srgbRed: stored[0].doubleValue,
                    green: stored[1].doubleValue,
                    blue: stored[2].doubleValue,
                    alpha: stored.count > 3 ? stored[3].doubleValue : 1
                )
            }

            // Preferences written before custom colors were supported stored an
            // ArrowColor raw value under the legacy key.
            if defaults.object(forKey: legacyColorKey) != nil,
               let preset = ArrowColor(rawValue: defaults.integer(forKey: legacyColorKey)) {
                return preset.nsColor
            }
            return .systemRed
        }
        set {
            let resolved = newValue.sRGBResolved
            let components: [Double] = [
                Double(resolved.redComponent),
                Double(resolved.greenComponent),
                Double(resolved.blueComponent),
                Double(resolved.alphaComponent)
            ]
            UserDefaults.standard.set(components, forKey: colorComponentsKey)
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
    private let arrowButton = ToolStripButton(
        symbolName: "arrow.up.right",
        toolTip: "Arrow tool: drag on the canvas to draw. Click again to stop drawing."
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

        canvas.setImageToolActive(true)
        arrowButton.setActive(true)
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

        arrowButton.frame = NSRect(x: 106, y: 8, width: 40, height: 32)
        arrowButton.target = self
        arrowButton.action = #selector(toggleArrowTool(_:))
        toolStrip.addSubview(arrowButton)

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

        setArrowToolActive(true)
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
        setArrowToolActive(!canvas.isImageToolActive)
        makeFirstResponder(canvas)
    }

    private func setArrowToolActive(_ active: Bool) {
        canvas.setImageToolActive(active)
        arrowButton.setActive(active)
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

    // MARK: Window delegate

    func windowWillClose(_ notification: Notification) {
        canvas.closeColorPanel()
        // Keep the capture, annotations, title, and camera intact so the status
        // menu can reopen the editor exactly where it was left.
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
    let swatchColor: NSColor
    private(set) var isSelected = false {
        didSet { needsDisplay = true }
    }

    init(color: NSColor, title: String) {
        swatchColor = color
        super.init(frame: .zero)
        toolTip = title
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
        swatchColor.sRGBResolved.setFill()
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

/// A vertical rainbow chip that opens the full system color picker.
@MainActor
private final class CustomColorButton: HoverButton {
    private static let rainbow: [NSColor] = [
        .systemRed, .systemOrange, .systemYellow, .systemGreen,
        .systemCyan, .systemBlue, .systemPurple, .systemPink
    ]

    private var isSelected = false {
        didSet { needsDisplay = true }
    }
    private var currentColor: NSColor = .systemRed {
        didSet { needsDisplay = true }
    }

    init() {
        super.init(frame: .zero)
        toolTip = "Custom color…"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(color: NSColor, selected: Bool) {
        currentColor = color
        isSelected = selected
    }

    override func draw(_ dirtyRect: NSRect) {
        if isHovered {
            NSColor.labelColor.withAlphaComponent(0.08).setFill()
            NSBezierPath(
                roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
                xRadius: 8,
                yRadius: 8
            ).fill()
        }

        let rect = bounds.insetBy(dx: 4, dy: 4)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        NSGradient(colors: Self.rainbow)?.draw(in: path, angle: -90)
        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()

        if isSelected {
            let ring = NSBezierPath(
                roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5),
                xRadius: 8,
                yRadius: 8
            )
            NSColor.controlAccentColor.setStroke()
            ring.lineWidth = 2
            ring.stroke()

            let chip = NSBezierPath(ovalIn: bounds.insetBy(dx: 7, dy: bounds.height / 2 - 6))
            currentColor.sRGBResolved.setFill()
            chip.fill()
            NSColor.white.setStroke()
            chip.lineWidth = 1.5
            chip.stroke()
        }
    }
}

/// Right-angled ramp: short at the left, tall at the right. Dragging
/// horizontally snaps to one of the arrow width presets.
@MainActor
private final class ThicknessSlider: NSView {
    private static let minimumInset: CGFloat = 9
    private static let knobRadius: CGFloat = 5.5

    var onThicknessChanged: (@MainActor (ArrowLineWidth) -> Void)?

    var thickness: ArrowLineWidth = .regular {
        didSet {
            guard thickness != oldValue else { return }
            toolTip = "\(thickness.title) arrow"
            needsDisplay = true
        }
    }

    private var isHovered = false {
        didSet { needsDisplay = true }
    }
    private var isDragging = false
    private var trackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        toolTip = "\(thickness.title) arrow"
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

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        updateThickness(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        updateThickness(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        updateThickness(with: event)
        isDragging = false
    }

    private func updateThickness(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let fraction = min(max((point.x - trackRect.minX) / trackRect.width, 0), 1)
        let lastIndex = ArrowLineWidth.allCases.count - 1
        let index = Int((fraction * CGFloat(lastIndex)).rounded())
        guard let newThickness = ArrowLineWidth(rawValue: index),
              newThickness != thickness else { return }
        thickness = newThickness
        onThicknessChanged?(newThickness)
    }

    private var trackRect: NSRect {
        bounds.insetBy(dx: Self.minimumInset, dy: Self.minimumInset)
    }

    private func knobPoint(for thickness: ArrowLineWidth) -> NSPoint {
        let lastIndex = max(1, ArrowLineWidth.allCases.count - 1)
        let fraction = CGFloat(thickness.rawValue) / CGFloat(lastIndex)
        let track = trackRect
        return NSPoint(
            x: track.minX + fraction * track.width,
            y: track.minY + fraction * track.height
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        let track = trackRect
        guard track.width > 0, track.height > 0 else { return }

        if isHovered || isDragging {
            NSColor.labelColor.withAlphaComponent(0.05).setFill()
            NSBezierPath(
                roundedRect: bounds.insetBy(dx: 1, dy: 1),
                xRadius: 7,
                yRadius: 7
            ).fill()
        }

        let triangle = NSBezierPath()
        triangle.move(to: NSPoint(x: track.minX, y: track.minY))
        triangle.line(to: NSPoint(x: track.maxX, y: track.minY))
        triangle.line(to: NSPoint(x: track.maxX, y: track.maxY))
        triangle.close()

        NSColor.labelColor.withAlphaComponent(0.07).setFill()
        triangle.fill()

        // Fill the part of the ramp up to the current value.
        let knob = knobPoint(for: thickness)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: NSRect(
            x: track.minX,
            y: track.minY,
            width: max(0, knob.x - track.minX),
            height: track.height
        )).addClip()
        NSColor.controlAccentColor.withAlphaComponent(0.28).setFill()
        triangle.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSColor.separatorColor.setStroke()
        triangle.lineWidth = 1
        triangle.stroke()

        // Tick marks for the four widths, just under the ramp.
        NSColor.tertiaryLabelColor.setStroke()
        for preset in ArrowLineWidth.allCases {
            let point = knobPoint(for: preset)
            let tick = NSBezierPath()
            tick.move(to: NSPoint(x: point.x, y: track.minY))
            tick.line(to: NSPoint(x: point.x, y: track.minY - 3))
            tick.lineWidth = 1
            tick.stroke()
        }

        let knobRect = NSRect(
            x: knob.x - Self.knobRadius,
            y: knob.y - Self.knobRadius,
            width: Self.knobRadius * 2,
            height: Self.knobRadius * 2
        )
        let knobPath = NSBezierPath(ovalIn: knobRect)
        NSColor.controlBackgroundColor.setFill()
        knobPath.fill()
        NSColor.controlAccentColor.setStroke()
        knobPath.lineWidth = 2
        knobPath.stroke()
    }
}

// MARK: - Options panel

@MainActor
private final class ArrowOptionsPanel: NSView {
    private static let swatchSize: CGFloat = 22
    private static let swatchSpacing: CGFloat = 6
    private static let columnCount = 3
    private static let rowCount = 3
    private static let customColorWidth: CGFloat = 26
    private static let customColorGap: CGFloat = 6
    private static let sliderWidth: CGFloat = 136
    private static let horizontalPadding: CGFloat = 12
    private static let verticalPadding: CGFloat = 12
    private static let dividerGap: CGFloat = 12

    private static var gridWidth: CGFloat {
        CGFloat(columnCount) * swatchSize + CGFloat(columnCount - 1) * swatchSpacing
    }

    private static var gridHeight: CGFloat {
        CGFloat(rowCount) * swatchSize + CGFloat(rowCount - 1) * swatchSpacing
    }

    var onColorSelected: (@MainActor (NSColor) -> Void)?
    var onThicknessSelected: (@MainActor (ArrowLineWidth) -> Void)?
    var onCustomColorRequested: (@MainActor () -> Void)?

    private var swatchButtons: [ColorSwatchButton] = []
    private let customColorButton = CustomColorButton()
    private let thicknessSlider = ThicknessSlider()

    override var isFlipped: Bool { false }

    convenience init() {
        self.init(frame: NSRect(origin: .zero, size: Self.preferredSize))
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static var preferredSize: NSSize {
        let width = horizontalPadding * 2
            + gridWidth
            + customColorGap + customColorWidth
            + dividerGap * 2 + 1
            + sliderWidth
        let height = verticalPadding * 2 + gridHeight
        return NSSize(width: width, height: height)
    }

    private func buildSubviews() {
        for (index, preset) in ArrowColor.allCases.enumerated() {
            let button = ColorSwatchButton(color: preset.nsColor, title: preset.title)
            button.target = self
            button.action = #selector(selectColor(_:))
            let column = index % Self.columnCount
            let row = index / Self.columnCount
            let x = Self.horizontalPadding
                + CGFloat(column) * (Self.swatchSize + Self.swatchSpacing)
            let y = Self.verticalPadding
                + CGFloat(Self.rowCount - 1 - row) * (Self.swatchSize + Self.swatchSpacing)
            button.frame = NSRect(x: x, y: y, width: Self.swatchSize, height: Self.swatchSize)
            addSubview(button)
            swatchButtons.append(button)
        }

        let customX = Self.horizontalPadding + Self.gridWidth + Self.customColorGap
        customColorButton.target = self
        customColorButton.action = #selector(selectCustomColor(_:))
        customColorButton.frame = NSRect(
            x: customX,
            y: Self.verticalPadding,
            width: Self.customColorWidth,
            height: Self.gridHeight
        )
        addSubview(customColorButton)

        let dividerX = customX + Self.customColorWidth + Self.dividerGap
        let divider = NSBox(frame: NSRect(
            x: dividerX,
            y: Self.verticalPadding,
            width: 1,
            height: Self.gridHeight
        ))
        divider.boxType = .separator
        addSubview(divider)

        thicknessSlider.onThicknessChanged = { [weak self] thickness in
            self?.onThicknessSelected?(thickness)
        }
        thicknessSlider.frame = NSRect(
            x: dividerX + 1 + Self.dividerGap,
            y: Self.verticalPadding,
            width: Self.sliderWidth,
            height: Self.gridHeight
        )
        addSubview(thicknessSlider)
    }

    func updateSelection(color: NSColor, thickness: ArrowLineWidth) {
        var matchesPreset = false
        for button in swatchButtons {
            let matches = button.swatchColor.matchesRGB(color)
            button.setSelected(matches)
            matchesPreset = matchesPreset || matches
        }
        customColorButton.update(color: color, selected: !matchesPreset)
        thicknessSlider.thickness = thickness
    }

    @objc private func selectColor(_ sender: ColorSwatchButton) {
        updateSelection(color: sender.swatchColor, thickness: thicknessSlider.thickness)
        onColorSelected?(sender.swatchColor)
    }

    @objc private func selectCustomColor(_ sender: Any?) {
        onCustomColorRequested?()
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
private final class AnnotationCanvasView: NSView {
    private struct Arrow {
        var start: CGPoint
        var end: CGPoint
        var color: NSColor
        var thickness: ArrowLineWidth
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
    private let optionsMargin: CGFloat = 20

    private var screenshot: CGImage?
    private var screenshotImage: NSImage?
    private var arrows: [Arrow] = []
    private var selectedArrowIndex: Int?
    private var dragMode: DragMode?
    private var pointerPosition: CGPoint?
    private var currentColor = ArrowPreferences.color
    private var currentThickness = ArrowPreferences.lineWidth
    private var trackingArea: NSTrackingArea?
    private let optionsPanel = ArrowOptionsPanel()

    /// View transform: `cameraCenter` is the content point at the viewport
    /// center, and `cameraScale` is view points per content unit. Content is
    /// the original screenshot plus every annotation. See `fitCameraToContent`.
    private var cameraCenter: CGPoint = .zero
    private var cameraScale: CGFloat = 1
    private var hasCamera = false
    private let minimumCameraScale: CGFloat = 0.02
    private let maximumCameraScale: CGFloat = 4

    private(set) var isImageToolActive = true

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        optionsPanel.isHidden = true
        optionsPanel.onColorSelected = { [weak self] color in
            self?.applyColor(color)
        }
        optionsPanel.onThicknessSelected = { [weak self] thickness in
            self?.applyThickness(thickness)
        }
        optionsPanel.onCustomColorRequested = { [weak self] in
            self?.showColorPanel()
        }
        optionsPanel.updateSelection(color: currentColor, thickness: currentThickness)
        addSubview(optionsPanel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Content

    var hasImage: Bool { screenshot != nil }

    func setImage(_ image: CGImage) {
        screenshot = image
        screenshotImage = NSImage(
            cgImage: image,
            size: NSSize(width: image.width, height: image.height)
        )
        currentColor = ArrowPreferences.color
        currentThickness = ArrowPreferences.lineWidth
        arrows.removeAll()
        selectedArrowIndex = nil
        dragMode = nil
        pointerPosition = nil
        hasCamera = false
        optionsPanel.updateSelection(color: currentColor, thickness: currentThickness)
        updateOptionsVisibility(animated: false)
        fitCameraToContent()
        needsDisplay = true
    }

    func setImageToolActive(_ active: Bool) {
        isImageToolActive = active
        if !active {
            dragMode = nil
            pointerPosition = nil
            selectedArrowIndex = nil
            optionsPanel.updateSelection(color: currentColor, thickness: currentThickness)
            needsDisplay = true
        }
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

        for (index, arrow) in arrows.enumerated() {
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
                color: arrow.color
            )
            if index == selectedArrowIndex {
                drawHandles(for: arrow)
            }
        }

        if case .drawing(let start)? = dragMode, let pointerPosition {
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
                color: currentColor
            )
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
        color.sRGBResolved.setStroke()
        path.stroke()
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
            arrow.color.sRGBResolved.setStroke()
            path.lineWidth = 2
            path.stroke()
        }
    }

    // MARK: Mouse handling

    override func mouseDown(with event: NSEvent) {
        ensureCamera()
        let pointInView = convert(event.locationInWindow, from: nil)
        guard screenshot != nil, let contentPoint = clampedContentPoint(for: pointInView) else {
            selectedArrowIndex = nil
            dragMode = nil
            needsDisplay = true
            return
        }

        if let target = hitTest(at: pointInView) {
            switch target {
            case .start(let index):
                selectArrow(at: index)
                dragMode = .resizingStart(index: index)
            case .end(let index):
                selectArrow(at: index)
                dragMode = .resizingEnd(index: index)
            case .body(let index):
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
            }
        } else if isImageToolActive {
            selectedArrowIndex = nil
            optionsPanel.updateSelection(color: currentColor, thickness: currentThickness)
            dragMode = .drawing(start: contentPoint)
            pointerPosition = contentPoint
        } else {
            selectedArrowIndex = nil
            dragMode = nil
            optionsPanel.updateSelection(color: currentColor, thickness: currentThickness)
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let mode = dragMode else { return }
        let pointInView = clampedViewPoint(convert(event.locationInWindow, from: nil))
        guard let point = clampedContentPoint(for: pointInView) else { return }

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

            let limits = visibleContentRect
            let minX = min(original.start.x, original.end.x)
            let maxX = max(original.start.x, original.end.x)
            let minY = min(original.start.y, original.end.y)
            let maxY = max(original.start.y, original.end.y)
            dx = min(max(dx, limits.minX - minX), limits.maxX - maxX)
            dy = min(max(dy, limits.minY - minY), limits.maxY - maxY)

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

        let pointInView = clampedViewPoint(convert(event.locationInWindow, from: nil))
        if case .drawing(let start) = mode,
           let end = clampedContentPoint(for: pointInView) {
            let startInView = contentToView(start)
            let endInView = contentToView(end)
            if distance(from: startInView, to: endInView) >= minimumDragDistance {
                arrows.append(Arrow(
                    start: start,
                    end: end,
                    color: currentColor,
                    thickness: currentThickness
                ))
                selectedArrowIndex = arrows.count - 1
                updateOptionsVisibility()
            } else {
                selectedArrowIndex = nil
            }
        }

        pointerPosition = nil
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
        NSCursor.arrow.set()
    }

    private func updateCursor(at _: CGPoint) {
        NSCursor.arrow.set()
    }

    // MARK: Selection and style

    private func selectArrow(at index: Int) {
        guard arrows.indices.contains(index) else { return }
        selectedArrowIndex = index
        let arrow = arrows[index]
        currentColor = arrow.color
        currentThickness = arrow.thickness
        optionsPanel.updateSelection(color: currentColor, thickness: currentThickness)
    }

    private func applyColor(_ color: NSColor, refocusCanvas: Bool = true) {
        currentColor = color
        ArrowPreferences.color = color
        if let index = selectedArrowIndex, arrows.indices.contains(index) {
            arrows[index].color = color
        }
        optionsPanel.updateSelection(color: color, thickness: currentThickness)
        needsDisplay = true
        if refocusCanvas {
            window?.makeFirstResponder(self)
        }
    }

    private func applyThickness(_ thickness: ArrowLineWidth) {
        currentThickness = thickness
        ArrowPreferences.lineWidth = thickness
        if let index = selectedArrowIndex, arrows.indices.contains(index) {
            arrows[index].thickness = thickness
        }
        optionsPanel.updateSelection(color: currentColor, thickness: thickness)
        needsDisplay = true
        window?.makeFirstResponder(self)
    }

    // MARK: Custom color

    private func showColorPanel() {
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.isContinuous = true
        panel.color = currentColor
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelChanged(_:)))
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func colorPanelChanged(_ sender: NSColorPanel) {
        // Keep the panel focused while the user drags or types in it.
        applyColor(sender.color, refocusCanvas: false)
    }

    /// Detaches the shared panel when the editor closes so it does not linger
    /// or keep sending changes to a hidden canvas.
    func closeColorPanel() {
        guard NSColorPanel.sharedColorPanelExists else { return }
        let panel = NSColorPanel.shared
        panel.setTarget(nil)
        panel.setAction(nil)
        panel.orderOut(nil)
    }

    private func updateOptionsVisibility(animated: Bool = true) {
        let shouldShow = !arrows.isEmpty
        if shouldShow {
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
        } else {
            optionsPanel.isHidden = true
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
        if selectedArrowIndex != nil {
            selectedArrowIndex = nil
            optionsPanel.updateSelection(color: currentColor, thickness: currentThickness)
            needsDisplay = true
            return true
        }
        return false
    }

    @discardableResult
    private func deleteSelectedArrow() -> Bool {
        guard let index = selectedArrowIndex, arrows.indices.contains(index) else { return false }
        arrows.remove(at: index)
        selectedArrowIndex = nil
        optionsPanel.updateSelection(color: currentColor, thickness: currentThickness)
        updateOptionsVisibility()
        needsDisplay = true
        return true
    }

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

        for index in arrows.indices.reversed() {
            let start = contentToView(arrows[index].start)
            let end = contentToView(arrows[index].end)
            if distance(from: point, to: end) <= endpointTolerance {
                return .end(index)
            }
            if distance(from: point, to: start) <= endpointTolerance {
                return .start(index)
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
        return bounds
    }

    /// Includes the arrow currently being dragged out, before it is committed.
    private var contentBoundsForCamera: CGRect {
        guard let screenshot else { return .zero }
        var bounds = contentBounds
        if case .drawing(let start)? = dragMode, let pointerPosition {
            let imageSize = CGSize(width: screenshot.width, height: screenshot.height)
            bounds = bounds.union(arrowBounds(
                for: Arrow(
                    start: start,
                    end: pointerPosition,
                    color: currentColor,
                    thickness: currentThickness
                ),
                imageSize: imageSize
            ))
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
        guard let image = renderCGImage() else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }

    func pngDataWithAnnotations() -> Data? {
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
        context.draw(screenshot, in: CGRect(
            x: -originX,
            y: CGFloat(exportHeight) + originY - CGFloat(imageHeight),
            width: CGFloat(imageWidth),
            height: CGFloat(imageHeight)
        ))

        context.setLineCap(.round)
        context.setLineJoin(.round)

        for arrow in arrows {
            let lineWidth = ArrowGeometry.lineWidth(
                forImageSize: imageSize,
                thickness: arrow.thickness
            )
            let headLength = ArrowGeometry.headLength(forLineWidth: lineWidth)
            context.setStrokeColor(arrow.color.sRGBResolved.cgColor)
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

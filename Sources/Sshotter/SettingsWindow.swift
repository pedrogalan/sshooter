import AppKit

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let onClose: @MainActor () -> Void
    private let folderValue = NSTextField(labelWithString: "")
    private let autoSaveCheckbox = NSButton(checkboxWithTitle: "Save captures automatically", target: nil, action: nil)

    init(onClose: @escaping @MainActor () -> Void) {
        self.onClose = onClose
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 190),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)

        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.delegate = self
        buildContents(in: window)
        refreshValues()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        window?.center()
        showWindow(nil)
        NSApp.activate()
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }

    private func buildContents(in window: NSWindow) {
        guard let contentView = window.contentView else { return }

        let folderLabel = NSTextField(labelWithString: "Save screenshots to:")
        folderLabel.setContentHuggingPriority(.required, for: .horizontal)

        folderValue.lineBreakMode = .byTruncatingMiddle
        folderValue.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let chooseFolderButton = NSButton(
            title: "Choose…",
            target: self,
            action: #selector(chooseSaveFolder(_:))
        )

        let folderRow = NSStackView(views: [folderLabel, folderValue, chooseFolderButton])
        folderRow.orientation = .horizontal
        folderRow.alignment = .centerY
        folderRow.spacing = 12

        autoSaveCheckbox.target = self
        autoSaveCheckbox.action = #selector(autoSaveChanged(_:))

        let infoButton = NSButton(
            image: NSImage(systemSymbolName: "info.circle", accessibilityDescription: "About automatic saving")!,
            target: self,
            action: #selector(showAutoSaveInformation(_:))
        )
        infoButton.isBordered = false
        infoButton.toolTip = "What gets saved automatically?"
        infoButton.setContentHuggingPriority(.required, for: .horizontal)

        let autoSaveRow = NSStackView(views: [autoSaveCheckbox, infoButton])
        autoSaveRow.orientation = .horizontal
        autoSaveRow.alignment = .centerY
        autoSaveRow.spacing = 8

        let stack = NSStackView(views: [folderRow, autoSaveRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 22
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            folderRow.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func refreshValues() {
        if let folder = ScreenshotStore.shared.saveFolderURL {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            if folder.path == home {
                folderValue.stringValue = "~"
            } else if folder.path.hasPrefix(home + "/") {
                folderValue.stringValue = "~" + folder.path.dropFirst(home.count)
            } else {
                folderValue.stringValue = folder.path
            }
        } else {
            folderValue.stringValue = "No folder selected"
        }
        autoSaveCheckbox.state = ScreenshotStore.shared.autoSaveCaptures ? .on : .off
    }

    @objc private func chooseSaveFolder(_ sender: Any?) {
        _ = ScreenshotStore.shared.chooseSaveFolder()
        refreshValues()
    }

    @objc private func autoSaveChanged(_ sender: NSButton) {
        ScreenshotStore.shared.autoSaveCaptures = sender.state == .on
    }

    @objc private func showAutoSaveInformation(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "What gets saved automatically?"
        alert.informativeText = "Each selected capture is saved as a PNG before it opens in the editor. This automatic save contains the original image only; annotations such as arrows and text are not included. Use ⌘S in the editor to save the annotated image."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        if let window, window.isVisible {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}

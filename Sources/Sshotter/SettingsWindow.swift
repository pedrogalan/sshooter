import AppKit

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private static let githubURL = URL(string: "https://github.com/pedrogalan/sshooter")!

    private let onClose: @MainActor () -> Void
    private let folderValue = NSTextField(labelWithString: "")
    private let autoSaveCheckbox = NSButton(checkboxWithTitle: "Save captures automatically", target: nil, action: nil)
    private let warningLabel = NSTextField(wrappingLabelWithString: "")
    private var statusLabels: [Permission: NSTextField] = [:]

    init(onClose: @escaping @MainActor () -> Void) {
        self.onClose = onClose
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)

        window.title = "sShooter Settings"
        window.isReleasedWhenClosed = false
        window.delegate = self
        buildContents(in: window)
        refreshValues()
        refreshPermissions()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshPermissions),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        refreshValues()
        refreshPermissions()
        window?.center()
        showWindow(nil)
        NSApp.activate()
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }

    // MARK: - Layout

    private func buildContents(in window: NSWindow) {
        guard let contentView = window.contentView else { return }

        let tabView = NSTabView()
        tabView.tabViewType = .topTabsBezelBorder
        tabView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tabView)

        let generalItem = NSTabViewItem(identifier: "general")
        generalItem.label = "General"
        generalItem.view = makeGeneralView()
        tabView.addTabViewItem(generalItem)

        let permissionsItem = NSTabViewItem(identifier: "permissions")
        permissionsItem.label = "Permissions"
        permissionsItem.view = makePermissionsView()
        tabView.addTabViewItem(permissionsItem)

        let aboutItem = NSTabViewItem(identifier: "about")
        aboutItem.label = "About"
        aboutItem.view = makeAboutView()
        tabView.addTabViewItem(aboutItem)

        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            tabView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }

    private func makeGeneralView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 400))

        let folderLabel = NSTextField(labelWithString: "Save screenshots to:")
        folderLabel.font = NSFont.systemFont(ofSize: 12)
        folderLabel.setContentHuggingPriority(.required, for: .horizontal)

        folderValue.font = NSFont.systemFont(ofSize: 12)
        folderValue.lineBreakMode = .byTruncatingMiddle
        folderValue.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let chooseFolderButton = NSButton(
            title: "Choose…",
            target: self,
            action: #selector(chooseSaveFolder(_:))
        )
        chooseFolderButton.bezelStyle = .rounded

        let folderRow = NSStackView(views: [folderLabel, folderValue, chooseFolderButton])
        folderRow.orientation = .horizontal
        folderRow.alignment = .centerY
        folderRow.spacing = 8
        folderRow.translatesAutoresizingMaskIntoConstraints = false

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

        let hint = NSTextField(
            wrappingLabelWithString: "sShooter lives in the menu bar. Press ⌘⇧2 or choose Capture area to take a screenshot."
        )
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.preferredMaxLayoutWidth = 430

        let stack = NSStackView(views: [folderRow, autoSaveRow, hint])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -16),
            folderRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])

        return view
    }

    private func makePermissionsView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 400))

        let intro = NSTextField(
            wrappingLabelWithString: "Grant Screen Recording in System Settings. sShooter reconnects automatically when you return."
        )
        intro.font = NSFont.systemFont(ofSize: 12)
        intro.preferredMaxLayoutWidth = 430

        warningLabel.font = NSFont.systemFont(ofSize: 11)
        warningLabel.textColor = .systemOrange
        warningLabel.preferredMaxLayoutWidth = 430

        var permissionRows: [NSView] = []
        for permission in Permission.allCases {
            let title = NSTextField(labelWithString: permission.title)
            title.font = NSFont.systemFont(ofSize: 12)

            let status = NSTextField(labelWithString: "")
            status.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            status.alignment = .right
            status.translatesAutoresizingMaskIntoConstraints = false
            status.widthAnchor.constraint(equalToConstant: 60).isActive = true
            statusLabels[permission] = status

            let openButton = NSButton(
                title: "Open…",
                target: self,
                action: #selector(openPermissionSettings(_:))
            )
            openButton.bezelStyle = .inline
            openButton.controlSize = .small
            openButton.tag = permission.rawValue

            let row = NSStackView(views: [title, status, openButton])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8
            permissionRows.append(row)
        }

        let stack = NSStackView(views: [intro, warningLabel] + permissionRows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -16),
        ])

        return view
    }

    private func makeAboutView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 400))

        let iconImage = NSApp.applicationIconImage
            ?? NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        let iconView = NSImageView(image: iconImage)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 96).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 96).isActive = true

        let nameLabel = NSTextField(labelWithString: "sShooter")
        nameLabel.font = NSFont.boldSystemFont(ofSize: 20)
        nameLabel.alignment = .center

        let versionLabel = NSTextField(labelWithString: "Version \(appVersion)")
        versionLabel.font = NSFont.systemFont(ofSize: 11)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center

        let description = NSTextField(
            wrappingLabelWithString: "A lightweight, native macOS menu bar screenshot utility. Capture an area and mark it up with arrows, shapes, text, and blur."
        )
        description.font = NSFont.systemFont(ofSize: 12)
        description.alignment = .center
        description.preferredMaxLayoutWidth = 360

        let githubButton = NSButton(
            title: "github.com/pedrogalan/sshooter",
            target: self,
            action: #selector(openGitHub)
        )
        githubButton.bezelStyle = .rounded

        let year = Calendar.current.component(.year, from: Date())
        let copyright = NSTextField(labelWithString: "© \(year) Pedro Galán")
        copyright.font = NSFont.systemFont(ofSize: 10)
        copyright.textColor = .tertiaryLabelColor
        copyright.alignment = .center

        let license = NSTextField(labelWithString: "Licensed under the MIT License")
        license.font = NSFont.systemFont(ofSize: 10)
        license.textColor = .tertiaryLabelColor
        license.alignment = .center

        let stack = NSStackView(views: [
            iconView,
            nameLabel,
            versionLabel,
            description,
            githubButton,
            copyright,
            license,
        ])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 28),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
        ])

        return view
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(shortVersion) (\(build))"
    }

    // MARK: - Values

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

    @objc private func refreshPermissions() {
        for permission in Permission.allCases {
            let granted = permission.isGranted
            guard let status = statusLabels[permission] else { continue }
            status.stringValue = granted ? "Granted" : "Missing"
            status.textColor = granted ? .systemGreen : .systemRed
        }

        if Permission.screenRecording.isGranted {
            warningLabel.stringValue = ""
            warningLabel.isHidden = true
        } else {
            warningLabel.stringValue = "Screen Recording is required to capture the screen. Grant it, then return here; sShooter reconnects automatically."
            warningLabel.isHidden = false
        }
    }

    // MARK: - Actions

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

    @objc private func openPermissionSettings(_ sender: NSButton) {
        guard let permission = Permission(rawValue: sender.tag) else { return }
        NSWorkspace.shared.open(permission.settingsURL)
    }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(Self.githubURL)
    }
}

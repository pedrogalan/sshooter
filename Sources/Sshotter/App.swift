import AppKit
import Carbon

@main
enum SshooterMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var statusMenu: NSMenu?
    private var reopenEditorItem: NSMenuItem?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let button = statusItem.button {
            if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                image.isTemplate = true
                image.size = NSSize(width: 18, height: 18)
                button.image = image
            } else {
                button.image = NSImage(systemSymbolName: "camera", accessibilityDescription: "sShooter")
            }
        }

        buildStatusMenu()
        buildMainMenu()
        registerHotKey()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    // MARK: - Menu bar (status item)

    private func buildStatusMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let reopenItem = NSMenuItem(
            title: "Reopen editor",
            action: #selector(reopenEditor(_:)),
            keyEquivalent: ""
        )
        reopenItem.target = self
        reopenItem.isEnabled = CaptureModel.shared.canReopenEditor
        menu.addItem(reopenItem)
        reopenEditorItem = reopenItem

        menu.addItem(.separator())

        let captureItem = NSMenuItem(
            title: "Capture area",
            action: #selector(captureArea(_:)),
            keyEquivalent: "2"
        )
        captureItem.keyEquivalentModifierMask = [.command, .shift]
        captureItem.target = self
        menu.addItem(captureItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings",
            action: #selector(showSettings(_:)),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusMenu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        reopenEditorItem?.isEnabled = CaptureModel.shared.canReopenEditor
    }

    @objc private func reopenEditor(_ sender: Any?) {
        CaptureModel.shared.reopenEditor()
    }

    @objc private func showSettings(_ sender: Any?) {
        NSApp.setActivationPolicy(.regular)
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController { [weak self] in
                CaptureModel.shared.settingsDidClose()
                self?.settingsWindowController = nil
            }
        }
        settingsWindowController?.show()
    }

    // MARK: - Main menu

    /// Builds the application menu bar. It is only visible while the app runs
    /// with the `.regular` activation policy (while the editor is open).
    private func buildMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        appMenu.addItem(withTitle: "About sShooter", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(showSettings(_:)),
            keyEquivalent: ""
        )
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())

        appMenu.addItem(withTitle: "Hide sShooter", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthersItem = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())

        let closeEditorItem = NSMenuItem(
            title: "Close Editor",
            action: #selector(closeEditor(_:)),
            keyEquivalent: "q"
        )
        closeEditorItem.target = self
        appMenu.addItem(closeEditorItem)
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Quit sShooter",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: ""
        )

        mainMenu.addItem(appMenuItem)

        let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu

        let captureItem = NSMenuItem(
            title: "Capture Area",
            action: #selector(captureArea(_:)),
            keyEquivalent: "2"
        )
        captureItem.keyEquivalentModifierMask = [.command, .shift]
        captureItem.target = self
        fileMenu.addItem(captureItem)
        fileMenu.addItem(.separator())
        fileMenu.addItem(
            withTitle: "Save Screenshot",
            action: #selector(AnnotationEditorWindow.saveScreenshot(_:)),
            keyEquivalent: "s"
        )
        fileMenu.addItem(
            withTitle: "Close",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        mainMenu.addItem(fileMenuItem)

        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(
            withTitle: "Undo",
            action: #selector(AnnotationEditorWindow.undoAnnotation(_:)),
            keyEquivalent: "z"
        )
        let redoItem = editMenu.addItem(
            withTitle: "Redo",
            action: #selector(AnnotationEditorWindow.redoAnnotation(_:)),
            keyEquivalent: "z"
        )
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(
            withTitle: "Copy Screenshot",
            action: #selector(AnnotationEditorWindow.copyScreenshot(_:)),
            keyEquivalent: "c"
        )
        mainMenu.addItem(editMenuItem)

        let windowMenuItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        mainMenu.addItem(windowMenuItem)

        NSApp.windowsMenu = windowMenu
        NSApp.mainMenu = mainMenu
    }

    // MARK: - Actions

    @objc private func captureArea(_ sender: Any?) {
        CaptureModel.shared.beginRegionCapture()
    }

    @objc private func closeEditor(_ sender: Any?) {
        CaptureModel.shared.closeEditor()
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    // MARK: - Global hotkey

    private func registerHotKey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in delegate.captureArea(nil) }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        guard handlerStatus == noErr else {
            showHotKeyError(handlerStatus)
            return
        }

        let identifier = EventHotKeyID(signature: OSType(0x53534852), id: 1)
        let registrationStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_2),
            UInt32(cmdKey | shiftKey),
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        if registrationStatus != noErr {
            showHotKeyError(registrationStatus)
        }
    }

    private func showHotKeyError(_ status: OSStatus) {
        let item = NSMenuItem(title: "Shortcut unavailable (error \(status))", action: nil, keyEquivalent: "")
        item.isEnabled = false
        statusMenu?.insertItem(item, at: 1)
        statusItem.button?.toolTip = "sShooter: ⌘⇧2 shortcut unavailable (error \(status))"
    }
}

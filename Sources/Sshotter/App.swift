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
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var appMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "camera", accessibilityDescription: "sshooter")
        }

        let menu = NSMenu()
        let captureItem = NSMenuItem(title: "Capture Area  ⌘⇧2", action: #selector(captureArea), keyEquivalent: "")
        captureItem.target = self
        menu.addItem(captureItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit sshooter", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
        appMenu = menu

        registerHotKey()
    }

    @objc private func captureArea() {
        CaptureModel.shared.beginRegionCapture()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func registerHotKey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in delegate.captureArea() }
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
        appMenu?.insertItem(item, at: 1)
        statusItem.button?.toolTip = "sshooter: ⌘⇧2 shortcut unavailable (error \(status))"
    }
}

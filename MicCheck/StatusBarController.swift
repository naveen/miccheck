import AppKit

final class StatusBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem
    private let micManager: MicrophoneManager
    private let menu = NSMenu()

    private enum Tag: Int { case toggle = 1, permWarning = 2 }

    init(micManager: MicrophoneManager) {
        self.micManager = micManager
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        buildMenu()
        updateLabel()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(micStateChanged),
            name: .microphoneStateChanged,
            object: nil
        )
    }

    // MARK: - Menu

    private func buildMenu() {
        menu.delegate = self

        // Permission warning — visible only when microphone access is not granted
        let permItem = NSMenuItem(title: "⚠️ Enable Microphone Access…", action: #selector(openMicPermission), keyEquivalent: "")
        permItem.tag = Tag.permWarning.rawValue
        permItem.target = self
        menu.addItem(permItem)

        let toggleItem = NSMenuItem(title: "", action: #selector(toggleMic), keyEquivalent: "")
        toggleItem.tag = Tag.toggle.rawValue
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        let quitItem = NSMenuItem(title: "Quit MicCheck", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        let hasPermission = AppDelegate.microphonePermissionGranted()
        if let permItem = menu.item(withTag: Tag.permWarning.rawValue) {
            permItem.isHidden = hasPermission
        }
        let isMuted = micManager.isMuted
        menu.item(withTag: Tag.toggle.rawValue)?.title = isMuted ? "Unmute Microphone" : "Mute Microphone"
    }

    // MARK: - Actions

    @objc private func toggleMic() { micManager.toggle() }

    @objc private func openMicPermission() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
    }

    @objc private func openPreferences() {
        PreferencesWindowController.shared.show()
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: - Label

    @objc private func micStateChanged() {
        DispatchQueue.main.async { self.updateLabel() }
    }

    private func updateLabel() {
        guard let button = statusItem.button else { return }
        let isMuted = micManager.isMuted
        let text = isMuted ? "OFF AIR" : "ON AIR"
        let color: NSColor = isMuted ? .tertiaryLabelColor : .systemRed
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .bold),
            .foregroundColor: color,
        ]
        button.image = nil
        button.imagePosition = .noImage
        button.attributedTitle = NSAttributedString(string: text, attributes: attrs)
    }
}

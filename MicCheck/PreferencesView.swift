import SwiftUI
import Carbon
import ServiceManagement
import UniformTypeIdentifiers

struct PreferencesView: View {
    @AppStorage("launchAtLogin")      private var launchAtLogin      = false
    @AppStorage("showNotifications")  private var showNotifications  = true
    @AppStorage("playSound")          private var playSound          = true
    @AppStorage("unmuteOnQuit")       private var unmuteOnQuit       = true

    @State private var whitelistedApps: [WhitelistedApp] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("MicCheck")
                        .font(.title2.bold())
                    Text("Microphone Mute Manager")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                MicStatusBadge()
            }
            .padding()
            .background(.regularMaterial)

            Divider()

            // Settings
            Form {
                Section("Behavior") {
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { newValue in
                            setLaunchAtLogin(newValue)
                        }
                    Toggle("Unmute microphone when MicCheck quits", isOn: $unmuteOnQuit)
                }

                Section("Feedback") {
                    Toggle("Play sound when toggling", isOn: $playSound)
                    Toggle("Show notification when toggling", isOn: $showNotifications)
                        .onChange(of: showNotifications) { newValue in
                            if newValue { NotificationManager.requestPermission() }
                        }
                }

                Section("Keyboard Shortcut") {
                    HotkeyRow()
                }

                Section {
                    if whitelistedApps.isEmpty {
                        Text("No apps added — all apps are blocked from changing mic state.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(whitelistedApps) { app in
                            HStack(spacing: 8) {
                                if let icon = app.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                }
                                Text(app.name)
                                Spacer()
                                Button {
                                    removeApp(app.bundleID)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Button("Add App…") { addApp() }
                } header: {
                    Text("Allowed Apps")
                } footer: {
                    Text("Allowed apps may temporarily change the mic state. All other apps are blocked.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .padding(.top, -12)
            .onAppear { whitelistedApps = loadWhitelistedApps() }

            Divider()

            // Footer
            HStack {
                Text("MicCheck v1.0")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Whitelist

    private func loadWhitelistedApps() -> [WhitelistedApp] {
        let ids = UserDefaults.standard.stringArray(forKey: "whitelistedBundleIDs") ?? []
        return ids.map { bundleID in
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            let name = url.map { ($0.lastPathComponent as NSString).deletingPathExtension } ?? bundleID
            let icon = url.map { NSWorkspace.shared.icon(forFile: $0.path) }
            return WhitelistedApp(bundleID: bundleID, name: name, icon: icon)
        }
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.application]
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Add"
        panel.message = "Choose an app to allow microphone access"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier else { return }
        var ids = UserDefaults.standard.stringArray(forKey: "whitelistedBundleIDs") ?? []
        guard !ids.contains(bundleID) else { return }
        ids.append(bundleID)
        UserDefaults.standard.set(ids, forKey: "whitelistedBundleIDs")
        whitelistedApps = loadWhitelistedApps()
    }

    private func removeApp(_ bundleID: String) {
        var ids = UserDefaults.standard.stringArray(forKey: "whitelistedBundleIDs") ?? []
        ids.removeAll { $0 == bundleID }
        UserDefaults.standard.set(ids, forKey: "whitelistedBundleIDs")
        whitelistedApps = loadWhitelistedApps()
    }

    // MARK: - Launch at Login

    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Launch at login error: \(error)")
            }
        }
    }
}

// MARK: - Whitelist App Model

struct WhitelistedApp: Identifiable {
    let bundleID: String
    let name: String
    let icon: NSImage?
    var id: String { bundleID }
}

// MARK: - Mic Status Badge

struct MicStatusBadge: View {
    @ObservedObject private var mic = MicrophoneManager.shared

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(mic.isMuted ? Color.red : Color.green)
                .frame(width: 8, height: 8)
            Text(mic.isMuted ? "Muted" : "Active")
                .font(.caption.bold())
                .foregroundStyle(mic.isMuted ? .red : .green)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(mic.isMuted ? Color.red.opacity(0.12) : Color.green.opacity(0.12))
        )
    }
}

// MARK: - Hotkey Row

struct HotkeyRow: View {
    @State private var isRecording = false
    @State private var displayString: String = ""

    var body: some View {
        HStack {
            Text("Toggle Mute")
            Spacer()
            Button(action: { isRecording.toggle() }) {
                Text(isRecording ? "Press shortcut…" : (displayString.isEmpty ? "⌥⇧M" : displayString))
                    .frame(minWidth: 100)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isRecording ? Color.accentColor : Color.secondary.opacity(0.4))
                    )
            }
            .buttonStyle(.plain)
            .background(KeyEventCapture(isActive: $isRecording, onCapture: { keyCode, modifiers, label in
                displayString = label
                HotkeyManager.shared.register(keyCode: keyCode, modifiers: modifiers)
                isRecording = false
            }))
        }
        .onAppear { displayString = loadHotkeyLabel() }
    }

    private func loadHotkeyLabel() -> String {
        let keyCode = UserDefaults.standard.integer(forKey: "hotkeyKeyCode")
        let modifiers = UserDefaults.standard.integer(forKey: "hotkeyModifiers")
        guard keyCode != 0 else { return "⌥⇧M" }
        return HotkeyFormatter.label(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers))
    }
}

// MARK: - Key Event Capture (NSViewRepresentable)

struct KeyEventCapture: NSViewRepresentable {
    @Binding var isActive: Bool
    var onCapture: (UInt32, UInt32, String) -> Void

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.onCapture = onCapture
        return view
    }

    func updateNSView(_ view: KeyCaptureView, context: Context) {
        view.isCapturing = isActive
        if isActive { view.window?.makeFirstResponder(view) }
    }
}

final class KeyCaptureView: NSView {
    var isCapturing = false
    var onCapture: ((UInt32, UInt32, String) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isCapturing else { super.keyDown(with: event); return }
        let keyCode = UInt32(event.keyCode)
        let modifiers = carbonModifiers(from: event.modifierFlags)
        let label = HotkeyFormatter.label(keyCode: keyCode, modifiers: modifiers)
        onCapture?(keyCode, modifiers, label)
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.shift)   { mods |= UInt32(shiftKey) }
        if flags.contains(.option)  { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        return mods
    }
}

// MARK: - Hotkey Formatter

struct HotkeyFormatter {
    static func label(keyCode: UInt32, modifiers: UInt32) -> String {
        var result = ""
        if modifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if modifiers & UInt32(optionKey)  != 0 { result += "⌥" }
        if modifiers & UInt32(shiftKey)   != 0 { result += "⇧" }
        if modifiers & UInt32(cmdKey)     != 0 { result += "⌘" }
        result += keyLabel(for: keyCode)
        return result
    }

    private static func keyLabel(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_Space:  return "Space"
        case kVK_F1:  return "F1";  case kVK_F2:  return "F2"
        case kVK_F3:  return "F3";  case kVK_F4:  return "F4"
        case kVK_F5:  return "F5";  case kVK_F6:  return "F6"
        case kVK_F7:  return "F7";  case kVK_F8:  return "F8"
        case kVK_F9:  return "F9";  case kVK_F10: return "F10"
        case kVK_F11: return "F11"; case kVK_F12: return "F12"
        default:      return "(\(keyCode))"
        }
    }
}

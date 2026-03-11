import AppKit
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        requestMicrophonePermissionIfNeeded()
        statusBarController = StatusBarController(micManager: MicrophoneManager.shared)
        HotkeyManager.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if UserDefaults.standard.bool(forKey: "unmuteOnQuit") {
            MicrophoneManager.shared.setMuted(false)
        }
        HotkeyManager.shared.stop()
    }

    // MARK: - Microphone Permission

    static func microphonePermissionGranted() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    private func requestMicrophonePermissionIfNeeded() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    DispatchQueue.main.async {
                        MicrophoneManager.shared.refreshState()
                    }
                }
            }
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }
}

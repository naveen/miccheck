import AppKit
import CoreAudio
import Foundation

extension Notification.Name {
    static let microphoneStateChanged = Notification.Name("com.miccheck.micStateChanged")
}

final class MicrophoneManager: ObservableObject {
    static let shared = MicrophoneManager()

    @Published private(set) var isMuted: Bool = false

    /// The mute state the user explicitly set — enforced against external changes
    /// unless a whitelisted app is running.
    private(set) var desiredMuteState: Bool = false

    /// True while we've temporarily unmuted to accommodate a whitelisted app's recording session.
    private var isTemporarilyUnmuted = false

    private init() {
        let initial = fetchMuteState()
        isMuted = initial
        desiredMuteState = initial
        installMutePropertyListener()
        installAudioSessionListener()
    }

    // MARK: - Public API

    func toggle() {
        setMuted(!isMuted)
    }

    func setMuted(_ mute: Bool) {
        DispatchQueue.main.async { [self] in
            desiredMuteState = mute
            isTemporarilyUnmuted = false
            applyMute(mute, userInitiated: true)
        }
    }

    /// Re-read mute state from hardware (call after permission is granted).
    func refreshState() {
        let newState = fetchMuteState()
        isMuted = newState
        desiredMuteState = newState
        NotificationCenter.default.post(name: .microphoneStateChanged, object: nil)
    }

    // MARK: - Private

    /// Apply mute state to hardware. Must be called from the main thread.
    private func applyMute(_ mute: Bool, userInitiated: Bool) {
        guard let deviceID = defaultInputDevice() else { return }
        var value = UInt32(mute ? 1 : 0)
        var address = mutePropertyAddress()
        let status = AudioObjectSetPropertyData(
            deviceID, &address, 0, nil,
            UInt32(MemoryLayout<UInt32>.size), &value
        )
        guard status == noErr else { return }
        isMuted = mute
        NotificationCenter.default.post(name: .microphoneStateChanged, object: nil)
        if userInitiated {
            if UserDefaults.standard.bool(forKey: "playSound") {
                SoundPlayer.play(mute ? .muted : .unmuted)
            }
            if UserDefaults.standard.bool(forKey: "showNotifications") {
                NotificationManager.send(muted: mute)
            }
        }
    }

    private func fetchMuteState() -> Bool {
        guard let deviceID = defaultInputDevice() else { return false }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = mutePropertyAddress()
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
        return value != 0
    }

    private func fetchIsRunningSomewhere() -> Bool {
        guard let deviceID = defaultInputDevice() else { return false }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
        return value != 0
    }

    private func defaultInputDevice() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        )
        return status == noErr ? deviceID : nil
    }

    private func mutePropertyAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    // MARK: - Property Listeners

    /// Watches the mute property itself — handles apps that explicitly toggle the mute flag.
    private func installMutePropertyListener() {
        guard let deviceID = defaultInputDevice() else { return }
        var address = mutePropertyAddress()

        AudioObjectAddPropertyListenerBlock(deviceID, &address, DispatchQueue.main) { [weak self] _, _ in
            guard let self else { return }
            let newState = self.fetchMuteState()

            if newState == self.desiredMuteState {
                // Matches desired — could be our own set or whitelisted app restoring state
                if self.isTemporarilyUnmuted && newState == true {
                    self.isTemporarilyUnmuted = false
                }
                if newState != self.isMuted {
                    self.isMuted = newState
                    NotificationCenter.default.post(name: .microphoneStateChanged, object: nil)
                }
                return
            }

            // External change diverges from desired
            if self.isWhitelistedAppRunning() {
                // Whitelisted app explicitly changed the mute property — allow it
                self.isMuted = newState
                NotificationCenter.default.post(name: .microphoneStateChanged, object: nil)
            } else {
                // Non-whitelisted change — enforce desired state
                self.applyMute(self.desiredMuteState, userInitiated: false)
            }
        }
    }

    /// Watches for audio sessions starting/stopping — handles apps that don't touch the mute
    /// property but simply open an input stream (e.g. SuperWhisper).
    private func installAudioSessionListener() {
        guard let deviceID = defaultInputDevice() else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectAddPropertyListenerBlock(deviceID, &address, DispatchQueue.main) { [weak self] _, _ in
            guard let self else { return }
            // Only relevant when we want the mic muted
            guard self.desiredMuteState else { return }

            let isRunning = self.fetchIsRunningSomewhere()

            if isRunning && !self.isTemporarilyUnmuted && self.isWhitelistedAppRunning() {
                // A whitelisted app just started an audio session — unmute for it
                self.isTemporarilyUnmuted = true
                self.applyMute(false, userInitiated: false)
            } else if !isRunning && self.isTemporarilyUnmuted {
                // Audio session ended — restore desired muted state
                self.isTemporarilyUnmuted = false
                self.applyMute(self.desiredMuteState, userInitiated: false)
            }
        }
    }

    private func isWhitelistedAppRunning() -> Bool {
        let whitelist = UserDefaults.standard.stringArray(forKey: "whitelistedBundleIDs") ?? []
        guard !whitelist.isEmpty else { return false }
        return NSWorkspace.shared.runningApplications.contains {
            guard let bid = $0.bundleIdentifier else { return false }
            return whitelist.contains(bid)
        }
    }
}

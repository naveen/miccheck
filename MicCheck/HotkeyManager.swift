import Carbon
import Foundation

// Global C callback required by Carbon's event handler API
private func hotkeyEventHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }

    var hotKeyID = EventHotKeyID()
    GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    if hotKeyID.id == HotkeyManager.toggleHotkeyID {
        HotkeyManager.shared.hotkeyFired()
    }
    return noErr
}

final class HotkeyManager {
    static let shared = HotkeyManager()
    static let toggleHotkeyID: UInt32 = 1
    static let hotkeySignature: OSType = 0x4D434B48 // "MCKH"

    // Default: ⌥⇧M
    static let defaultKeyCode: UInt32 = UInt32(kVK_ANSI_M)
    static let defaultModifiers: UInt32 = UInt32(optionKey | shiftKey)

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private init() {}

    func start() {
        let keyCode = UInt32(UserDefaults.standard.integer(forKey: "hotkeyKeyCode").nonzero(or: Int(HotkeyManager.defaultKeyCode)))
        let modifiers = UInt32(UserDefaults.standard.integer(forKey: "hotkeyModifiers").nonzero(or: Int(HotkeyManager.defaultModifiers)))
        register(keyCode: keyCode, modifiers: modifiers)
    }

    func stop() {
        unregister()
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
            eventHandlerRef = nil
        }
    }

    func register(keyCode: UInt32, modifiers: UInt32) {
        unregister()

        if eventHandlerRef == nil {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            InstallEventHandler(
                GetApplicationEventTarget(),
                hotkeyEventHandler,
                1, &eventType,
                nil, &eventHandlerRef
            )
        }

        var hotKeyID = EventHotKeyID(signature: HotkeyManager.hotkeySignature, id: HotkeyManager.toggleHotkeyID)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)

        UserDefaults.standard.set(Int(keyCode), forKey: "hotkeyKeyCode")
        UserDefaults.standard.set(Int(modifiers), forKey: "hotkeyModifiers")
    }

    private func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    func hotkeyFired() {
        MicrophoneManager.shared.toggle()
    }
}

private extension Int {
    func nonzero(or fallback: Int) -> Int {
        self == 0 ? fallback : self
    }
}

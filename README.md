# MicCheck

A lightweight macOS menu bar app that keeps your microphone muted unless you say otherwise.

MicCheck sits quietly in your menu bar and enforces your mic state — blocking any app from unmuting you without your permission. You can whitelist specific apps (like SuperWhisper) so they can record when needed, then MicCheck automatically re-mutes when they're done.

---

## Features

- **Always-on mute enforcement** — MicCheck watches the system microphone at the CoreAudio level. If any non-whitelisted app tries to unmute your mic, MicCheck immediately reverts it.
- **Whitelist** — Trusted apps (e.g. SuperWhisper, dictation tools) are allowed to temporarily unmute and record. When they release the mic, MicCheck re-mutes automatically — no action needed from you.
- **Menu bar indicator** — Shows **ON AIR** in red when the mic is live, **OFF AIR** in grey when muted. One click on the menu bar item brings up the menu.
- **Global hotkey** — Toggle mute from anywhere with the default shortcut ⌥⇧M. Fully customizable in Preferences.
- **Sound feedback** — Plays a sound on mute/unmute so you always know what state you're in.
- **Notifications** — Optional banner notifications when the mic state changes.
- **Launch at Login** — Start MicCheck automatically when you log in.
- **Unmute on Quit** — Optionally restore the mic to unmuted when MicCheck exits, so you're not left silently muted.

---

## How It Works

### Mute Enforcement

macOS exposes a hardware-level mute flag on every audio input device via CoreAudio (`kAudioDevicePropertyMute`). MicCheck sets this flag and installs a property listener to watch for external changes. If anything changes the flag away from your desired state, MicCheck reverts it within milliseconds.

Most recording apps (SuperWhisper, Whisper transcription tools, etc.) don't touch the mute flag — they just open an audio session and expect audio to flow. MicCheck handles this too: it also listens to `kAudioDevicePropertyDeviceIsRunningSomewhere`, which fires the moment any app starts or stops an active audio session on the input device.

### Whitelist Flow

When you add an app to the whitelist in Preferences:

1. The whitelisted app starts recording (opens an audio session)
2. MicCheck detects the session via `kAudioDevicePropertyDeviceIsRunningSomewhere`, confirms the app is in the whitelist, and temporarily unmutes
3. The app records normally
4. The app finishes and releases the mic
5. `kAudioDevicePropertyDeviceIsRunningSomewhere` fires again as the session closes — MicCheck re-mutes back to your previous state automatically

Your desired mute state is never changed by whitelist activity. If you were muted before SuperWhisper recorded, you'll be muted again after.

### Note on Conflicting Apps

MicCheck cannot coexist with other mic manager apps that also enforce mic state via CoreAudio property listeners. Running two such apps simultaneously causes them to fight each other — each one reverting the other's changes. Quit any other mic manager before using MicCheck.

---

## Download

[Download MicCheck v1.0.0](https://github.com/naveen/miccheck/releases/latest)

---

## Requirements

- macOS 13.0 (Ventura) or later
- Microphone permission (prompted on first launch)

---

## Building from Source

```bash
git clone <repo>
cd miccheck
xcodebuild -project MicCheck.xcodeproj -scheme MicCheck -configuration Release build CODE_SIGN_IDENTITY="-" CONFIGURATION_BUILD_DIR=./build/Release
```

The built app will be at `./build/Release/MicCheck.app`. Move it to `/Applications` or open it directly:

```bash
open ./build/Release/MicCheck.app
```

### Gatekeeper Warning

Because MicCheck is not notarized through Apple's developer program, macOS will block it on first launch. To open it anyway:

- **Right-click → Open → Open** in Finder, or
- Strip the quarantine attribute from the terminal:

```bash
xattr -d com.apple.quarantine /Applications/MicCheck.app
```

---

## Architecture

| File | Role |
|---|---|
| `AppMain.swift` | SwiftUI `@main` entry point |
| `AppDelegate.swift` | App lifecycle, microphone TCC permission request |
| `StatusBarController.swift` | `NSStatusItem` menu bar item, ON AIR / OFF AIR label |
| `MicrophoneManager.swift` | CoreAudio mute enforcement, whitelist logic, property listeners |
| `HotkeyManager.swift` | Global hotkey via Carbon `RegisterEventHotKey` |
| `PreferencesView.swift` | SwiftUI preferences form |
| `PreferencesWindowController.swift` | `NSWindowController` hosting the preferences view |
| `SoundPlayer.swift` | Mute/unmute sound feedback |
| `NotificationManager.swift` | `UNUserNotificationCenter` banners |

---

## Preferences

Open Preferences from the menu bar menu or with **⌘,**.

| Setting | Description |
|---|---|
| Launch at Login | Start MicCheck automatically at login (uses `SMAppService`) |
| Unmute on Quit | Restore mic to unmuted when MicCheck exits |
| Play sound | Audio feedback on toggle |
| Show notification | Banner notification on toggle |
| Keyboard Shortcut | Click to record a new global hotkey |
| Allowed Apps | Apps permitted to temporarily unmute the mic |

---

## License

MIT

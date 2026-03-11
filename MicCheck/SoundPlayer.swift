import AppKit

enum MicSound {
    case muted
    case unmuted
}

struct SoundPlayer {
    static func play(_ sound: MicSound) {
        switch sound {
        case .muted:
            NSSound(named: "Funk")?.play()
        case .unmuted:
            NSSound(named: "Pop")?.play()
        }
    }
}

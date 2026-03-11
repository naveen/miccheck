import UserNotifications

struct NotificationManager {
    static func send(muted: Bool) {
        let content = UNMutableNotificationContent()
        content.title = "MicCheck"
        content.body = muted ? "Microphone muted" : "Microphone unmuted"
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }
}

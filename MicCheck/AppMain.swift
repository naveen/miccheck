import SwiftUI

@main
struct MicCheckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar only app — all UI lives in StatusBarController + PreferencesWindowController.
        // A Settings scene is required to satisfy the App protocol but is intentionally empty.
        Settings { EmptyView() }
    }
}

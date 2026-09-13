import SwiftUI

@main
struct LoadyApp: App {

    // AppKit, because NSStatusItem has no SwiftUI equivalent.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // A Scene is required; this app has no window at launch. Preferences
        // is a window we own — see PreferencesWindowController.
        Settings { EmptyView() }
    }
}

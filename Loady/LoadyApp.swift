import SwiftUI

@main
struct LoadyApp: App {

    // Bridges SwiftUI's App lifecycle to an old-style AppKit delegate.
    // We need AppKit because NSStatusItem — the menu bar — has no SwiftUI
    // equivalent capable of drawing a live graph. See ADR: SwiftUI everywhere
    // the user clicks; AppKit anywhere that redraws on a timer in the menu bar.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Every SwiftUI App must declare at least one Scene, and this app has
        // no window at launch. `Settings` is the conventional placeholder: it
        // contributes nothing visible on its own.
        //
        // Preferences deliberately does NOT live here. The Settings scene can
        // only be opened by `SettingsLink` or the private `showSettingsWindow:`
        // selector, and the selector no longer works — which would leave the
        // right-click menu with no way in. See `PreferencesWindowController`.
        Settings {
            EmptyView()
        }
    }
}

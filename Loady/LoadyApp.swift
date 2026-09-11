import SwiftUI

@main
struct LoadyApp: App {

    // Bridges SwiftUI's App lifecycle to an old-style AppKit delegate.
    // We need AppKit because NSStatusItem — the menu bar — has no SwiftUI
    // equivalent capable of drawing a live graph. See ADR: SwiftUI everywhere
    // the user clicks; AppKit anywhere that redraws on a timer in the menu bar.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Every SwiftUI App must declare at least one Scene, but this app has
        // no window at launch. `Settings` contributes the ⌘, window and nothing
        // else — it stays closed until asked for. That makes it the
        // conventional choice for menu bar apps, and we'll fill it in later.
        Settings {
            EmptyView()
        }
    }
}

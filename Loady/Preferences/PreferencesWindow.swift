import AppKit
import SwiftUI

/// Hosts `PreferencesView` in a window this app owns, rather than in SwiftUI's
/// `Settings` scene.
///
/// That scene opens only via `SettingsLink` or the private
/// `showSettingsWindow:` selector. macOS 26 refuses the selector, and
/// `SettingsLink` is a View that cannot attach to an `NSMenuItem` — which
/// would leave right-click → Preferences with no way in.
@MainActor
final class PreferencesWindowController {

    static let shared = PreferencesWindowController()
    private var window: NSWindow?

    private init() {}

    func show() {
        // An LSUIElement app is never active; without this the window opens
        // behind whatever the user was doing.
        NSApp.activate(ignoringOtherApps: true)

        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: PreferencesView.width, height: 100),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Loady Preferences"
        window.contentViewController = NSHostingController(rootView: PreferencesView())
        // ARC owns it, and it is reused across openings rather than rebuilt.
        window.isReleasedWhenClosed = false
        // The hosting controller sizes the window from the content, and each
        // tab reports a different height — so centre after it has done so.
        window.center()

        self.window = window
        window.makeKeyAndOrderFront(nil)
    }
}

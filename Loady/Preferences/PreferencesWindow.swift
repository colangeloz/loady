import AppKit
import SwiftUI

/// Not SwiftUI's `Settings` scene: that opens only via `SettingsLink` (a View,
/// so unusable from an NSMenuItem) or the private `showSettingsWindow:`
/// selector, which macOS 26 refuses.
@MainActor
final class PreferencesWindowController {

    static let shared = PreferencesWindowController()
    private var window: NSWindow?

    private init() {}

    func show() {
        // An LSUIElement app is never active; the window would open behind.
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
        let hosting = NSHostingController(rootView: PreferencesView())
        // Without this the window is sized once, at first layout.
        hosting.sizingOptions = [.preferredContentSize]
        window.contentViewController = hosting
        window.isReleasedWhenClosed = false
        window.center()

        self.window = window
        window.makeKeyAndOrderFront(nil)
    }
}

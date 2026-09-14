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
        // NOT `sizingOptions = [.preferredContentSize]`. That makes the window
        // track the content, but the resize makes NSHostingView invalidate,
        // which asks for another resize — an unbounded loop that AppKit turns
        // into an uncaught NSGenericException on the first tab switch.
        // The view reports its height instead, and this sets it once.
        let hosting = NSHostingController(rootView: PreferencesView { [weak window] contentHeight in
            guard let window else { return }
            guard abs(window.contentLayoutRect.height - contentHeight) > 0.5 else { return }
            let top = window.frame.maxY
            window.setContentSize(NSSize(width: PreferencesView.width, height: contentHeight))
            // Keep the title bar where it is; a centred resize makes the window
            // appear to jump when you switch tabs.
            window.setFrameOrigin(NSPoint(x: window.frame.origin.x,
                                          y: top - window.frame.height))
        })
        window.contentViewController = hosting
        window.isReleasedWhenClosed = false
        window.center()

        self.window = window
        window.makeKeyAndOrderFront(nil)
    }
}

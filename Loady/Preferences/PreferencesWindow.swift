import AppKit
import SwiftUI

/// Not SwiftUI's `Settings` scene: that opens only via `SettingsLink` (a View,
/// so unusable from an NSMenuItem) or the private `showSettingsWindow:`
/// selector, which macOS 26 refuses.
@MainActor
final class PreferencesWindowController {

    static let shared = PreferencesWindowController()
    private var window: NSWindow?

    var dismissPopup: (() -> Void)?

    private var centreOnNextShow = true

    private init() {}

    func show() {
        dismissPopup?()

        // An LSUIElement app is never active; the window would open behind.
        NSApp.activate(ignoringOtherApps: true)
        centreOnNextShow = true

        if let window {
            centre(window)
            centreOnNextShow = false
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
        let hosting = NSHostingController(rootView: PreferencesView { [weak self, weak window] contentHeight in
            guard let window else { return }
            guard abs(window.contentLayoutRect.height - contentHeight) > 0.5 else { return }
            let top = window.frame.maxY
            window.setContentSize(NSSize(width: PreferencesView.width, height: contentHeight))

            if self?.centreOnNextShow == true {
                self?.centre(window)
                self?.centreOnNextShow = false
            } else {
                window.setFrameOrigin(NSPoint(x: window.frame.origin.x,
                                              y: top - window.frame.height))
            }
        })
        window.contentViewController = hosting
        window.isReleasedWhenClosed = false

        self.window = window
        centre(window)
        window.makeKeyAndOrderFront(nil)
    }

    /// `NSWindow.center()` puts a window in the upper third, not the middle.
    private func centre(_ window: NSWindow) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) }
            ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let area = screen.visibleFrame
        window.setFrameOrigin(NSPoint(x: area.midX - window.frame.width / 2,
                                      y: area.midY - window.frame.height / 2))
    }
}

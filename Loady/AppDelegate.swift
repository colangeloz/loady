import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    // Held for the app's lifetime. If this were a local variable it would be
    // deallocated immediately and the menu bar item would vanish.
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = StatusItemController()
    }

    // The app has no windows, so there is no "last window closed" moment.
    // Without this, closing Settings would quit the whole app.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

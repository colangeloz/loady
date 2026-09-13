import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    // Held for the app's lifetime. If this were a local variable it would be
    // deallocated immediately and the menu bar item would vanish.
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Xcode hosts SwiftUI previews by launching the app, so `@main` runs
        // and every canvas refresh would add another menu bar item.
        guard !ProcessInfo.processInfo.isRunningInXcodePreview else { return }

        // Same reasoning, different cause: launching the installed app while
        // it is already running would add a second, identical menu bar item.
        if SingleInstance.yieldToExistingInstance() {
            NSApp.terminate(nil)
            return
        }

        statusItem = StatusItemController()

        // Only if the user asked for it; see UpdateChecker.
        Task { await UpdateChecker.shared.checkIfEnabled() }
    }

    // The app has no windows, so there is no "last window closed" moment.
    // Without this, closing Settings would quit the whole app.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

extension ProcessInfo {
    var isRunningInXcodePreview: Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

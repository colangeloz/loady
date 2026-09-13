import AppKit

/// Stops a second copy of the *same* bundle from running.
///
/// Matched on bundle path, not bundle identifier. A Debug build shares its
/// identifier with the copy in /Applications, so an identifier check would
/// refuse to launch from Xcode whenever the released app is running.
enum SingleInstance {

    static func existing() -> NSRunningApplication? {
        guard let identifier = Bundle.main.bundleIdentifier else { return nil }
        let mine = Bundle.main.bundleURL.standardizedFileURL
        let me = ProcessInfo.processInfo.processIdentifier

        return NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .first { other in
                other.processIdentifier != me
                    && other.bundleURL?.standardizedFileURL == mine
            }
    }

    /// Hands over to the copy already running and reports whether it did. It
    /// is asked to show itself, because an LSUIElement app has no Dock icon to
    /// bounce and launching one that appears to do nothing reads as broken.
    static func yieldToExistingInstance() -> Bool {
        guard let other = existing() else { return false }
        other.activate()
        return true
    }
}

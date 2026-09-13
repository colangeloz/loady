import AppKit

/// Stops a second copy of the same bundle from running. Matched on bundle
/// path, not identifier — a Debug build shares its identifier with the copy in
/// /Applications, so an identifier check would block running from Xcode.
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

    /// Activates the running copy, since an LSUIElement app has no Dock icon
    /// to bounce and one that appears to do nothing reads as broken.
    static func yieldToExistingInstance() -> Bool {
        guard let other = existing() else { return false }
        other.activate()
        return true
    }
}

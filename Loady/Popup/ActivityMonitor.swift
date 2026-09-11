import AppKit

/// Launching Apple's Activity Monitor.
///
/// Resolved by bundle identifier rather than a hardcoded path: Apple has moved
/// the Utilities folder before, and a user could have it open from elsewhere.
enum ActivityMonitor {

    private static let bundleID = "com.apple.ActivityMonitor"

    static let url: URL? = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)

    static var icon: NSImage? {
        url.map { NSWorkspace.shared.icon(forFile: $0.path) }
    }

    static func open() {
        guard let url else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}

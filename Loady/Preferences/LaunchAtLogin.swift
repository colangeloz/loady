import Foundation
import ServiceManagement

/// Whether macOS starts Loady when you log in.
///
/// `SMAppService.status` is the source of truth, never a stored flag: macOS
/// ties the registration to the bundle's location and signature, and the user
/// can revoke it in System Settings without telling the app.
@MainActor
@Observable
final class LaunchAtLogin {

    static let shared = LaunchAtLogin()

    private let service = SMAppService.mainApp

    /// Set when registration fails, so the toggle can explain itself rather
    /// than silently snapping back.
    private(set) var failure: String?

    private(set) var isEnabled: Bool = false

    /// True when macOS has the login item but the user has switched it off in
    /// System Settings. The app cannot override that — only point at it.
    private(set) var needsApprovalInSystemSettings = false

    private init() {
        refresh()
    }

    private var isInApplicationsFolder: Bool {
        Bundle.main.bundleURL.deletingLastPathComponent().path.hasSuffix("/Applications")
    }

    func refresh() {
        let status = service.status
        isEnabled = status == .enabled
        needsApprovalInSystemSettings = status == .requiresApproval
    }

    func set(_ enabled: Bool) {
        failure = nil
        do {
            if enabled {
                // Registering when already registered throws, which is not an
                // error worth surfacing.
                if service.status != .enabled { try service.register() }
            } else {
                try service.unregister()
            }
        } catch {
            // SMAppService reports "Operation not permitted" whatever the
            // cause, and the usual cause is not a permission — it is the app
            // running from outside /Applications.
            failure = isInApplicationsFolder
                ? error.localizedDescription
                : "Move Loady to your Applications folder first."
        }
        refresh()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

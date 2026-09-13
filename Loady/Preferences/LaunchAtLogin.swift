import Foundation
import ServiceManagement

/// `SMAppService.status` is the source of truth, never a stored flag — the
/// user can revoke this in System Settings without telling the app.
@MainActor
@Observable
final class LaunchAtLogin {

    static let shared = LaunchAtLogin()

    private let service = SMAppService.mainApp

    private(set) var failure: String?

    private(set) var isEnabled: Bool = false

    /// Registered, but switched off in System Settings. Cannot be overridden.
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
                if service.status != .enabled { try service.register() }
            } else {
                try service.unregister()
            }
        } catch {
            // SMAppService says "Operation not permitted" whatever the cause.
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

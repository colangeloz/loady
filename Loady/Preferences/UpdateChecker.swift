import Foundation
import Sparkle

/// In-app updates, via Sparkle.
///
/// **The only code in Loady that touches the network, and it is off until you
/// turn it on.** `SUEnableAutomaticChecks` is `NO` in Info.plist, which both
/// disables scheduled checks and suppresses Sparkle's second-launch prompt.
@MainActor
@Observable
final class UpdateChecker {

    static let shared = UpdateChecker()

    private let controller: SPUStandardUpdaterController
    private let observer = AutomaticChecksObserver()

    private var updater: SPUUpdater { controller.updater }

    /// Mirrors `updater.canCheckForUpdates`, which is KVO rather than
    /// `@Observable` and so would not invalidate a SwiftUI view on its own.
    private(set) var canCheck = true

    private init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: GentleReminders.shared
        )
        // Never install anything without asking.
        updater.automaticallyDownloadsUpdates = false
        observer.start(updater: updater) { [weak self] in self?.canCheck = $0 }
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Bound straight to Sparkle rather than mirrored into our own defaults:
    /// two stores for one setting drift, and Sparkle needs its copy anyway.
    var checksAutomatically: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }

    /// User-initiated: always shows UI, including "you're up to date".
    func check() {
        updater.checkForUpdates()
    }
}

/// Bridges the updater's KVO property into `@Observable`.
private final class AutomaticChecksObserver: NSObject {
    private var token: NSKeyValueObservation?

    @MainActor
    func start(updater: SPUUpdater, onChange: @escaping @MainActor (Bool) -> Void) {
        onChange(updater.canCheckForUpdates)
        token = updater.observe(\.canCheckForUpdates, options: [.new]) { updater, _ in
            let value = updater.canCheckForUpdates
            Task { @MainActor in onChange(value) }
        }
    }
}

/// Without this, a scheduled update alert is effectively invisible.
///
/// Sparkle will not let a scheduled alert steal focus, so it appears *behind*
/// other windows — and an LSUIElement app has no Dock icon and no window of
/// its own, so nothing tells the user an update exists.
@MainActor
final class GentleReminders: NSObject, SPUStandardUserDriverDelegate {

    static let shared = GentleReminders()

    /// Set while an update is waiting and the alert is not in front, so the
    /// status item can say so.
    private(set) var updateIsWaiting = false

    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        // A user-initiated check is already in front of them; only a scheduled
        // one needs the menu bar to carry the news.
        updateIsWaiting = !state.userInitiated
    }

    func standardUserDriverWillFinishUpdateSession() {
        updateIsWaiting = false
    }
}

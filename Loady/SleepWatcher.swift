import AppKit

/// Stops work while the Mac is asleep.
///
/// Sampling through sleep is the behaviour that gets monitors uninstalled: on
/// battery it is pure waste, since nobody is looking at a menu bar on a closed
/// laptop. It also fixes a correctness problem — several readers report a delta
/// since the previous sample, so the first reading after a long sleep would
/// otherwise describe hours rather than a second.
///
/// `NSWorkspace`'s notifications, not `@Observable` state: these are posted by
/// the system on the main thread, and the app's whole response is to start or
/// stop work.
@MainActor
final class SleepWatcher {

    private var observers: [NSObjectProtocol] = []

    /// - Parameters:
    ///   - onSleep: called just before the Mac sleeps. macOS allows only a
    ///     short window here, so this must return quickly.
    ///   - onWake: called after waking.
    init(onSleep: @escaping @MainActor () -> Void, onWake: @escaping @MainActor () -> Void) {
        let center = NSWorkspace.shared.notificationCenter

        observers = [
            center.addObserver(forName: NSWorkspace.willSleepNotification,
                               object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { onSleep() }
            },
            center.addObserver(forName: NSWorkspace.didWakeNotification,
                               object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { onWake() }
            },
        ]
    }

    /// Never called in practice — the watcher lives as long as the app — but
    /// leaving observers registered against a dead object is how you get a
    /// crash on the next notification.
    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach(center.removeObserver)
        observers.removeAll()
    }
}

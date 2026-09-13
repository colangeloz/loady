import AppKit

/// Stops sampling while the Mac is asleep. Also a correctness fix: readers
/// report a delta since the last sample, so the first read after a long sleep
/// would otherwise cover hours.
@MainActor
final class SleepWatcher {

    private var observers: [NSObjectProtocol] = []

    /// `onSleep` runs in the short window macOS allows before sleeping, so it
    /// must return quickly.
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

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach(center.removeObserver)
        observers.removeAll()
    }
}

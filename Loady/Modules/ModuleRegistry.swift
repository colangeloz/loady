import SwiftUI
import SystemMetrics

/// Every module the app knows about, and which of them are switched on.
///
/// Adding a seventh module should be a one-line change to `all` plus the
/// module's own files. If it ever needs more than that, the abstraction is
/// wrong and should be fixed before adding anything else.
@MainActor
@Observable
final class ModuleRegistry {

    let all: [any MetricModule]

    init(profile: SystemProfile) {
        all = [
            CPUModule(profile: profile),
            MemoryModule(),
        ]
    }

    var enabled: [any MetricModule] { all.filter(\.isEnabled) }

    /// Starts what's enabled and stops what isn't. Safe to call repeatedly —
    /// modules ignore a second `start()`.
    func sync() {
        for module in all {
            if module.isEnabled { module.start() } else { module.stop() }
        }
    }
}

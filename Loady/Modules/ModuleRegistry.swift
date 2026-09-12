import SwiftUI
import SystemMetrics

/// Every module the app knows about, in the user's chosen order.
///
/// Adding a module is one line in `make` plus the module's own files.
@MainActor
@Observable
final class ModuleRegistry {

    private let byID: [Module: any MetricModule]

    /// Display order, persisted. Drives both the menu bar and the popup.
    var order: [Module] {
        didSet { Preferences.shared.moduleOrder = order }
    }

    init(profile: SystemProfile) {
        let modules: [any MetricModule] = [
            CPUModule(profile: profile),
            MemoryModule(),
            DiskModule(),
        ]
        let lookup = Dictionary(uniqueKeysWithValues: modules.map { ($0.module, $0) })
        byID = lookup
        // Local rather than `byID`: referring to a property here would capture
        // self before `order` is initialised.
        order = Preferences.shared.moduleOrder.filter { lookup[$0] != nil }
    }

    var all: [any MetricModule] { order.compactMap { byID[$0] } }
    var enabled: [any MetricModule] { all.filter(\.isEnabled) }

    /// Moves `module` to `index` in the display order.
    func move(_ module: Module, to index: Int) {
        guard let from = order.firstIndex(of: module) else { return }
        var next = order
        next.remove(at: from)
        next.insert(module, at: min(max(index, 0), next.count))
        order = next
    }

    /// Starts what's enabled and stops what isn't. Safe to call repeatedly.
    func sync() {
        for module in all {
            if module.isEnabled { module.start() } else { module.stop() }
        }
    }
}


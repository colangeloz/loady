import SwiftUI
import SystemMetrics

@MainActor
@Observable
final class MemoryModule: MetricModule {

    let module = Module.memory

    var isEnabled: Bool {
        didSet { Preferences.shared.setEnabled(isEnabled, for: module) }
    }

    private(set) var latest: MemorySample?

    // Memory moves far more slowly than CPU, so a 2-second cadence loses
    // nothing visible and halves this module's share of the wakeups.
    private let sampler = Sampler(interval: .seconds(2)) { MemoryReader() }
    private var task: Task<Void, Never>?

    init() {
        self.isEnabled = Preferences.shared.isEnabled(.memory)
    }

    var presentation: MenuBarPresentation? {
        guard let latest else { return nil }
        return MenuBarPresentation(
            fraction: latest.usedFraction,
            text: "\(Int((latest.usedFraction * 100).rounded()))%"
        )
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            let samples = await sampler.stream()
            await sampler.start()
            for await sample in samples { self.latest = sample }
        }
    }

    func stop() {
        guard let task else { return }   // already stopped; don't spawn work
        task.cancel()
        self.task = nil
        Task { [sampler] in await sampler.stop() }
    }

    func popupSection() -> AnyView { AnyView(MemorySection(module: self)) }
}

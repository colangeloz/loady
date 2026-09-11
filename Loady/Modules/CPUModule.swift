import SwiftUI
import SystemMetrics

@MainActor
@Observable
final class CPUModule: MetricModule {

    let module = Module.cpu
    let profile: SystemProfile

    var isEnabled: Bool {
        didSet { Preferences.shared.setEnabled(isEnabled, for: module) }
    }

    private(set) var latest: CPUSample?
    private(set) var history: [Double] = []
    private let historyLimit = 60

    private let sampler = Sampler(interval: .seconds(1)) { CPUReader() }
    private var task: Task<Void, Never>?

    init(profile: SystemProfile) {
        self.profile = profile
        self.isEnabled = Preferences.shared.isEnabled(.cpu)
    }

    var presentation: MenuBarPresentation? {
        guard let latest else { return nil }
        return MenuBarPresentation(
            fraction: latest.busy,
            text: "\(Int((latest.busy * 100).rounded()))%"
        )
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            let samples = await sampler.stream()
            await sampler.start()
            for await sample in samples { self.ingest(sample) }
        }
    }

    func stop() {
        guard let task else { return }   // already stopped; don't spawn work
        task.cancel()
        self.task = nil
        Task { [sampler] in await sampler.stop() }
    }

    private func ingest(_ sample: CPUSample) {
        latest = sample
        history.append(sample.busy)
        if history.count > historyLimit { history.removeFirst(history.count - historyLimit) }
    }

    var tierLoads: [(tier: CoreTier, load: Double)] {
        guard let latest else { return profile.cpu.tiers.map { ($0, 0) } }
        return profile.cpu.tiers.map { ($0, latest.busy(for: $0)) }
    }

    func popupSection() -> AnyView { AnyView(CPUSection(module: self)) }
}

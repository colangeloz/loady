import SwiftUI
import SystemMetrics

@MainActor
@Observable
final class DiskModule: MetricModule {

    let module = Module.disk

    var isEnabled: Bool {
        didSet { Preferences.shared.setEnabled(isEnabled, for: module) }
    }

    fileprivate(set) var latest: DiskSample?

    // Capacity barely moves; throughput does. 2s is the compromise.
    private let sampler = Sampler(interval: .seconds(2)) { DiskReader() }
    private var task: Task<Void, Never>?

    init() {
        self.isEnabled = Preferences.shared.isEnabled(.disk)
    }

    var presentation: MenuBarPresentation? {
        guard let volume = latest?.primary else { return nil }
        return MenuBarPresentation(
            fraction: volume.usedFraction,
            text: "\(Int((volume.usedFraction * 100).rounded()))%"
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
        guard let task else { return }
        task.cancel()
        self.task = nil
        Task { [sampler] in await sampler.stop() }
    }

    func popupSection() -> AnyView { AnyView(DiskSection(module: self)) }
}

#if DEBUG
extension DiskModule {
    static func preview() -> DiskModule {
        let m = DiskModule()
        m.latest = DiskSample(
            volumes: [DiskVolume(name: "Macintosh HD",
                                 total: 1_995_165_736_960, available: 1_714_700_000_000)],
            readBytesPerSecond: 12_400_000, writeBytesPerSecond: 3_100_000)
        return m
    }
}
#endif

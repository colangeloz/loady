import SwiftUI
import SystemMetrics

@MainActor
@Observable
final class NetworkModule: MetricModule {

    let module = Module.network

    var isEnabled: Bool {
        didSet { Preferences.shared.setEnabled(isEnabled, for: module) }
    }

    fileprivate(set) var latest: NetworkSample?

    private let sampler = Sampler(interval: .seconds(1)) { NetworkReader() }
    private var task: Task<Void, Never>?

    init() {
        self.isEnabled = Preferences.shared.isEnabled(.network)
    }

    var presentation: MenuBarPresentation? {
        guard let sample = latest else { return nil }
        // Download is what people watch; upload is in the popup and tooltip.
        // There is no maximum throughput to divide by, so the fraction is only
        // meaningful relative to the highest rate seen this session.
        let down = sample.downloadBytesPerSecond
        return MenuBarPresentation(
            fraction: min(1, down / 12_500_000),   // ~100 Mbit as a full bar
            text: Format.rateCompact(down)
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

    func popupSection() -> AnyView { AnyView(NetworkSection(module: self)) }
}

#if DEBUG
extension NetworkModule {
    static func preview() -> NetworkModule {
        let m = NetworkModule()
        m.latest = NetworkSample(interfaces: [
            NetworkInterface(name: "en0", bytesIn: 2_910_727_168, bytesOut: 1_434_459_136,
                             bytesInPerSecond: 1_240_000, bytesOutPerSecond: 180_000),
            NetworkInterface(name: "lo0", bytesIn: 23_695, bytesOut: 0, isLoopback: true),
        ])
        return m
    }
}
#endif

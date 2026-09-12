import SwiftUI
import SystemMetrics

@MainActor
@Observable
final class GPUModule: MetricModule {

    let module = Module.gpu

    var isEnabled: Bool {
        didSet { Preferences.shared.setEnabled(isEnabled, for: module) }
    }

    fileprivate(set) var latest: GPUSample?

    // Utilization is averaged over the gap between reads, so the interval is
    // also the measurement window. 1s keeps it comparable to the CPU readout.
    private let sampler = Sampler(interval: .seconds(1)) { GPUReader() }
    private var task: Task<Void, Never>?

    init() {
        self.isEnabled = Preferences.shared.isEnabled(.gpu)
    }

    var presentation: MenuBarPresentation? {
        // The first sample of a device deliberately has no utilization, so the
        // menu bar shows nothing rather than a misleading zero.
        guard let utilization = latest?.primary?.utilization else { return nil }
        return MenuBarPresentation(
            fraction: utilization,
            text: "\(Int((utilization * 100).rounded()))%"
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

    func popupSection() -> AnyView { AnyView(GPUSection(module: self)) }
}

#if DEBUG
extension GPUModule {
    static func preview() -> GPUModule {
        let m = GPUModule()
        m.latest = GPUSample(devices: [
            GPUDevice(id: 1, name: "Apple M5 Pro", vendor: .apple,
                      utilization: 0.37, rendererUtilization: 0.31,
                      tilerUtilization: 0.12, inUseMemory: 1_183_000_000)
        ])
        return m
    }
}
#endif

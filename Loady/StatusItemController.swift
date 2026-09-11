import AppKit
import SystemMetrics

/// Owns the menu bar item and keeps it fed with CPU readings.
@MainActor
final class StatusItemController {

    private let statusItem: NSStatusItem
    private let profile = SystemProfile.current()
    private let reader = CPUReader()
    private var samplingTask: Task<Void, Never>?

    init() {
        // `.variableLength` lets the item size itself to its content. The
        // alternative is a fixed width, which clips as the number grows.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Survives relaunch and remembers where the user dragged the item.
        statusItem.autosaveName = "me.colangelo.loady.statusitem"

        configureButton()
        buildMenu()
        startSampling()
    }

    deinit {
        samplingTask?.cancel()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }

        // A monospaced digit font is essential here. With a proportional font,
        // "11.1%" and "8.8%" are different widths, so the item resizes every
        // second and visibly shoves its menu bar neighbours around.
        button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        button.title = "CPU  --.-%"

        // Read by VoiceOver. Almost nothing in this app category bothers.
        button.setAccessibilityLabel("CPU usage")
    }

    private func buildMenu() {
        // Without a Dock icon and without an app menu, this menu is the ONLY
        // way to quit. Ship an LSUIElement app without it and the user has to
        // reach for Activity Monitor.
        let menu = NSMenu()
        menu.addItem(
            withTitle: "Quit Loady",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        statusItem.menu = menu
    }

    private func startSampling() {
        samplingTask = Task { [weak self] in
            // The first read only establishes a baseline — load is a difference
            // between two instants, so there's nothing to report yet.
            _ = self?.reader.read()

            var deadline = ContinuousClock.now

            while !Task.isCancelled {
                deadline = deadline.advanced(by: .seconds(1))

                // Absolute deadlines, not `sleep(for:)`. A relative sleep adds
                // the work duration to every interval, so a "1 second" sampler
                // drifts measurably slow over an hour.
                //
                // `tolerance` is the important part: it lets the kernel fire
                // this wakeup early to coalesce it with other pending timers.
                // Wakeups, not work, are what costs battery.
                try? await ContinuousClock().sleep(until: deadline, tolerance: .milliseconds(100))

                guard let self, let sample = self.reader.read() else { continue }
                self.update(with: sample)
            }
        }
    }

    private func update(with sample: CPUSample) {
        guard let button = statusItem.button else { return }

        let percent = sample.busy * 100
        button.title = String(format: "CPU %5.1f%%", percent)
        button.setAccessibilityLabel("CPU \(Int(percent.rounded())) percent")
    }
}

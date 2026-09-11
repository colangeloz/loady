import AppKit
import SystemMetrics

/// Owns the menu bar item and keeps it fed with CPU readings.
///
/// `@MainActor` means every method here runs on the main thread, and the
/// compiler enforces it. That's what makes touching `statusItem.button` safe
/// without a single `DispatchQueue.main.async` anywhere in the file.
@MainActor
final class StatusItemController {

    private let statusItem: NSStatusItem
    private let profile = SystemProfile.current()

    /// The reader lives *inside* this actor, on a background executor. It is
    /// created by the closure rather than passed in, because `CPUReader` isn't
    /// `Sendable` and therefore couldn't legally cross the boundary.
    private let sampler = Sampler(interval: .seconds(1)) { CPUReader() }

    private var consumerTask: Task<Void, Never>?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "me.colangelo.loady.statusitem"

        configureButton()
        buildMenu()
        startConsuming()
    }

    deinit {
        consumerTask?.cancel()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }

        // Monospaced digits: with a proportional font "11.1%" and "8.8%" are
        // different widths, so the item resizes every second and visibly
        // shoves its menu bar neighbours around.
        button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        button.title = "CPU  --.-%"
        button.setAccessibilityLabel("CPU usage")
    }

    private func buildMenu() {
        // An LSUIElement app has no Dock icon and no app menu, so this is the
        // only way to quit it. Without it the user needs Activity Monitor.
        let menu = NSMenu()
        menu.addItem(
            withTitle: "Quit Loady",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        statusItem.menu = menu
    }

    private func startConsuming() {
        // `Task { }` inside a @MainActor type inherits MainActor isolation, so
        // the body already runs on the main thread. There is exactly ONE hop
        // across the boundary — `await` on the sampler — and what comes back
        // is a `CPUSample`, a Sendable value type.
        consumerTask = Task { [weak self] in
            guard let self else { return }

            // Subscribe before starting, so no early sample is missed.
            let samples = await sampler.stream()
            await sampler.start()

            for await sample in samples {
                self.update(with: sample)
            }
        }
    }

    private func update(with sample: CPUSample) {
        guard let button = statusItem.button else { return }

        let percent = sample.busy * 100
        button.title = String(format: "CPU %5.1f%%", percent)

        // Per-tier detail for VoiceOver and the tooltip. On an M5 Pro this
        // reads "Super 12%, Performance 6%"; on an Intel Mac, one figure.
        let tiers = profile.cpu.tiers
            .map { "\($0.name) \(Int((sample.busy(for: $0) * 100).rounded()))%" }
            .joined(separator: ", ")

        button.toolTip = tiers
        button.setAccessibilityLabel("CPU \(Int(percent.rounded())) percent. \(tiers)")
    }
}

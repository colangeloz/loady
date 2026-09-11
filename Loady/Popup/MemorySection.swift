import SwiftUI
import SystemMetrics

struct MemorySection: View {
    let module: MemoryModule

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var animation: Animation? {
        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 1.0)
    }

    /// Colour carries meaning here, not decoration.
    private var tint: Color {
        switch module.latest?.pressure {
        case .critical: .red
        case .warning: .orange
        default: .accentColor
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                module: .memory,
                subtitle: module.latest.map { "\(Format.bytes($0.used)) of \(Format.bytes($0.total))" } ?? "—",
                value: Format.percent(module.latest?.usedFraction ?? 0),
                animation: animation
            )

            Bar(fraction: module.latest?.usedFraction ?? 0, tint: tint, animation: animation)

            if let sample = module.latest {
                HStack(spacing: 14) {
                    breakdown("App", sample.app)
                    breakdown("Wired", sample.wired)
                    breakdown("Compressed", sample.compressed)
                }
            }
        }
    }

    private func breakdown(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text(Format.bytes(value))
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
        }
    }
}

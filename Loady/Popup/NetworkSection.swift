import SwiftUI
import SystemMetrics

struct NetworkSection: View {
    let module: NetworkModule

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var animation: Animation? {
        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 1.0)
    }

    private var sample: NetworkSample? { module.latest }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                module: .network,
                subtitle: sample?.primary?.name ?? "—",
                value: sample.map { Format.rateCompact($0.downloadBytesPerSecond) } ?? "—",
                animation: animation
            )

            if let sample {
                // The rates are why anyone looks at this module, so they get the
                // space a bar gets elsewhere. There is no maximum throughput to
                // draw a bar against anyway.
                HStack(spacing: 18) {
                    throughput("arrow.down", sample.downloadBytesPerSecond)
                    throughput("arrow.up", sample.uploadBytesPerSecond)
                    Spacer(minLength: 0)
                    if let primary = sample.primary {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("Since boot")
                                .font(.system(size: 9)).foregroundStyle(.secondary)
                            Text(Format.bytes(Int(primary.bytesIn + primary.bytesOut)))
                                .font(.system(size: 10, weight: .medium)).monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func throughput(_ symbol: String, _ bytesPerSecond: Double) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(Format.rate(bytesPerSecond))
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(animation, value: bytesPerSecond)
        }
    }
}

#if DEBUG
#Preview("Network") {
    NetworkSection(module: .preview())
        .padding(16).frame(width: 268)
}
#endif

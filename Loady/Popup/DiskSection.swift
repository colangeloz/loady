import SwiftUI
import SystemMetrics

struct DiskSection: View {
    let module: DiskModule

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var animation: Animation? {
        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                module: .disk,
                subtitle: module.latest?.primary.map {
                    "\(Format.bytes($0.used)) of \(Format.bytes($0.total))"
                } ?? "—",
                value: Format.percent(module.latest?.primary?.usedFraction ?? 0),
                animation: animation
            )

            Bar(fraction: module.latest?.primary?.usedFraction ?? 0, animation: animation)

            if let sample = module.latest {
                HStack(spacing: 14) {
                    rate("Read", sample.readBytesPerSecond)
                    rate("Write", sample.writeBytesPerSecond)
                    Spacer()
                    if let free = sample.primary?.available {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("Free").font(.system(size: 9)).foregroundStyle(.secondary)
                            Text(Format.bytes(free))
                                .font(.system(size: 10, weight: .medium)).monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    private func rate(_ label: String, _ bytesPerSecond: Double) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
            Text("\(Format.bytes(Int(bytesPerSecond)))/s")
                .font(.system(size: 10, weight: .medium)).monospacedDigit()
        }
    }
}

#if DEBUG
#Preview("Disk") {
    DiskSection(module: .preview())
        .padding(16).frame(width: 268)
}
#endif

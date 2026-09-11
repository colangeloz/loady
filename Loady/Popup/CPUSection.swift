import SwiftUI
import SystemMetrics

struct CPUSection: View {
    let module: CPUModule

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var animation: Animation? {
        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                module: .cpu,
                subtitle: module.profile.cpuBrand,
                value: Format.percent(module.latest?.busy ?? 0),
                animation: animation
            )

            ForEach(module.tierLoads, id: \.tier.name) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(entry.tier.name)
                            .font(.system(size: 11, weight: .medium))
                        Text("\(entry.tier.coreCount) cores")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(Format.percent(entry.load))
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    Bar(fraction: entry.load, animation: animation)
                }
            }
        }
    }
}

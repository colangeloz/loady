import SwiftUI
import SystemMetrics

struct GPUSection: View {
    let module: GPUModule

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var animation: Animation? {
        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 1.0)
    }

    private var device: GPUDevice? { module.latest?.primary }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                module: .gpu,
                subtitle: device?.name ?? "—",
                value: device?.utilization.map(Format.percent) ?? "—",
                animation: animation
            )

            // No bar at all until there is a reading. A zero-length bar would
            // claim the GPU is idle, which is not what "not measured yet" means.
            if let utilization = device?.utilization {
                Bar(fraction: utilization, animation: animation)
            }

            if let device {
                HStack(spacing: 14) {
                    // Apple Silicon splits work between the renderer and the
                    // tiler; discrete GPUs report neither, so both are optional.
                    if let renderer = device.rendererUtilization {
                        stat("Renderer", Format.percent(renderer))
                    }
                    if let tiler = device.tilerUtilization {
                        stat("Tiler", Format.percent(tiler))
                    }
                    if let temperature = device.temperatureCelsius {
                        stat("Temp", "\(Int(temperature.rounded()))°")
                    }
                    Spacer()
                    if let memory = device.inUseMemory {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("Memory").font(.system(size: 9)).foregroundStyle(.secondary)
                            Text(Format.bytes(memory))
                                .font(.system(size: 10, weight: .medium)).monospacedDigit()
                        }
                    }
                }
            }

            // More than one GPU is normal on Intel laptops and with an eGPU.
            if let devices = module.latest?.devices, devices.count > 1 {
                ForEach(devices.filter { $0.id != device?.id }) { other in
                    HStack {
                        Text(other.name).font(.system(size: 10)).foregroundStyle(.secondary)
                        Spacer()
                        Text(other.utilization.map(Format.percent) ?? "—")
                            .font(.system(size: 10, weight: .medium)).monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 10, weight: .medium)).monospacedDigit()
        }
    }
}

#if DEBUG
#Preview("GPU") {
    GPUSection(module: .preview())
        .padding(16).frame(width: 268)
}
#endif

import Foundation
import IOKit

/// GPU utilization and memory from the IORegistry.
///
/// Reads `PerformanceStatistics` on every `IOAccelerator` service. Property
/// reads need no user client, so this works without elevated privileges — and
/// would still work sandboxed, unlike the SMC.
///
/// **Utilization is averaged since the counter was last read, by any process.**
/// A long gap between reads therefore inflates the next value, which is why a
/// device's first sample is reported as `nil` rather than as a number covering
/// an unbounded window. It also means a second monitoring app running
/// alongside this one will skew both: each read resets the other's window.
public final class GPUReader {

    /// Devices already sampled at least once, by registry entry ID. A GPU
    /// appearing later — an eGPU being plugged in — gets the same first-read
    /// treatment as one present at launch.
    private var sampled: Set<UInt64> = []

    /// Recent raw readings per device and statistic, for the rolling mean.
    /// Each series is capped at the smoothing window, and devices that go away
    /// are dropped in `read()`, so neither dimension grows without bound.
    private var history: [UInt64: [String: [Double]]] = [:]

    public init() {}

    public func read() -> GPUSample? {
        var iterator: io_iterator_t = 0
        // Re-enumerated every read rather than cached: eGPUs appear and vanish
        // without restarting the app, and a stale io_object_t would miss it.
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator
        ) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var devices: [GPUDevice] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            if let device = readDevice(service) { devices.append(device) }
        }

        // Forget devices that have gone — an eGPU unplugged, or a discrete GPU
        // powered down. Without this, their history and first-sample flag would
        // outlive them, and a device that came back would silently resume a
        // stale rolling mean rather than starting clean.
        let present = Set(devices.map(\.id))
        sampled.formIntersection(present)
        history = history.filter { present.contains($0.key) }

        return GPUSample(devices: devices)
    }

    private func readDevice(_ service: io_service_t) -> GPUDevice? {
        var id: UInt64 = 0
        guard IORegistryEntryGetRegistryEntryID(service, &id) == KERN_SUCCESS else { return nil }

        let ioClass = Self.string(service, "IOClass") ?? ""
        let vendor = GPUVendor(ioClass: ioClass)

        // `model` lives on the parent device, not the accelerator, and is a
        // C string in a data blob on discrete cards.
        let name = Self.name(service) ?? (ioClass.isEmpty ? "GPU" : ioClass)

        let stats = Self.statistics(service)

        // A device seen for the first time has been accumulating since some
        // unknown earlier read, so its utilization is not attributable to any
        // interval we can name. Report the device, withhold the number.
        let isFirstSample = sampled.insert(id).inserted

        // All three utilization figures come from the same bursty counter, so
        // they get the same treatment. Smoothing only the headline number left
        // it steady beside a renderer and tiler that still flickered to zero,
        // which reads as a bug rather than as a quiet machine.
        func smoothed(_ key: String) -> Double? {
            guard !isFirstSample, let raw = GPUMath.fraction(percent: stats[key]) else { return nil }
            var recent = history[id]?[key] ?? []
            recent.append(raw)
            if recent.count > GPUMath.smoothingWindow { recent.removeFirst() }
            history[id, default: [:]][key] = recent
            return GPUMath.smoothed(recent)
        }

        return GPUDevice(
            id: id,
            name: name,
            vendor: vendor,
            utilization: smoothed("Device Utilization %"),
            rendererUtilization: smoothed("Renderer Utilization %"),
            tilerUtilization: smoothed("Tiler Utilization %"),
            inUseMemory: stats["In use system memory"].map { Int($0) },
            allocatedMemory: stats["Alloc system memory"].map { Int($0) },
            // Published by Intel and AMD drivers only; absent on Apple Silicon.
            temperatureCelsius: stats["Temperature(C)"],
            coreClockMHz: stats["Core Clock(MHz)"]
        )
    }

    // MARK: IORegistry access

    /// Flattens `PerformanceStatistics` into typed numbers **inside** the
    /// reader. The CF dictionary is not `Sendable` and neither is `Any`, so
    /// nothing of that shape may cross out of here.
    private static func statistics(_ service: io_service_t) -> [String: Double] {
        guard let raw = IORegistryEntryCreateCFProperty(
            service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue() as? NSDictionary else { return [:] }

        var out: [String: Double] = [:]
        for case let (key as String, value) in raw {
            if let number = value as? NSNumber { out[key] = number.doubleValue }
        }
        return out
    }

    private static func string(_ service: io_service_t, _ key: String) -> String? {
        guard let raw = IORegistryEntryCreateCFProperty(
            service, key as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue() else { return nil }

        if let s = raw as? String { return s }
        // Discrete drivers store `model` as a NUL-terminated C string in data.
        if let data = raw as? Data {
            return String(decoding: data.prefix { $0 != 0 }, as: UTF8.self)
        }
        return nil
    }

    /// Walks up the service tree looking for a `model`, since the accelerator
    /// itself does not carry one. Bounded, because an unbounded walk would
    /// reach the root and pick up the Mac's own model identifier.
    private static func name(_ service: io_service_t) -> String? {
        var current = service
        var owned = false
        defer { if owned { IOObjectRelease(current) } }

        for _ in 0..<3 {
            if let model = string(current, "model"), !model.isEmpty { return model }

            var parent: io_registry_entry_t = 0
            guard IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent) == KERN_SUCCESS
            else { return nil }

            if owned { IOObjectRelease(current) }
            current = parent
            owned = true
        }
        return nil
    }
}

extension GPUReader: MetricReader {}

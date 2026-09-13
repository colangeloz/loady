/// Dispatched on the driver's `IOClass`, not `#if arch()` — the x86_64 slice
/// runs on Apple Silicon under Rosetta.
public enum GPUVendor: String, Sendable {
    case apple, intel, amd, nvidia, unknown

    /// Prefix-matched: the suffix changes every hardware generation.
    public init(ioClass: String) {
        switch ioClass.lowercased() {
        case let c where c.hasPrefix("agx"):           self = .apple
        case let c where c.contains("intel"):          self = .intel
        case let c where c.contains("amd") || c.contains("radeon"): self = .amd
        case let c where c.contains("nvaccelerator") || c.contains("nvidia"): self = .nvidia
        default:                                       self = .unknown
        }
    }
}

/// One GPU's state. Everything past `name` is optional because GPUs differ in
/// what they publish; absent is never reported as zero.
public struct GPUDevice: Sendable, Equatable, Identifiable {
    public let id: UInt64
    public let name: String
    public let vendor: GPUVendor

    /// 0...1. `nil` on a device's first sample — see `GPUReader`.
    public let utilization: Double?
    public let rendererUtilization: Double?
    public let tilerUtilization: Double?

    public let inUseMemory: Int?
    public let allocatedMemory: Int?

    /// Discrete GPUs only. Apple Silicon publishes neither here.
    public let temperatureCelsius: Double?
    public let coreClockMHz: Double?

    public init(
        id: UInt64,
        name: String,
        vendor: GPUVendor,
        utilization: Double? = nil,
        rendererUtilization: Double? = nil,
        tilerUtilization: Double? = nil,
        inUseMemory: Int? = nil,
        allocatedMemory: Int? = nil,
        temperatureCelsius: Double? = nil,
        coreClockMHz: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.vendor = vendor
        self.utilization = utilization
        self.rendererUtilization = rendererUtilization
        self.tilerUtilization = tilerUtilization
        self.inUseMemory = inUseMemory
        self.allocatedMemory = allocatedMemory
        self.temperatureCelsius = temperatureCelsius
        self.coreClockMHz = coreClockMHz
    }
}

/// Every GPU the machine currently has.
public struct GPUSample: Sendable, Equatable {
    public let devices: [GPUDevice]

    public init(devices: [GPUDevice]) {
        self.devices = devices
    }

    /// The busiest device with a reading — on a laptop with a discrete GPU,
    /// whichever is actually working.
    public var primary: GPUDevice? {
        devices.filter { $0.utilization != nil }
            .max { ($0.utilization ?? 0) < ($1.utilization ?? 0) }
            ?? devices.first
    }
}

/// Percent-to-fraction and smoothing, kept away from IOKit.
enum GPUMath {

    /// Three seconds: enough to remove dropouts without visible lag.
    static let smoothingWindow = 3

    /// Rolling mean. `Device Utilization %` counts submitted work, so it is
    /// genuinely 0 in seconds where nothing was drawn — 9 of 30 reads on an
    /// idle desktop, swinging 0-37%. The mean is sound (16.1% against
    /// powermetrics' 13-17%); only the variance is unusable at 1 Hz.
    static func smoothed(_ recent: [Double]) -> Double? {
        guard !recent.isEmpty else { return nil }
        let window = recent.suffix(smoothingWindow)
        return window.reduce(0, +) / Double(window.count)
    }

    /// IOKit reports whole percents. Values outside 0...100 have been observed
    /// on driver recovery, so clamp rather than propagate a nonsense fraction.
    static func fraction(percent: Double?) -> Double? {
        guard let percent else { return nil }
        guard percent.isFinite else { return nil }
        return min(1, max(0, percent / 100))
    }
}

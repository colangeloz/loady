/// Which driver family a GPU sits behind.
///
/// Dispatched on the driver's `IOClass` rather than on the build architecture:
/// the x86_64 slice runs on Apple Silicon under Rosetta, where `#if arch()`
/// would pick the Intel path on an M-series Mac.
public enum GPUVendor: String, Sendable {
    case apple, intel, amd, nvidia, unknown

    /// Apple's driver classes are `AGXAccelerator*`, Intel's `IntelAccelerator`,
    /// AMD's `AMDRadeon*`, NVIDIA's `nvAccelerator`. Matched case-insensitively
    /// on a prefix, because the suffix changes every hardware generation.
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

/// One GPU's state at a point in time.
///
/// Everything past `name` is optional because GPUs genuinely differ in what
/// they publish — Intel and AMD expose temperature and core clock, Apple
/// Silicon exposes neither, and a brand new device has no utilization yet.
/// A missing value is reported as absent, never as a zero.
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

    /// The busiest device with a reading, which is what a single-line readout
    /// should show — on a laptop with a discrete GPU the interesting one is
    /// whichever is actually working.
    public var primary: GPUDevice? {
        devices.filter { $0.utilization != nil }
            .max { ($0.utilization ?? 0) < ($1.utilization ?? 0) }
            ?? devices.first
    }
}

/// Percent-to-fraction conversion and smoothing, kept pure and separate
/// from IOKit.
enum GPUMath {

    /// How many samples the rolling mean covers. Three seconds is enough to
    /// remove the dropouts without the readout lagging noticeably behind a
    /// change in load.
    static let smoothingWindow = 3

    /// A rolling mean over the most recent readings.
    ///
    /// `Device Utilization %` counts work the driver submitted, which is
    /// genuinely zero in seconds where nothing was drawn — measured at 9 of 30
    /// one-second reads on an idle desktop, swinging 0% to 37% between
    /// consecutive samples. The underlying mean is sound (16.1% against
    /// powermetrics' 13-17% over the same period); only the per-sample
    /// variance is unusable for a readout that updates once a second.
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

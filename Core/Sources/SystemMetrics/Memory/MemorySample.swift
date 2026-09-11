/// A snapshot of physical memory use, in bytes.
///
/// The categories mirror Activity Monitor's, because that's what users will
/// compare against. Getting them subtly different is worse than not showing
/// them — "why does Loady say 40 GB and Activity Monitor say 32?" is a bug
/// report you cannot win.
public struct MemorySample: Sendable, Equatable {

    /// Memory held by running applications.
    public let app: Int

    /// Memory the kernel cannot page out. Drivers, kernel structures.
    public let wired: Int

    /// Memory that has been compressed to avoid swapping to disk.
    public let compressed: Int

    /// File-backed pages the system is keeping around opportunistically.
    /// Available for reuse, so *not* counted as used.
    public let cached: Int

    /// Genuinely unused.
    public let free: Int

    /// Installed physical memory.
    public let total: Int

    /// Kernel memory-pressure level: 1 normal, 2 warning, 4 critical.
    public let pressureLevel: Int

    /// Swap currently in use, in bytes.
    public let swapUsed: Int

    public init(
        app: Int, wired: Int, compressed: Int, cached: Int,
        free: Int, total: Int, pressureLevel: Int, swapUsed: Int
    ) {
        self.app = app
        self.wired = wired
        self.compressed = compressed
        self.cached = cached
        self.free = free
        self.total = total
        self.pressureLevel = pressureLevel
        self.swapUsed = swapUsed
    }

    /// What Activity Monitor calls "Memory Used".
    public var used: Int { app + wired + compressed }

    /// Used as a fraction of total, 0...1.
    public var usedFraction: Double {
        guard total > 0 else { return 0 }
        return min(1, Double(used) / Double(total))
    }

    /// Memory pressure as a human-readable state.
    public var pressure: MemoryPressure {
        switch pressureLevel {
        case 4: .critical
        case 2: .warning
        default: .normal
        }
    }
}

public enum MemoryPressure: Sendable, Equatable {
    case normal, warning, critical
}

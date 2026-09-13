/// One group of CPU cores sharing a performance level.
///
/// Names come from the kernel and vary by machine: "Super"/"Performance" on an
/// M5 Pro, "Performance"/"Efficiency" on an M1, a single "Standard" on Intel.
public struct CoreTier: Sendable, Equatable {
    /// Kernel-supplied. Never assume a particular value.
    public let name: String

    public let coreCount: Int

    /// Logical CPU indices in this tier.
    ///
    /// `hw.perflevel0` is the *fastest* tier, but per-core kernel data is
    /// ordered slowest-first — so the M5 Pro's six "Super" cores are indices
    /// 12...17, not 0...5. Reversing this produces plausible-looking nonsense.
    public let cpuIndices: Range<Int>

    public init(name: String, coreCount: Int, cpuIndices: Range<Int>) {
        self.name = name
        self.coreCount = coreCount
        self.cpuIndices = cpuIndices
    }
}

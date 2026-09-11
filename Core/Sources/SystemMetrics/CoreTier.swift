/// One group of CPU cores that share a performance level.
///
/// The name comes from the kernel and varies by machine: "Super" and
/// "Performance" on an M5 Pro, "Performance" and "Efficiency" on an M1,
/// a single "Standard" on Intel. Treating it as data rather than a fixed
/// set of cases is what lets one type describe all of them — including
/// whatever Apple names the tiers on hardware that doesn't exist yet.
public struct CoreTier: Sendable, Equatable {
    /// Kernel-supplied name, e.g. "Super". Never assume a particular value.
    public let name: String

    /// Physical cores in this tier.
    public let coreCount: Int

    /// Logical CPU indices belonging to this tier.
    ///
    /// This matters more than it looks. `hw.perflevel0` is the *fastest* tier,
    /// but per-core kernel data lists cores slowest-first — so on an M5 Pro the
    /// six "Super" cores are indices 12...17, not 0...5. Getting this backwards
    /// produces graphs that are wrong in a way that looks completely plausible.
    public let cpuIndices: Range<Int>

    public init(name: String, coreCount: Int, cpuIndices: Range<Int>) {
        self.name = name
        self.coreCount = coreCount
        self.cpuIndices = cpuIndices
    }
}

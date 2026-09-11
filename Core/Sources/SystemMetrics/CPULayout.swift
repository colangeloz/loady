/// The CPU's core layout: every tier the kernel reports, fastest first.
public struct CPULayout: Sendable, Equatable {
    /// Tiers in kernel order — `hw.perflevel0` first, which is the *fastest*.
    public let tiers: [CoreTier]

    /// Logical CPUs per physical core. 1 on Apple Silicon (no SMT),
    /// 2 on Intel Macs with hyperthreading.
    public let threadsPerCore: Int

    public init(tiers: [CoreTier], threadsPerCore: Int) {
        self.tiers = tiers
        self.threadsPerCore = threadsPerCore
    }

    /// Total physical cores across every tier.
    public var totalCores: Int {
        tiers.reduce(0) { $0 + $1.coreCount }
    }

    /// True when the machine has more than one kind of core.
    /// Intel Macs are homogeneous; Apple Silicon is not.
    public var isHeterogeneous: Bool { tiers.count > 1 }
}

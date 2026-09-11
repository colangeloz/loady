import Darwin

/// An immutable description of the machine this code is running on.
///
/// Built once at startup and consulted by everything else. This is what
/// replaces compile-time architecture checks: `#if arch(x86_64)` is *wrong*
/// here, because the x86_64 slice of a universal binary runs on Apple Silicon
/// under Rosetta — where it would take the Intel path and report nothing.
/// Asking the running machine is the only reliable answer.
public struct SystemProfile: Sendable, Equatable {

    /// Marketing-ish model identifier, e.g. "Mac17,9".
    public let modelIdentifier: String

    /// CPU name, e.g. "Apple M5 Pro".
    public let cpuBrand: String

    /// True when the *machine* is Apple Silicon, regardless of which slice
    /// of the binary is executing.
    public let isAppleSilicon: Bool

    /// True when this process is an x86_64 binary being translated by Rosetta.
    public let isTranslated: Bool

    /// CPU core layout — tiers, counts and index ranges.
    public let cpu: CPULayout

    /// Physical RAM in bytes.
    public let memoryBytes: Int

    /// Virtual-memory page size in bytes.
    ///
    /// **16384 on Apple Silicon, 4096 on Intel.** Every memory statistic the
    /// kernel reports is a page *count*, so hardcoding the Intel value makes
    /// every number on Apple Silicon four times too small.
    public let pageSize: Int

    public init(
        modelIdentifier: String,
        cpuBrand: String,
        isAppleSilicon: Bool,
        isTranslated: Bool,
        cpu: CPULayout,
        memoryBytes: Int,
        pageSize: Int
    ) {
        self.modelIdentifier = modelIdentifier
        self.cpuBrand = cpuBrand
        self.isAppleSilicon = isAppleSilicon
        self.isTranslated = isTranslated
        self.cpu = cpu
        self.memoryBytes = memoryBytes
        self.pageSize = pageSize
    }
}

// MARK: - Reading the real machine

extension SystemProfile {

    /// Interrogates the kernel and builds a profile of this machine.
    ///
    /// Every field has a fallback, because this must not crash on hardware
    /// nobody has tested — including virtual machines, where several of these
    /// keys are missing or lie.
    public static func current() -> SystemProfile {
        SystemProfile(
            modelIdentifier: Sysctl.string("hw.model") ?? "unknown",
            cpuBrand: Sysctl.string("machdep.cpu.brand_string") ?? "unknown",

            // The machine is Apple Silicon if this key exists and is 1.
            // Intel Macs don't have the key at all, so nil means Intel.
            isAppleSilicon: Sysctl.flag("hw.optional.arm64") ?? false,

            // 0 = running natively, 1 = translated by Rosetta,
            // key absent = a genuine Intel Mac.
            isTranslated: Sysctl.flag("sysctl.proc_translated") ?? false,

            cpu: readCPULayout(),
            memoryBytes: Sysctl.integer("hw.memsize") ?? 0,
            pageSize: Sysctl.integer("hw.pagesize") ?? 4096
        )
    }

    /// Reads the CPU tier structure without assuming anything about it.
    ///
    /// The kernel exposes `hw.nperflevels` and then `hw.perflevelN.*` for each.
    /// Intel reports exactly one level named "Standard". An M1 reports two,
    /// "Performance" and "Efficiency". An M5 Pro reports two named "Super" and
    /// "Performance" — with no efficiency tier at all. Code that looks for the
    /// string "Efficiency" finds nothing on this machine.
    static func readCPULayout() -> CPULayout {
        let physical = Sysctl.integer("hw.physicalcpu") ?? 1
        let logical  = Sysctl.integer("hw.logicalcpu") ?? physical
        let threadsPerCore = max(1, logical / max(1, physical))

        let levelCount = Sysctl.integer("hw.nperflevels") ?? 1

        // Kernel per-core data is ordered slowest-tier-first, while perflevel0
        // is the *fastest* tier. So we walk the levels from last to first,
        // assigning CPU indices from 0 upwards, then reverse at the end to get
        // back to fastest-first ordering.
        var tiers: [CoreTier] = []
        var nextIndex = 0

        for level in stride(from: levelCount - 1, through: 0, by: -1) {
            let name = Sysctl.string("hw.perflevel\(level).name") ?? "Standard"
            let count = Sysctl.integer("hw.perflevel\(level).logicalcpu") ?? 0
            guard count > 0 else { continue }

            tiers.append(
                CoreTier(
                    name: name,
                    coreCount: Sysctl.integer("hw.perflevel\(level).physicalcpu") ?? count,
                    cpuIndices: nextIndex ..< (nextIndex + count)
                )
            )
            nextIndex += count
        }

        // Nothing reported usable tiers — a VM, or a kernel we don't understand.
        // Fall back to one homogeneous tier rather than an empty layout.
        if tiers.isEmpty {
            tiers = [CoreTier(name: "Standard", coreCount: physical, cpuIndices: 0 ..< logical)]
        }

        return CPULayout(tiers: tiers.reversed(), threadsPerCore: threadsPerCore)
    }
}

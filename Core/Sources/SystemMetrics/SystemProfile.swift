import Darwin

/// What machine this is, read once at startup.
///
/// Replaces `#if arch()`, which is wrong here: the x86_64 slice runs on Apple
/// Silicon under Rosetta and would take the Intel path.
public struct SystemProfile: Sendable, Equatable {

    /// e.g. "Mac17,9".
    public let modelIdentifier: String

    /// e.g. "Apple M5 Pro".
    public let cpuBrand: String

    /// The *machine*, whichever slice is executing.
    public let isAppleSilicon: Bool

    /// This process is x86_64 under Rosetta.
    public let isTranslated: Bool

    public let cpu: CPULayout

    public let memoryBytes: Int

    /// 16384 on Apple Silicon, 4096 on Intel. Kernel memory figures are page
    /// *counts*, so hardcoding 4096 makes every number 4x too small.
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

    /// Every field has a fallback: this must not crash on untested hardware,
    /// including VMs where several of these keys are missing.
    public static func current() -> SystemProfile {
        SystemProfile(
            modelIdentifier: Sysctl.string("hw.model") ?? "unknown",
            cpuBrand: Sysctl.string("machdep.cpu.brand_string") ?? "unknown",

            // Absent on Intel, so nil means Intel.
            isAppleSilicon: Sysctl.flag("hw.optional.arm64") ?? false,

            // 0 native, 1 Rosetta, absent = a real Intel Mac.
            isTranslated: Sysctl.flag("sysctl.proc_translated") ?? false,

            cpu: readCPULayout(),
            memoryBytes: Sysctl.integer("hw.memsize") ?? 0,
            pageSize: Sysctl.integer("hw.pagesize") ?? 4096
        )
    }

    /// Reads the tier structure without assuming a shape.
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

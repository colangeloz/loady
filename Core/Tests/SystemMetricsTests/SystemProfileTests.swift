import Testing
@testable import SystemMetrics

/// These run against the real machine, so they assert *shape* rather than
/// values. `#expect(model == "Mac17,9")` would pass here and fail on every
/// CI runner and every other Mac.
@Suite("SystemProfile")
struct SystemProfileTests {

    @Test func describesTheMachine() {
        let p = SystemProfile.current()

        #expect(p.modelIdentifier != "unknown")
        #expect(p.cpuBrand.isEmpty == false)
        #expect(p.memoryBytes > 1_000_000_000)
    }

    // Only two page sizes exist on any Mac Apple has shipped.
    @Test func pageSizeIsOneOfTwoKnownValues() {
        let p = SystemProfile.current()
        #expect(p.pageSize == 4096 || p.pageSize == 16384)
    }

    @Test func reportsAtLeastOneCoreTier() {
        let p = SystemProfile.current()
        #expect(p.cpu.tiers.isEmpty == false)
        #expect(p.cpu.totalCores > 0)
    }

    /// The important one. Tier index ranges must tile the full CPU range
    /// exactly — no gaps, no overlaps, nothing left over. A tier whose range
    /// is wrong produces a graph that's mislabelled in a plausible-looking way.
    @Test func tierIndexRangesTileTheWholeCPURange() {
        let p = SystemProfile.current()

        let covered = p.cpu.tiers
            .flatMap { Array($0.cpuIndices) }
            .sorted()

        let logicalCPUs = Sysctl.integer("hw.logicalcpu") ?? 0

        #expect(covered == Array(0 ..< logicalCPUs))
    }

    /// Rosetta-translated processes are still running on an Apple Silicon
    /// machine. Being translated therefore implies Apple Silicon — the
    /// combination "translated but not Apple Silicon" is impossible.
    @Test func translationImpliesAppleSilicon() {
        let p = SystemProfile.current()
        if p.isTranslated { #expect(p.isAppleSilicon) }
    }
}

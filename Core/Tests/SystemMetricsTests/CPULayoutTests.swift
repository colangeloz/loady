import Testing
@testable import SystemMetrics

@Suite("CPULayout")
struct CPULayoutTests {

    // Hand-built layouts: no kernel involved, so these pass identically on
    // an M5 Pro, an Intel CI runner, and hardware that doesn't exist yet.

    @Test func sumsCoresAcrossTiers() {
        let m5pro = CPULayout(
            tiers: [
                CoreTier(name: "Super", coreCount: 6, cpuIndices: 12 ..< 18),
                CoreTier(name: "Performance", coreCount: 12, cpuIndices: 0 ..< 12)
            ],
            threadsPerCore: 1
        )
        #expect(m5pro.totalCores == 18)
        #expect(m5pro.isHeterogeneous)
    }

    @Test func handlesASingleTierMachine() {
        let intel = CPULayout(
            tiers: [CoreTier(name: "Standard", coreCount: 8, cpuIndices: 0 ..< 16)],
            threadsPerCore: 2
        )
        #expect(intel.totalCores == 8)
        #expect(intel.isHeterogeneous == false)
        #expect(intel.threadsPerCore == 2)
    }

    @Test func handlesNoTiers() {
        #expect(CPULayout(tiers: [], threadsPerCore: 1).totalCores == 0)
    }
}

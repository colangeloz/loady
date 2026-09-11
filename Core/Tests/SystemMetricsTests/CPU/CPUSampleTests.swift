import Testing
@testable import SystemMetrics

@Suite("CPUSample")
struct CPUSampleTests {

    private func core(busy: Double) -> CoreLoad {
        CoreLoad(user: busy, system: 0, nice: 0, idle: 1 - busy)
    }

    @Test func averagesAcrossCores() {
        let sample = CPUSample(cores: [core(busy: 1.0), core(busy: 0.0)])
        #expect(sample.busy == 0.5)
    }

    @Test func emptySampleIsZeroNotNaN() {
        let sample = CPUSample(cores: [])
        #expect(sample.busy == 0)
        #expect(sample.busy.isNaN == false)
    }

    /// A tier's average uses only its own CPU indices. On an M5 Pro the
    /// "Super" tier is indices 12...17 — if this used 0...5 instead, the
    /// number would look entirely plausible and be completely wrong.
    @Test func averagesOnlyTheCoresInATier() {
        // 4 cores: the first two idle, the last two pinned.
        let sample = CPUSample(cores: [
            core(busy: 0.0), core(busy: 0.0),
            core(busy: 1.0), core(busy: 1.0)
        ])

        let slow = CoreTier(name: "Performance", coreCount: 2, cpuIndices: 0 ..< 2)
        let fast = CoreTier(name: "Super", coreCount: 2, cpuIndices: 2 ..< 4)

        #expect(sample.busy(for: slow) == 0.0)
        #expect(sample.busy(for: fast) == 1.0)
    }

    /// A tier whose range exceeds what we sampled must not crash the app.
    @Test func toleratesATierRangeBeyondTheSampledCores() {
        let sample = CPUSample(cores: [core(busy: 0.5)])
        let bogus = CoreTier(name: "Ghost", coreCount: 8, cpuIndices: 4 ..< 12)

        #expect(sample.busy(for: bogus) == 0)
    }
}

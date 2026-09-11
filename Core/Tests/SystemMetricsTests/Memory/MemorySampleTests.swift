import Testing
@testable import SystemMetrics

@Suite("MemorySample")
struct MemorySampleTests {

    private func sample(app: Int, wired: Int, compressed: Int, total: Int) -> MemorySample {
        MemorySample(app: app, wired: wired, compressed: compressed,
                     cached: 0, free: 0, total: total,
                     pressureLevel: 1, swapUsed: 0)
    }

    @Test func usedIsAppPlusWiredPlusCompressed() {
        let s = sample(app: 4, wired: 2, compressed: 1, total: 16)
        #expect(s.used == 7)
    }

    /// Cached files are available for reuse, so they must NOT count as used.
    /// Counting them is the most common way to report inflated memory usage.
    @Test func cachedFilesAreNotCountedAsUsed() {
        let s = MemorySample(app: 4, wired: 2, compressed: 1, cached: 8,
                             free: 1, total: 16, pressureLevel: 1, swapUsed: 0)
        #expect(s.used == 7)
    }

    @Test func fractionIsClampedAndSafeAtZeroTotal() {
        #expect(sample(app: 8, wired: 0, compressed: 0, total: 16).usedFraction == 0.5)
        #expect(sample(app: 99, wired: 0, compressed: 0, total: 10).usedFraction == 1.0)

        let noTotal = sample(app: 4, wired: 0, compressed: 0, total: 0)
        #expect(noTotal.usedFraction == 0)
        #expect(noTotal.usedFraction.isNaN == false)
    }

    @Test func pressureLevelsMapToStates() {
        func pressure(_ level: Int) -> MemoryPressure {
            MemorySample(app: 0, wired: 0, compressed: 0, cached: 0, free: 0,
                         total: 1, pressureLevel: level, swapUsed: 0).pressure
        }
        #expect(pressure(1) == .normal)
        #expect(pressure(2) == .warning)
        #expect(pressure(4) == .critical)
        #expect(pressure(99) == .normal)   // unknown values must not crash
    }
}

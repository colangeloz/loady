import Testing
@testable import SystemMetrics

/// Real kernel, so these assert shape and internal consistency rather than
/// values — memory use changes between one line of the test and the next.
@Suite("MemoryReader")
struct MemoryReaderTests {

    @Test func firstReadReturnsASample() {
        // Unlike CPUReader, memory is absolute rather than a rate, so there's
        // no baseline to establish and the first read is already valid.
        #expect(MemoryReader().read() != nil)
    }

    @Test func totalMatchesTheMachine() throws {
        let sample = try #require(MemoryReader().read())
        #expect(sample.total == Sysctl.integer("hw.memsize"))
    }

    @Test func categoriesAreNonNegativeAndFitInPhysicalMemory() throws {
        let s = try #require(MemoryReader().read())

        #expect(s.app >= 0)
        #expect(s.wired >= 0)
        #expect(s.compressed >= 0)
        #expect(s.cached >= 0)
        #expect(s.used <= s.total)
        #expect(s.usedFraction > 0 && s.usedFraction <= 1)
    }

    /// A page-size mistake is the classic bug here: hardcoding 4096 on a Mac
    /// whose pages are 16 KB yields numbers exactly four times too small.
    /// Any real Mac has at least a gigabyte of wired memory-ish usage, so a
    /// wildly low total is the signature of that error.
    @Test func figuresAreInARealisticRangeForAnyMac() throws {
        let s = try #require(MemoryReader().read())
        #expect(s.used > 500_000_000)        // half a GB, absolute floor
        #expect(s.wired > 100_000_000)
    }
}

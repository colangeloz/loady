import Testing
@testable import SystemMetrics

@Suite("DiskReader")
struct DiskReaderTests {

    @Test func firstReadReturnsCapacitiesWithZeroThroughput() throws {
        let s = try #require(DiskReader().read())
        #expect(s.volumes.isEmpty == false)
        #expect(s.readBytesPerSecond == 0)   // no baseline yet, by contract
        #expect(s.writeBytesPerSecond == 0)
    }

    /// The APFS trap: `statfs` reports the container's free space to every
    /// volume in it, so a naive enumeration would report several times the
    /// real capacity. Browsable volumes give one entry per container.
    @Test func doesNotMultiplyCapacityAcrossAPFSVolumes() throws {
        let s = try #require(DiskReader().read())
        let boot = try #require(s.primary)

        // Anything that has summed the container across its volumes shows a
        // wildly implausible total. No shipping Mac has a 5 TB internal disk.
        #expect(boot.total < 5_000_000_000_000)
        #expect(boot.available <= boot.total)
    }

    @Test func throughputIsNonNegativeOnSubsequentReads() throws {
        let reader = DiskReader()
        _ = reader.read()
        let s = try #require(reader.read())
        #expect(s.readBytesPerSecond >= 0)
        #expect(s.writeBytesPerSecond >= 0)
        #expect(s.readBytesPerSecond.isNaN == false)
    }

    @Test func blockStorageCountersAreMonotonic() {
        let a = DiskReader.blockStorageTotals()
        let b = DiskReader.blockStorageTotals()
        #expect(b.read >= a.read)
        #expect(b.written >= a.written)
        #expect(a.read > 0)   // any running Mac has read something
    }
}

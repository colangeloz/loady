import Testing
@testable import SystemMetrics

@Suite("DiskVolume")
struct DiskVolumeTests {

    @Test func usedIsTotalMinusAvailable() {
        let v = DiskVolume(name: "Macintosh HD", total: 1000, available: 250)
        #expect(v.used == 750)
        #expect(v.usedFraction == 0.75)
    }

    @Test func handlesZeroTotalWithoutDividingByZero() {
        let v = DiskVolume(name: "Empty", total: 0, available: 0)
        #expect(v.usedFraction == 0)
        #expect(v.usedFraction.isNaN == false)
    }

    /// `forImportantUsage` includes purgeable space and can exceed the raw
    /// free space, which would otherwise make `used` negative.
    @Test func availableExceedingTotalClampsToZeroUsed() {
        let v = DiskVolume(name: "Odd", total: 100, available: 120)
        #expect(v.used == 0)
        #expect(v.usedFraction == 0)
    }
}

@Suite("DiskSample")
struct DiskSampleTests {

    @Test func primaryIsTheFirstVolume() {
        let s = DiskSample(
            volumes: [DiskVolume(name: "Macintosh HD", total: 100, available: 40),
                      DiskVolume(name: "External", total: 500, available: 500)],
            readBytesPerSecond: 0, writeBytesPerSecond: 0)
        #expect(s.primary?.name == "Macintosh HD")
    }

    @Test func noVolumesIsSafe() {
        #expect(DiskSample(volumes: [], readBytesPerSecond: 0, writeBytesPerSecond: 0).primary == nil)
    }
}

import Testing
@testable import SystemMetrics

/// These touch the real kernel, so they assert shape rather than values —
/// CPU load is different every time you look at it.
@Suite("CPUReader")
struct CPUReaderTests {

    /// The documented contract: nothing to diff against yet.
    @Test func firstReadReturnsNil() {
        #expect(CPUReader().read() == nil)
    }

    @Test func secondReadReturnsOneEntryPerLogicalCPU() {
        let reader = CPUReader()
        _ = reader.read()                       // establish the baseline
        let sample = reader.read()

        #expect(sample != nil)
        #expect(sample?.cores.count == Sysctl.integer("hw.logicalcpu"))
    }

    @Test func everyCoreIsBetweenZeroAndOne() {
        let reader = CPUReader()
        _ = reader.read()
        guard let sample = reader.read() else {
            Issue.record("expected a sample on the second read")
            return
        }

        for core in sample.cores {
            #expect(core.busy >= 0 && core.busy <= 1)
            #expect(core.busy.isNaN == false)
        }
        #expect(sample.busy >= 0 && sample.busy <= 1)
    }
}

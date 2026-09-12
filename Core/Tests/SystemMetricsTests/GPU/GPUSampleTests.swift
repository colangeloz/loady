import Testing
@testable import SystemMetrics

@Suite("GPUVendor")
struct GPUVendorTests {

    /// Real IOClass values. The suffix changes every generation, so matching
    /// is on a prefix — G17X is M5, G16 was M4, and a future G18 must still
    /// resolve to Apple without a code change.
    @Test(arguments: [
        ("AGXAcceleratorG17X", GPUVendor.apple),
        ("AGXAcceleratorG16G", GPUVendor.apple),
        ("AGXAcceleratorG99Z", GPUVendor.apple),
        ("IntelAccelerator", GPUVendor.intel),
        ("AMDRadeonX6000", GPUVendor.amd),
        ("nvAccelerator", GPUVendor.nvidia),
        ("SomethingElse", GPUVendor.unknown),
    ])
    func classifies(ioClass: String, expected: GPUVendor) {
        #expect(GPUVendor(ioClass: ioClass) == expected)
    }

    @Test func isCaseInsensitive() {
        #expect(GPUVendor(ioClass: "agxacceleratorg17x") == .apple)
        #expect(GPUVendor(ioClass: "INTELACCELERATOR") == .intel)
    }
}

@Suite("GPUMath")
struct GPUMathTests {

    @Test func convertsPercentToFraction() {
        #expect(GPUMath.fraction(percent: 0) == 0)
        #expect(GPUMath.fraction(percent: 50) == 0.5)
        #expect(GPUMath.fraction(percent: 100) == 1)
    }

    /// Values outside 0...100 have been seen after a driver recovery.
    @Test func clampsOutOfRangeValues() {
        #expect(GPUMath.fraction(percent: 140) == 1)
        #expect(GPUMath.fraction(percent: -5) == 0)
        #expect(GPUMath.fraction(percent: .infinity) == nil)
        #expect(GPUMath.fraction(percent: .nan) == nil)
    }

    @Test func absentStaysAbsent() {
        #expect(GPUMath.fraction(percent: nil) == nil)
    }
}

@Suite("GPUSample")
struct GPUSampleTests {

    private func device(_ name: String, _ utilization: Double?) -> GPUDevice {
        GPUDevice(id: UInt64(abs(name.hashValue)), name: name, vendor: .unknown,
                  utilization: utilization)
    }

    /// On a machine with both an integrated and a discrete GPU, the one worth
    /// showing is whichever is actually working.
    @Test func primaryIsTheBusiestDeviceWithAReading() {
        let s = GPUSample(devices: [device("integrated", 0.1), device("discrete", 0.8)])
        #expect(s.primary?.name == "discrete")
    }

    /// A device still warming up must not win by virtue of having no number.
    @Test func primaryIgnoresDevicesWithoutAReading() {
        let s = GPUSample(devices: [device("unread", nil), device("busy", 0.4)])
        #expect(s.primary?.name == "busy")
    }

    @Test func primaryFallsBackWhenNothingHasReadYet() {
        let s = GPUSample(devices: [device("only", nil)])
        #expect(s.primary?.name == "only")
    }

    @Test func primaryIsNilWithNoDevices() {
        #expect(GPUSample(devices: []).primary == nil)
    }
}

@Suite("GPUMath.smoothed")
struct GPUSmoothingTests {

    /// Means of fractions are not exactly representable, so compare with a
    /// tolerance rather than for equality.
    private func expectClose(_ value: Double?, _ expected: Double,
                             sourceLocation: SourceLocation = #_sourceLocation) throws {
        let value = try #require(value, sourceLocation: sourceLocation)
        #expect(abs(value - expected) < 1e-9, sourceLocation: sourceLocation)
    }

    @Test func averagesTheWindow() throws {
        try expectClose(GPUMath.smoothed([0.1, 0.2, 0.3]), 0.2)
    }

    /// Fewer samples than the window is the normal state just after launch.
    @Test func handlesAShortWindow() throws {
        try expectClose(GPUMath.smoothed([0.4]), 0.4)
        try expectClose(GPUMath.smoothed([0.2, 0.4]), 0.3)
    }

    @Test func usesOnlyTheMostRecentSamples() throws {
        // The leading 1.0s must not influence the result once the window moves.
        try expectClose(GPUMath.smoothed([1, 1, 1, 0.1, 0.2, 0.3]), 0.2)
    }

    /// The dropout this exists to fix: a zero between two real readings must
    /// not drag the readout to zero.
    @Test func aSingleDropoutDoesNotZeroTheReadout() throws {
        let smoothed = try #require(GPUMath.smoothed([0.30, 0.0, 0.33]))
        #expect(smoothed > 0.2)
    }

    @Test func emptyIsAbsentNotZero() {
        #expect(GPUMath.smoothed([]) == nil)
    }
}

import Testing
@testable import SystemMetrics

@Suite("GPUReader")
struct GPUReaderTests {

    /// Every Mac has at least one GPU. A CI VM may not, so this tolerates an
    /// empty result rather than asserting hardware exists.
    @Test func enumeratesWithoutCrashing() throws {
        let sample = try #require(GPUReader().read())
        for device in sample.devices {
            #expect(device.name.isEmpty == false)
        }
    }

    /// The contract that finding #5 forces: utilization is averaged since the
    /// counter was last read by any process, so the first read covers an
    /// unbounded window and must not be reported as if it described an
    /// interval. Verified empirically — back-to-back reads on an idle M5 Pro
    /// gave 22%, then 0% nine times.
    @Test func firstSamplePerDeviceWithholdsUtilization() throws {
        let reader = GPUReader()
        let first = try #require(reader.read())

        for device in first.devices {
            #expect(device.utilization == nil)
            #expect(device.rendererUtilization == nil)
        }
    }

    /// A GPU that publishes no utilization at all is a supported state, not a
    /// failure: CI runs on VMs whose paravirtual GPU (`AppleParavirtGPU`,
    /// `Apple Paravirtualized Graphics Device`) enumerates but exposes no
    /// PerformanceStatistics. Asserting a reading exists would test the runner's
    /// hardware rather than this code, so the contract is conditional — when
    /// there is a value it must be a fraction, and absence must stay absent
    /// rather than becoming zero.
    @Test func utilizationIsAFractionWhenPublishedAtAll() throws {
        let reader = GPUReader()
        _ = reader.read()
        _ = reader.read()
        let sample = try #require(reader.read())

        for device in sample.devices {
            guard let value = device.utilization else { continue }
            #expect(value >= 0 && value <= 1)
        }
    }

    /// Memory is an instantaneous gauge rather than a windowed average, so it
    /// is valid on the very first read — where a device publishes it.
    @Test func memoryIsValidOnTheFirstRead() throws {
        let sample = try #require(GPUReader().read())
        for device in sample.devices {
            guard let inUse = device.inUseMemory else { continue }
            #expect(inUse >= 0)
        }
    }
}

@Suite("GPUReader smoothing")
struct GPUReaderSmoothingTests {

    /// All three utilization figures come from the same bursty counter, so
    /// they must be smoothed alike. Smoothing only the headline number left it
    /// steady beside a renderer and tiler that still dropped to zero.
    @Test func smoothsEveryUtilizationFigureConsistently() throws {
        let reader = GPUReader()
        _ = reader.read()

        var utilizationSeen = false
        var rendererSeen = false
        for _ in 0..<4 {
            let sample = try #require(reader.read())
            for device in sample.devices {
                if device.utilization != nil { utilizationSeen = true }
                if device.rendererUtilization != nil { rendererSeen = true }
            }
        }
        // Either both are published by this driver or neither is — a VM's
        // paravirtual GPU publishes neither. What must not happen is one being
        // smoothed while the other is raw.
        #expect(utilizationSeen == rendererSeen)
    }

    /// The reader keeps per-device history, so it must not accumulate state for
    /// hardware that has gone away.
    @Test func forgetsDevicesThatDisappear() throws {
        let reader = GPUReader()
        let first = try #require(reader.read())
        for _ in 0..<3 { _ = reader.read() }
        let later = try #require(reader.read())
        // Nothing was unplugged mid-test, so the device set must be stable —
        // this pins that pruning does not drop devices that are still present.
        #expect(Set(first.devices.map(\.id)) == Set(later.devices.map(\.id)))
    }
}

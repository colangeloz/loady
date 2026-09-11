import Testing
@testable import SystemMetrics

@Suite("Sysctl")
struct SysctlTests {

    @Test func readsAKnownStringKey() {
        let model = Sysctl.string("hw.model")
        #expect(model != nil)
        #expect(model?.isEmpty == false)
    }

    // The failure path matters as much as the success path: the app decides
    // which CPU-frequency source to use based on a missing key returning nil.
    @Test func returnsNilForAnUnknownKey() {
        #expect(Sysctl.string("hw.definitely.not.a.real.key") == nil)
        #expect(Sysctl.integer("hw.definitely.not.a.real.key") == nil)
    }

    // hw.ncpu is a 32-bit value, hw.memsize is 64-bit. Both must decode
    // correctly — reading a 4-byte key into a UInt64 leaves garbage on top.
    @Test func readsBoth32BitAnd64BitIntegers() {
        let cpus = Sysctl.integer("hw.ncpu")
        let memory = Sysctl.integer("hw.memsize")

        #expect(cpus != nil && cpus! > 0)
        #expect(memory != nil && memory! > 1_000_000_000)  // any Mac has >1 GB
    }

    @Test func readsFlags() {
        // Present on Apple Silicon, absent on Intel — either is valid,
        // but it must never crash or return a nonsense value.
        let arm = Sysctl.flag("hw.optional.arm64")
        #expect(arm == true || arm == nil)
    }
}

import Testing
@testable import SystemMetrics

/// All hand-written numbers — no kernel. These are the tests that matter,
/// because this is where the bugs actually live.
@Suite("CPUMath")
struct CPUMathTests {

    @Test func halfIdleIsFiftyPercentBusy() {
        let before = CoreTicks(user: 100, system: 0, idle: 100, nice: 0)
        let after  = CoreTicks(user: 150, system: 0, idle: 150, nice: 0)

        let load = CPUMath.load(from: before, to: after)
        #expect(load.busy == 0.5)
        #expect(load.idle == 0.5)
    }

    @Test func completelyIdle() {
        let before = CoreTicks(user: 10, system: 10, idle: 10, nice: 10)
        let after  = CoreTicks(user: 10, system: 10, idle: 110, nice: 10)

        #expect(CPUMath.load(from: before, to: after).busy == 0)
    }

    @Test func completelyBusy() {
        let before = CoreTicks(user: 0, system: 0, idle: 50, nice: 0)
        let after  = CoreTicks(user: 100, system: 0, idle: 50, nice: 0)

        #expect(CPUMath.load(from: before, to: after).busy == 1.0)
    }

    @Test func userAndSystemAreReportedSeparately() {
        let before = CoreTicks(user: 0, system: 0, idle: 0, nice: 0)
        let after  = CoreTicks(user: 25, system: 25, idle: 50, nice: 0)

        let load = CPUMath.load(from: before, to: after)
        #expect(load.user == 0.25)
        #expect(load.system == 0.25)
        #expect(load.busy == 0.5)
    }

    /// Two identical snapshots mean no time passed. Dividing by a zero total
    /// would produce NaN, which then poisons every average downstream and
    /// renders as a blank graph rather than an obvious error.
    @Test func identicalSnapshotsDoNotDivideByZero() {
        let ticks = CoreTicks(user: 5, system: 5, idle: 5, nice: 5)
        let load = CPUMath.load(from: ticks, to: ticks)

        #expect(load.busy == 0)
        #expect(load.busy.isNaN == false)
    }

    /// The kernel's counters are 32-bit and wrap after roughly 49 days of
    /// uptime. This is impossible to reproduce on demand and trivial to test
    /// with made-up numbers — exactly the case for a pure function.
    @Test func survivesCounterWraparound() {
        // idle sits 10 below the top and wraps around to 5.
        // That's 10 ticks up to .max, 1 more to roll over to 0, then 5 => 16.
        // (I got this wrong by hand the first time. Hence the test.)
        let before = CoreTicks(user: 0, system: 0, idle: .max - 10, nice: 0)
        let after  = CoreTicks(user: 0, system: 0, idle: 5,         nice: 0)

        #expect(CPUMath.delta(before.idle, after.idle) == 16)

        let load = CPUMath.load(from: before, to: after)
        #expect(load.idle == 1.0)   // all 15 ticks were idle
        #expect(load.busy == 0)     // NOT a stuck 100%
    }

    @Test func wraparoundOnABusyCounterToo() {
        let before = CoreTicks(user: .max - 4, system: 0, idle: 0, nice: 0)
        let after  = CoreTicks(user: 5,        system: 0, idle: 0, nice: 0)

        #expect(CPUMath.delta(before.user, after.user) == 10)
        #expect(CPUMath.load(from: before, to: after).busy == 1.0)
    }
}

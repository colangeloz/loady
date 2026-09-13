/// Tick snapshots to percentages. No kernel access, so the edge cases —
/// counter wraparound, zero elapsed — are testable with hand-written numbers.
public enum CPUMath {

    public static func load(from before: CoreTicks, to after: CoreTicks) -> CoreLoad {
        let user   = delta(before.user,   after.user)
        let system = delta(before.system, after.system)
        let idle   = delta(before.idle,   after.idle)
        let nice   = delta(before.nice,   after.nice)

        let total = user + system + idle + nice
        guard total > 0 else {
            return CoreLoad(user: 0, system: 0, nice: 0, idle: 0)
        }

        let t = Double(total)
        return CoreLoad(
            user:   Double(user)   / t,
            system: Double(system) / t,
            nice:   Double(nice)   / t,
            idle:   Double(idle)   / t
        )
    }

    /// Wrapping subtraction, not `-`. The kernel's 32-bit counters roll over
    /// after ~49 days of uptime; `-` would trap and the core would read pinned
    /// at 100%. `5 &- 4_294_967_290 == 11`, the true elapsed ticks.
    static func delta(_ before: UInt32, _ after: UInt32) -> UInt32 {
        after &- before
    }
}

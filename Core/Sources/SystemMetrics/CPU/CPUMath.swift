/// Pure arithmetic turning tick snapshots into percentages.
///
/// Deliberately free of any kernel access, so every edge case here can be
/// tested with hand-written numbers — including ones that are impossible to
/// reproduce on demand, like a counter wrapping after 49 days of uptime.
public enum CPUMath {

    /// Load for one core between two snapshots.
    ///
    /// Returns all-zero when no time passed, rather than dividing by zero.
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

    /// Difference between two cumulative counters, correct across wraparound.
    ///
    /// The kernel's counters are 32-bit and roll over to zero after about
    /// 49 days of uptime. Plain `after - before` would then be hugely negative
    /// (or trap, in Swift) and the core would read as pinned at 100% forever.
    ///
    /// `&-` is Swift's *wrapping* subtraction: it deliberately allows the
    /// overflow, which produces exactly the right answer in modular arithmetic.
    /// 5 &- 4_294_967_290 == 11, which is the true number of elapsed ticks.
    static func delta(_ before: UInt32, _ after: UInt32) -> UInt32 {
        after &- before
    }
}

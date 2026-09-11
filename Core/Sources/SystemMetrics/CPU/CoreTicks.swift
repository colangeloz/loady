/// Raw cumulative tick counters for one logical CPU, as the kernel reports them.
///
/// These only ever increase (until they wrap). They are meaningless on their
/// own — usage is the *difference* between two snapshots.
public struct CoreTicks: Sendable, Equatable {
    public let user: UInt32
    public let system: UInt32
    public let idle: UInt32
    public let nice: UInt32

    public init(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }
}

/// How busy one logical CPU was over an interval. Each value is a fraction
/// of that interval, 0...1.
public struct CoreLoad: Sendable, Equatable {
    public let user: Double
    public let system: Double
    public let nice: Double
    public let idle: Double

    public init(user: Double, system: Double, nice: Double, idle: Double) {
        self.user = user
        self.system = system
        self.nice = nice
        self.idle = idle
    }

    /// Everything that isn't idle. This is the number people mean by "CPU %".
    public var busy: Double { user + system + nice }
}

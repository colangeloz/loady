/// One network interface's counters and current throughput.
public struct NetworkInterface: Sendable, Equatable, Identifiable {
    public var id: String { name }

    public let name: String
    /// Cumulative since boot, 64-bit — see `NetworkReader` for why that matters.
    public let bytesIn: UInt64
    public let bytesOut: UInt64
    public let bytesInPerSecond: Double
    public let bytesOutPerSecond: Double
    /// Loopback carries a process talking to itself, not network traffic.
    public let isLoopback: Bool

    public init(name: String, bytesIn: UInt64, bytesOut: UInt64,
                bytesInPerSecond: Double = 0, bytesOutPerSecond: Double = 0,
                isLoopback: Bool = false) {
        self.name = name
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
        self.bytesInPerSecond = bytesInPerSecond
        self.bytesOutPerSecond = bytesOutPerSecond
        self.isLoopback = isLoopback
    }
}

public struct NetworkSample: Sendable, Equatable {
    public let interfaces: [NetworkInterface]

    public init(interfaces: [NetworkInterface]) {
        self.interfaces = interfaces
    }

    /// Busiest non-loopback interface. Never hardcode `en0`: it is not the same
    /// device on every Mac, nor always the one in use.
    public var primary: NetworkInterface? {
        interfaces.filter { !$0.isLoopback }
            .max { ($0.bytesIn + $0.bytesOut) < ($1.bytesIn + $1.bytesOut) }
    }

    /// Summed across every non-loopback interface.
    public var downloadBytesPerSecond: Double {
        interfaces.filter { !$0.isLoopback }.reduce(0) { $0 + $1.bytesInPerSecond }
    }

    public var uploadBytesPerSecond: Double {
        interfaces.filter { !$0.isLoopback }.reduce(0) { $0 + $1.bytesOutPerSecond }
    }
}

/// Throughput arithmetic, kept pure and away from sysctl.
enum NetworkMath {

    /// A decrease means the interface cycled (cable out, Wi-Fi reconnect, VPN)
    /// and its counters restarted — reported as zero, not as a wraparound,
    /// which would claim a gigabyte in one second.
    static func rate(before: UInt64, after: UInt64, seconds: Double) -> Double {
        guard seconds > 0 else { return 0 }
        guard after >= before else { return 0 }
        return Double(after - before) / seconds
    }
}

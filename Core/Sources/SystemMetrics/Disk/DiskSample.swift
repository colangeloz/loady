/// One mounted volume's capacity.
public struct DiskVolume: Sendable, Equatable {
    public let name: String
    public let total: Int
    public let available: Int

    public init(name: String, total: Int, available: Int) {
        self.name = name
        self.total = total
        self.available = available
    }

    public var used: Int { max(0, total - available) }

    public var usedFraction: Double {
        guard total > 0 else { return 0 }
        return min(1, Double(used) / Double(total))
    }
}

/// Volume capacities plus disk throughput over the last interval.
public struct DiskSample: Sendable, Equatable {
    public let volumes: [DiskVolume]
    public let readBytesPerSecond: Double
    public let writeBytesPerSecond: Double

    public init(volumes: [DiskVolume], readBytesPerSecond: Double, writeBytesPerSecond: Double) {
        self.volumes = volumes
        self.readBytesPerSecond = readBytesPerSecond
        self.writeBytesPerSecond = writeBytesPerSecond
    }

    /// The boot volume, which is what a single-line readout should show.
    public var primary: DiskVolume? { volumes.first }
}

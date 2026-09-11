/// CPU load across all cores over one interval.
public struct CPUSample: Sendable, Equatable {
    /// One entry per logical CPU, in kernel order (slowest tier first).
    public let cores: [CoreLoad]

    public init(cores: [CoreLoad]) {
        self.cores = cores
    }

    /// Mean busy fraction across all cores, 0...1. This is what a single
    /// "CPU 34%" readout shows.
    public var busy: Double {
        guard !cores.isEmpty else { return 0 }
        return cores.reduce(0) { $0 + $1.busy } / Double(cores.count)
    }

    /// Mean busy fraction for one tier, using its CPU index range.
    ///
    /// Returns 0 if the range falls outside what we actually sampled — which
    /// can happen on a machine whose topology we misread rather than crashing.
    public func busy(for tier: CoreTier) -> Double {
        let indices = tier.cpuIndices.filter { $0 < cores.count }
        guard !indices.isEmpty else { return 0 }
        return indices.reduce(0.0) { $0 + cores[$1].busy } / Double(indices.count)
    }
}

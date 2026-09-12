import Foundation
import IOKit

/// Volume capacity from the filesystem, throughput from the IORegistry.
///
/// Stateful because throughput is a delta: the first `read()` establishes a
/// baseline and reports zero bytes per second.
public final class DiskReader {

    private var previousBytes: (read: UInt64, written: UInt64)?
    private var previousInstant: UInt64?

    // Enumerating volumes touches the filesystem, and capacity barely moves.
    // Throughput still updates every read; capacity refreshes occasionally.
    private var cachedVolumes: [DiskVolume] = []
    private var volumesRefreshedAt: UInt64 = 0
    private let volumeRefreshInterval: UInt64 = 30_000_000_000   // 30s

    public init() {}

    public func read() -> DiskSample? {
        let io = Self.blockStorageTotals()

        var readRate = 0.0
        var writeRate = 0.0
        let now = DispatchTime.now().uptimeNanoseconds

        if let previousBytes, let previousInstant, now > previousInstant {
            let seconds = Double(now - previousInstant) / 1_000_000_000
            // Counters reset to zero when a device is unmounted, so clamp
            // rather than reporting a negative rate.
            readRate  = Double(io.read  &- previousBytes.read)  / seconds
            writeRate = Double(io.written &- previousBytes.written) / seconds
            if io.read < previousBytes.read { readRate = 0 }
            if io.written < previousBytes.written { writeRate = 0 }
        }

        previousBytes = io
        previousInstant = now

        if cachedVolumes.isEmpty || now &- volumesRefreshedAt > volumeRefreshInterval {
            cachedVolumes = Self.volumes()
            volumesRefreshedAt = now
        }

        return DiskSample(
            volumes: cachedVolumes,
            readBytesPerSecond: readRate,
            writeBytesPerSecond: writeRate
        )
    }

    /// Browsable volumes only.
    ///
    /// This is what makes APFS come out right. `statfs` reports the whole
    /// *container's* free space to every volume inside it, so summing the
    /// mounts on this Mac would claim a 9 TB disk. Preboot, VM, Update and
    /// Data are not browsable — Finder shows one entry per container, and so
    /// do we.
    static func volumes() -> [DiskVolume] {
        let keys: Set<URLResourceKey> = [
            .volumeNameKey, .volumeIsBrowsableKey,
            .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
        ]

        let mounts = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(keys), options: []) ?? []

        return mounts.compactMap { url in
            guard let v = try? url.resourceValues(forKeys: keys),
                  v.volumeIsBrowsable == true,
                  let total = v.volumeTotalCapacity, total > 0
            else { return nil }

            // `forImportantUsage` counts purgeable space, which is what Finder
            // shows. Plain `volumeAvailableCapacity` reads lower and makes
            // users think we disagree with the Finder.
            let available = v.volumeAvailableCapacityForImportantUsage.map(Int.init)
                ?? v.volumeAvailableCapacity ?? 0

            return DiskVolume(name: v.volumeName ?? url.lastPathComponent,
                              total: total, available: available)
        }
    }

    /// Cumulative bytes read and written, summed across every block device.
    ///
    /// `IOBlockStorageDriver` exposes a `Statistics` dictionary. The keys are
    /// undocumented but have been stable for a decade, and it's a plain
    /// property read rather than a user client — so it works even under the
    /// App Sandbox.
    static func blockStorageTotals() -> (read: UInt64, written: UInt64) {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOBlockStorageDriver"),
            &iterator) == KERN_SUCCESS
        else { return (0, 0) }
        defer { IOObjectRelease(iterator) }

        var totalRead: UInt64 = 0
        var totalWritten: UInt64 = 0

        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }

            guard let raw = IORegistryEntryCreateCFProperty(
                service, "Statistics" as CFString, kCFAllocatorDefault, 0)
            else { continue }

            // Parse into plain values here: CF types are non-Sendable and must
            // not escape.
            // `as? NSDictionary` is a free toll-free bridge. `as? [String: Any]`
            // deep-converts every key and value into Swift types, which showed
            // up as the single hottest thing in the app.
            guard let stats = raw.takeRetainedValue() as? NSDictionary else { continue }
            totalRead    += (stats["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
            totalWritten += (stats["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
        }

        return (totalRead, totalWritten)
    }
}

extension DiskReader: MetricReader {}

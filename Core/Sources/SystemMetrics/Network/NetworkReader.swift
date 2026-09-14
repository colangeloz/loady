import Foundation

/// Interface byte counters from `sysctl(NET_RT_IFLIST2)`.
///
/// **Not `getifaddrs`.** That returns `if_data`, whose byte counters are
/// `UInt32` — they wrap at 4 GiB and keep wrapping, so on a machine that has
/// been up a while the reported total is the real one modulo 4 GiB. Measured
/// on this Mac: `getifaddrs` and `NET_RT_IFLIST2` agreed at 2.91 GiB, one
/// gigabyte short of the ceiling, and would have diverged after it.
///
/// The trap is that *packet* counts are fine either way, and so are throughput
/// rates until the moment of a wrap — so the bug survives casual testing and
/// only shows up as a wrong cumulative total on a long-lived machine.
/// `NET_RT_IFLIST2` returns `if_msghdr2`, carrying `if_data64`.
public final class NetworkReader {

    private var previous: [String: (in: UInt64, out: UInt64)] = [:]
    private var previousInstant: UInt64?

    public init() {}

    public func read() -> NetworkSample? {
        guard let counters = Self.counters() else { return nil }

        let now = DispatchTime.now().uptimeNanoseconds
        let seconds = previousInstant.map { Double(now &- $0) / 1_000_000_000 } ?? 0

        let interfaces = counters.map { entry -> NetworkInterface in
            let before = previous[entry.name]
            return NetworkInterface(
                name: entry.name,
                bytesIn: entry.bytesIn,
                bytesOut: entry.bytesOut,
                bytesInPerSecond: before.map {
                    NetworkMath.rate(before: $0.in, after: entry.bytesIn, seconds: seconds)
                } ?? 0,
                bytesOutPerSecond: before.map {
                    NetworkMath.rate(before: $0.out, after: entry.bytesOut, seconds: seconds)
                } ?? 0,
                isLoopback: entry.isLoopback
            )
        }

        previous = Dictionary(uniqueKeysWithValues:
            counters.map { ($0.name, (in: $0.bytesIn, out: $0.bytesOut)) })
        previousInstant = now

        return NetworkSample(interfaces: interfaces)
    }

    // MARK: sysctl

    private struct Entry {
        let name: String
        let bytesIn: UInt64
        let bytesOut: UInt64
        let isLoopback: Bool
    }

    /// Walks the routing-table message buffer, which is a sequence of
    /// variable-length messages rather than an array — each header carries its
    /// own length, and the interface name follows the struct as a `sockaddr_dl`.
    private static func counters() -> [Entry]? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]

        // The two-call idiom: ask for the size, then the data. The size can
        // change between the calls if an interface appears, which is why the
        // second call's returned length is the one trusted below.
        var length = 0
        guard sysctl(&mib, 6, nil, &length, nil, 0) == 0, length > 0 else { return nil }

        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, 6, &buffer, &length, nil, 0) == 0 else { return nil }

        var entries: [Entry] = []
        buffer.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var offset = 0

            while offset + MemoryLayout<if_msghdr>.size <= length {
                let header = base.advanced(by: offset)
                    .assumingMemoryBound(to: if_msghdr.self).pointee
                let messageLength = Int(header.ifm_msglen)
                guard messageLength > 0 else { break }
                defer { offset += messageLength }

                // The buffer also carries address messages; only RTM_IFINFO2
                // has the 64-bit counters.
                guard header.ifm_type == RTM_IFINFO2,
                      offset + MemoryLayout<if_msghdr2>.size <= length else { continue }

                let message = base.advanced(by: offset)
                    .assumingMemoryBound(to: if_msghdr2.self).pointee
                let link = base.advanced(by: offset + MemoryLayout<if_msghdr2>.size)
                    .assumingMemoryBound(to: sockaddr_dl.self).pointee

                let nameLength = Int(link.sdl_nlen)
                guard nameLength > 0 else { continue }
                var storage = link.sdl_data
                let name = withUnsafeBytes(of: &storage) { bytes in
                    String(decoding: bytes.prefix(nameLength), as: UTF8.self)
                }

                entries.append(Entry(
                    name: name,
                    bytesIn: message.ifm_data.ifi_ibytes,
                    bytesOut: message.ifm_data.ifi_obytes,
                    isLoopback: (message.ifm_flags & IFF_LOOPBACK) != 0
                ))
            }
        }
        return entries
    }
}

extension NetworkReader: MetricReader {}

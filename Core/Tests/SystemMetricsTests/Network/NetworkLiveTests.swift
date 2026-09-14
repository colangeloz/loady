import Testing
import Foundation
@testable import SystemMetrics

/// Cross-checks the reader against `netstat -ibn`, which reports the same
/// 64-bit counters. Skipped unless `LOADY_LIVE=1`.
@Suite("Network live", .enabled(if: ProcessInfo.processInfo.environment["LOADY_LIVE"] != nil))
struct NetworkLiveTests {

    @Test func matchesNetstat() throws {
        let sample = try #require(NetworkReader().read())
        let primary = try #require(sample.primary)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        process.arguments = ["-ibn"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()

        // The <Link#n> row carries the interface totals.
        let row = output.split(separator: "\n").first {
            let f = $0.split(separator: " ", omittingEmptySubsequences: true)
            return f.count > 9 && f[0] == primary.name && f[2].hasPrefix("<Link")
        }
        let fields = try #require(row).split(separator: " ", omittingEmptySubsequences: true)
        let netstatIn = try #require(UInt64(fields[6]))

        print("  interface \(primary.name)")
        print("  loady   ibytes \(primary.bytesIn)")
        print("  netstat ibytes \(netstatIn)")

        // Traffic continues between the two reads, so they cannot be identical.
        // Anything within a few megabytes is the same counter; a 4 GiB-modulo
        // disagreement would be the getifaddrs bug.
        let difference = primary.bytesIn > netstatIn
            ? primary.bytesIn - netstatIn : netstatIn - primary.bytesIn
        print("  difference \(difference) bytes")
        #expect(difference < 16_000_000)
    }
}

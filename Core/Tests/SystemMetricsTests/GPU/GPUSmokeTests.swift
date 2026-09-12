import Testing
import Foundation
@testable import SystemMetrics

/// Prints a live reading. Not an assertion — a way to eyeball real hardware
/// output, since the numbers this reader produces cannot be asserted against
/// fixed values on a machine whose GPU is genuinely doing work.
/// Skipped unless `LOADY_LIVE=1`, so CI — where a VM may have no GPU at all —
/// never depends on hardware being present.
@Suite("GPU live", .enabled(if: ProcessInfo.processInfo.environment["LOADY_LIVE"] != nil))
struct GPULiveTests {
    @Test func dump() throws {
        let count = Int(ProcessInfo.processInfo.environment["LOADY_LIVE_READS"] ?? "5") ?? 5
        let reader = GPUReader()
        _ = reader.read()   // baseline; its window is unbounded

        var readings: [Double] = []
        for i in 1...count {
            Thread.sleep(forTimeInterval: 1)
            let sample = try #require(reader.read())
            for d in sample.devices {
                let pct = d.utilization.map { String(format: "%5.1f%%", $0 * 100) } ?? "  nil"
                let tiler = d.tilerUtilization.map { String(format: "%5.1f%%", $0 * 100) } ?? "  nil"
                if let u = d.utilization { readings.append(u * 100) }
                print("read \(i): \(d.name) [\(d.vendor.rawValue)] util=\(pct) tiler=\(tiler) "
                      + "inUse=\((d.inUseMemory ?? 0) / 1_048_576)MB "
                      + "temp=\(d.temperatureCelsius.map { "\($0)C" } ?? "n/a")")
            }
        }
        if !readings.isEmpty {
            let mean = readings.reduce(0, +) / Double(readings.count)
            print(String(format: "summary: min %.2f%%  mean %.2f%%  max %.2f%%  (n=%d)",
                         readings.min()!, mean, readings.max()!, readings.count))
        }
    }
}

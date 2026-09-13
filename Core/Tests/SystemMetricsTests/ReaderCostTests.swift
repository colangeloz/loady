import Testing
import Foundation
@testable import SystemMetrics

/// What one sample of each reader costs. Not an assertion about absolute
/// speed — that varies by machine — but a way to see which reader dominates
/// the sampling budget, and to catch a regression that makes one of them
/// orders of magnitude worse.
@Suite("Reader cost", .enabled(if: ProcessInfo.processInfo.environment["LOADY_LIVE"] != nil))
struct ReaderCostTests {

    private func measure(_ name: String, iterations: Int = 50, _ body: () -> Void) {
        body()   // warm up: first calls allocate and establish baselines
        let start = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations { body() }
        let elapsed = DispatchTime.now().uptimeNanoseconds - start
        let perCall = Double(elapsed) / Double(iterations) / 1_000_000
        // `%s` expects a C string; a Swift String there is a segfault.
        let padded = name.padding(toLength: 8, withPad: " ", startingAt: 0)
        print("  \(padded) \(String(format: "%7.3f", perCall)) ms/read")
    }

    @Test func costPerRead() {
        let cpu = CPUReader()
        let memory = MemoryReader()
        let disk = DiskReader()
        let gpu = GPUReader()

        measure("cpu") { _ = cpu.read() }
        measure("memory") { _ = memory.read() }
        measure("disk") { _ = disk.read() }
        measure("gpu") { _ = gpu.read() }
    }
}

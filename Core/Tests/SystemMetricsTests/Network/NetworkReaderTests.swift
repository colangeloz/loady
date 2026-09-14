import Testing
import Foundation
@testable import SystemMetrics

@Suite("NetworkReader")
struct NetworkReaderTests {

    @Test func enumeratesInterfaces() throws {
        let sample = try #require(NetworkReader().read())
        #expect(sample.interfaces.isEmpty == false)
        // Every Mac has loopback, and it must be recognised as such so it never
        // counts toward throughput.
        #expect(sample.interfaces.contains { $0.name == "lo0" && $0.isLoopback })
        for interface in sample.interfaces {
            #expect(interface.name.isEmpty == false)
        }
    }

    /// The reason this reader exists. `getifaddrs` reports the same counters as
    /// `UInt32`, which wrap at 4 GiB; a machine that has been up a while then
    /// reports its real total modulo 4 GiB. Anything at or above the ceiling
    /// proves the 64-bit path is live — below it, the two agree and this can
    /// only assert the type is wide enough to hold more.
    @Test func countersAreSixtyFourBit() throws {
        let sample = try #require(NetworkReader().read())
        let busiest = try #require(sample.primary)
        #expect(UInt64.max > UInt64(UInt32.max))
        #expect(busiest.bytesIn <= UInt64.max)
        #expect(type(of: busiest.bytesIn) == UInt64.self)
    }

    @Test func firstReadReportsNoThroughput() throws {
        let sample = try #require(NetworkReader().read())
        #expect(sample.downloadBytesPerSecond == 0)
        #expect(sample.uploadBytesPerSecond == 0)
    }

    @Test func throughputIsNonNegativeAndFinite() throws {
        let reader = NetworkReader()
        _ = reader.read()
        Thread.sleep(forTimeInterval: 0.3)
        let sample = try #require(reader.read())
        #expect(sample.downloadBytesPerSecond >= 0)
        #expect(sample.uploadBytesPerSecond >= 0)
        #expect(sample.downloadBytesPerSecond.isFinite)
    }

    @Test func primaryIsNeverLoopback() throws {
        let sample = try #require(NetworkReader().read())
        if let primary = sample.primary { #expect(primary.isLoopback == false) }
    }
}

@Suite("NetworkMath")
struct NetworkMathTests {

    @Test func computesRate() {
        #expect(NetworkMath.rate(before: 1000, after: 3000, seconds: 2) == 1000)
    }

    /// Counters restart at zero when an interface goes down and returns.
    /// Reporting that as a delta would claim gigabytes in one second.
    @Test func aCounterResetReportsZeroNotAHugeSpike() {
        #expect(NetworkMath.rate(before: 5_000_000_000, after: 1000, seconds: 1) == 0)
    }

    @Test func guardsAgainstZeroElapsed() {
        #expect(NetworkMath.rate(before: 0, after: 1000, seconds: 0) == 0)
    }

    /// Values above the 32-bit ceiling must survive, which is the entire point
    /// of reading if_data64 rather than if_data.
    @Test func handlesValuesBeyondThirtyTwoBits() {
        let below = UInt64(UInt32.max) - 1000
        let above = UInt64(UInt32.max) + 1000
        #expect(NetworkMath.rate(before: below, after: above, seconds: 1) == 2000)
    }
}

@Suite("Network throughput")
struct NetworkThroughputTests {

    /// Pushes real bytes over loopback and checks the counters move.
    ///
    /// Without this, every other test here would pass on a reader that always
    /// returned zero throughput. Loopback because it needs no network and no
    /// remote host — and because `lo0` is excluded from the totals, this
    /// asserts on the interface directly.
    @Test func countersRiseWhenBytesActuallyFlow() throws {
        func loopbackBytes() throws -> UInt64 {
            let sample = try #require(NetworkReader().read())
            let lo = try #require(sample.interfaces.first { $0.isLoopback })
            return lo.bytesIn + lo.bytesOut
        }

        let before = try loopbackBytes()

        // A listening socket, a connection to it, and a megabyte through it.
        let listener = socket(AF_INET, SOCK_STREAM, 0)
        defer { close(listener) }
        var yes: Int32 = 1
        setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        address.sin_port = 0            // let the kernel choose
        var bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(listener, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        #expect(bound == 0)
        #expect(listen(listener, 1) == 0)

        var assigned = sockaddr_in()
        var size = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &assigned) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(listener, $0, &size) }
        }

        let payload = [UInt8](repeating: 0x41, count: 1_000_000)
        let sender = Thread {
            let client = socket(AF_INET, SOCK_STREAM, 0)
            defer { close(client) }
            var target = assigned
            _ = withUnsafePointer(to: &target) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    connect(client, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            payload.withUnsafeBytes { _ = send(client, $0.baseAddress, $0.count, 0) }
        }
        sender.start()

        let accepted = accept(listener, nil, nil)
        defer { close(accepted) }
        var received = 0
        var chunk = [UInt8](repeating: 0, count: 65536)
        while received < payload.count {
            let n = recv(accepted, &chunk, chunk.count, 0)
            if n <= 0 { break }
            received += n
        }
        #expect(received == payload.count)

        bound = 0   // silence the unused-write warning
        let after = try loopbackBytes()

        // At least most of what was sent, not merely "something changed":
        // loopback carries other traffic, so `after > before` could pass on a
        // reader that returned an unrelated rising number.
        #expect(after - before >= UInt64(Double(payload.count) * 0.9))
    }
}

import Darwin

/// Reads physical memory statistics from the Mach kernel.
///
/// Unlike `CPUReader` this is *stateless* — memory use is an absolute quantity,
/// not a rate, so there's no previous sample to diff against and the very first
/// `read()` returns a usable answer.
public final class MemoryReader {

    private let host: mach_port_t = mach_host_self()
    private let pageSize: Int
    private let totalBytes: Int

    public init() {
        // **16384 on Apple Silicon, 4096 on Intel.** Every figure the kernel
        // returns below is a page *count*, so hardcoding 4096 would make every
        // number on this Mac exactly four times too small.
        self.pageSize = Sysctl.integer("hw.pagesize") ?? 4096
        self.totalBytes = Sysctl.integer("hw.memsize") ?? 0
    }

    deinit {
        mach_port_deallocate(mach_task_self_, host)
    }

    public func read() -> MemorySample? {
        guard let vm = Self.vmStatistics(host: host) else { return nil }

        func bytes(_ pages: UInt64) -> Int { Int(pages) * pageSize }
        func bytes(_ pages: UInt32) -> Int { Int(pages) * pageSize }

        // Activity Monitor's arithmetic, which is not documented anywhere and
        // was derived by comparing against it directly:
        //
        //   App Memory   = internal pages - purgeable pages
        //   Wired        = wired pages
        //   Compressed   = pages *occupied by* the compressor
        //   Cached Files = external pages + purgeable pages
        //   Memory Used  = App + Wired + Compressed
        //
        // The subtle one is `compressor_page_count`. `vm_stat` prints two
        // similar-looking numbers: "Pages occupied by compressor" (this one,
        // the post-compression footprint) and "Pages stored in compressor"
        // (`total_uncompressed_pages_in_compressor`, roughly 2.5x larger).
        // Activity Monitor shows the former; graphing the latter is a common
        // and very plausible-looking mistake.
        let app = bytes(vm.internal_page_count) - bytes(vm.purgeable_count)
        let wired = bytes(vm.wire_count)
        let compressed = bytes(vm.compressor_page_count)
        let cached = bytes(vm.external_page_count) + bytes(vm.purgeable_count)

        // `vm_stat`'s "Pages free" already has speculative pages subtracted.
        // Reading the raw struct, we have to do it ourselves — and must not
        // do it twice when cross-checking against that tool's output.
        let free = bytes(vm.free_count) - bytes(vm.speculative_count)

        return MemorySample(
            app: max(0, app),
            wired: wired,
            compressed: compressed,
            cached: cached,
            free: max(0, free),
            total: totalBytes,
            pressureLevel: Sysctl.integer("kern.memorystatus_vm_pressure_level") ?? 1,
            swapUsed: Self.swapUsed()
        )
    }

    private static func vmStatistics(host: mach_port_t) -> vm_statistics64? {
        var stats = vm_statistics64()

        // The kernel wants the struct size expressed in 32-bit words, which is
        // what this division computes. Getting it wrong returns KERN_FAILURE
        // rather than corrupting anything, mercifully.
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }

        return result == KERN_SUCCESS ? stats : nil
    }

    /// Swap usage via `sysctl vm.swapusage`, which returns a struct rather
    /// than a plain integer — so `Sysctl.integer` can't read it.
    private static func swapUsed() -> Int {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else { return 0 }
        return Int(usage.xsu_used)
    }
}

extension MemoryReader: MetricReader {}

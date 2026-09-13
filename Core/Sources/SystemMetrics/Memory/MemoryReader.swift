import Darwin

/// Physical memory from the Mach kernel. Stateless — memory is an absolute
/// quantity, so the first `read()` is already usable.
public final class MemoryReader {

    private let host: mach_port_t = mach_host_self()
    private let pageSize: Int
    private let totalBytes: Int

    public init() {
        // Page counts below, and the page is 16K on Apple Silicon, 4K on Intel.
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

        // Activity Monitor's arithmetic, undocumented, derived by comparison:
        //
        //   App Memory   = internal - purgeable
        //   Wired        = wired
        //   Compressed   = pages *occupied by* the compressor
        //   Cached Files = external + purgeable
        //   Memory Used  = App + Wired + Compressed
        //
        // `compressor_page_count` is the occupied footprint. The other
        // similar-looking figure, `total_uncompressed_pages_in_compressor`, is
        // ~2.5x larger and is not what Activity Monitor shows.
        let app = bytes(vm.internal_page_count) - bytes(vm.purgeable_count)
        let wired = bytes(vm.wire_count)
        let compressed = bytes(vm.compressor_page_count)
        let cached = bytes(vm.external_page_count) + bytes(vm.purgeable_count)

        // `vm_stat` already subtracts speculative pages; the raw struct does not.
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

        // Size in 32-bit words, not bytes. Wrong value returns KERN_FAILURE.
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

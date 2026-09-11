import Darwin

/// Reads per-core CPU load from the Mach kernel.
///
/// Stateful by necessity: load is a difference between two points in time, so
/// the reader remembers the previous snapshot. The first `read()` after
/// creation returns `nil` — there is nothing to compare against yet. That is a
/// contract, not a failure.
///
/// Deliberately a `class`, not a `struct`, and deliberately **not** `Sendable`:
/// it owns a Mach port. Refusing the `Sendable` conformance is what makes the
/// compiler stop this type being shared across threads by accident.
public final class CPUReader {

    private var previous: [CoreTicks]?

    /// `mach_host_self()` hands out a *send right* every time it's called, and
    /// each one must be given back. Calling it once per read and never
    /// deallocating leaks a port right per sample — 86,400 a day at 1 Hz.
    /// So we take one right, keep it, and release it in `deinit`.
    private let host: mach_port_t = mach_host_self()

    public init() {}

    deinit {
        mach_port_deallocate(mach_task_self_, host)
    }

    /// Samples the kernel and returns load since the previous call.
    /// Returns `nil` on the first call, and if the kernel call fails.
    public func read() -> CPUSample? {
        guard let current = Self.readTicks(host: host) else { return nil }
        defer { previous = current }

        guard let previous, previous.count == current.count else { return nil }

        let loads = zip(previous, current).map(CPUMath.load(from:to:))
        return CPUSample(cores: loads)
    }

    /// Pulls raw per-core counters out of the kernel.
    ///
    /// `host_processor_info` allocates a buffer on our behalf and hands back a
    /// raw pointer. Nothing frees it for us — that's what the `vm_deallocate`
    /// in the `defer` is for. Forgetting it leaks a few hundred bytes per
    /// sample, which at 1 Hz is a slow but real memory leak.
    private static func readTicks(host: mach_port_t) -> [CoreTicks]? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            host,
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &info,
            &infoCount
        )

        guard result == KERN_SUCCESS, let info else { return nil }

        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: info)),
                vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)
            )
        }

        // The buffer is flat: four counters per CPU, one after another.
        // CPU_STATE_MAX is 4 — user, system, idle, nice.
        let states = Int(CPU_STATE_MAX)

        return (0 ..< Int(cpuCount)).map { cpu in
            let base = cpu * states
            // The kernel types these as signed Int32, but they're really
            // unsigned counters. `bitPattern:` reinterprets rather than
            // converting, so values past 2^31 don't come back negative.
            return CoreTicks(
                user:   UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]),
                system: UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]),
                idle:   UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]),
                nice:   UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)])
            )
        }
    }
}

// CPUReader already has the shape the protocol wants, so the conformance is
// empty. Note it is NOT declared Sendable — that refusal is what makes the
// compiler confine it to whichever Sampler owns it.
extension CPUReader: MetricReader {}

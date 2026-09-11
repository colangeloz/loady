import Foundation   // String(format:) and .padding() live here, not in the stdlib
import SystemMetrics

// SwiftPM treats a file literally named `main.swift` as the entry point:
// top-level code runs directly, no `func main()` needed.

let profile = SystemProfile.current()

// `loady-probe --bench` measures what one sample actually costs. A system
// monitor that shows up in its own "top processes" list has failed.
if CommandLine.arguments.contains("--bench") {
    let reader = CPUReader()
    _ = reader.read()

    let iterations = 1000
    let start = DispatchTime.now().uptimeNanoseconds
    for _ in 0 ..< iterations { _ = reader.read() }
    let elapsed = DispatchTime.now().uptimeNanoseconds - start

    let perSample = Double(elapsed) / Double(iterations)
    print(String(format: "\n  %.1f µs per sample", perSample / 1000))
    print(String(format: "  %.4f%% of one core at 1 Hz\n", perSample / 1_000_000_000 * 100))
    exit(0)
}

func gigabytes(_ bytes: Int) -> String {
    String(format: "%.0f GB", Double(bytes) / 1_073_741_824)
}

func bar(_ fraction: Double, width: Int = 24) -> String {
    let filled = Int((fraction * Double(width)).rounded())
    return String(repeating: "█", count: max(0, min(width, filled)))
         + String(repeating: "·", count: max(0, width - filled))
}

func pct(_ fraction: Double) -> String {
    String(format: "%5.1f%%", fraction * 100)
}

print("""

  \(profile.cpuBrand)
  \(profile.modelIdentifier)

  architecture   \(profile.isAppleSilicon ? "Apple Silicon" : "Intel")\
\(profile.isTranslated ? " (running under Rosetta)" : "")
  memory         \(gigabytes(profile.memoryBytes))
  page size      \(profile.pageSize) bytes
  cores          \(profile.cpu.totalCores) physical\
\(profile.cpu.threadsPerCore > 1 ? ", \(profile.cpu.totalCores * profile.cpu.threadsPerCore) logical (SMT)" : "")

  core tiers     \(profile.cpu.isHeterogeneous ? "heterogeneous" : "homogeneous")
""")

for tier in profile.cpu.tiers {
    let r = tier.cpuIndices
    print("    \(tier.name.padding(toLength: 14, withPad: " ", startingAt: 0))"
        + "\(tier.coreCount) cores   cpu \(r.lowerBound)...\(r.upperBound - 1)")
}

// ── live CPU load ────────────────────────────────────────────────────────
// Load is a difference between two instants, so the first read only
// establishes a baseline and returns nil. Sample once a second after that.

// ── memory ───────────────────────────────────────────────────────────────
if let mem = MemoryReader().read() {
    func gb(_ b: Int) -> String { String(format: "%6.2f GB", Double(b) / 1_073_741_824) }

    print("""

  memory
    app           \(gb(mem.app))
    wired         \(gb(mem.wired))
    compressed    \(gb(mem.compressed))
    ─────────────────────────
    used          \(gb(mem.used))   \(String(format: "%.1f%%", mem.usedFraction * 100))
    cached files  \(gb(mem.cached))
    free          \(gb(mem.free))
    total         \(gb(mem.total))
    swap used     \(gb(mem.swapUsed))
    pressure      \(mem.pressure)
""")
}

print("\n  sampling CPU for 5 seconds — compare against `top -l 2 -o cpu`\n")

let reader = CPUReader()
_ = reader.read()   // baseline; discarded by contract

for _ in 1 ... 5 {
    Thread.sleep(forTimeInterval: 1.0)

    guard let sample = reader.read() else {
        print("  (no sample)")
        continue
    }

    var line = "  total \(pct(sample.busy))  \(bar(sample.busy))"
    for tier in profile.cpu.tiers {
        line += "   \(tier.name) \(pct(sample.busy(for: tier)))"
    }
    print(line)
}

print("")

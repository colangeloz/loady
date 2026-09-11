import Foundation   // String(format:) and .padding() live here, not in the stdlib
import SystemMetrics

// SwiftPM treats a file literally named `main.swift` as the entry point:
// top-level code runs directly, no `func main()` needed.

let profile = SystemProfile.current()

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

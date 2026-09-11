import Foundation   // String(format:) and .padding() live here, not in the stdlib
import SystemMetrics

// SwiftPM treats a file literally named `main.swift` as the entry point:
// top-level code runs directly, no `func main()` needed.

let profile = SystemProfile.current()

func gigabytes(_ bytes: Int) -> String {
    String(format: "%.0f GB", Double(bytes) / 1_073_741_824)
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
    let range = tier.cpuIndices
    print("    \(tier.name.padding(toLength: 14, withPad: " ", startingAt: 0))"
        + "\(tier.coreCount) cores   cpu \(range.lowerBound)...\(range.upperBound - 1)")
}

print("")

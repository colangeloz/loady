import Foundation

enum Format {
    /// Bytes as a short human string. `ByteCountFormatter` is the system one
    /// and matches what Finder and Activity Monitor show, including their
    /// base-10 GB convention — rolling our own would disagree with every other
    /// number on the machine.
    static func bytes(_ value: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .memory
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: Int64(value))
    }

    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    /// Throughput for the menu bar, where there is room for about five
    /// characters: "0", "84K", "1.2M". Deliberately not `ByteCountFormatter`,
    /// which produces "1.2 MB" — too wide, and the unit changing width makes
    /// the item resize as traffic varies.
    static func rateCompact(_ bytesPerSecond: Double) -> String {
        let value = max(0, bytesPerSecond)
        switch value {
        case ..<1_000:          return "0"
        case ..<1_000_000:      return "\(Int(value / 1_000))K"
        case ..<10_000_000:     return String(format: "%.1fM", value / 1_000_000)
        default:                return "\(Int(value / 1_000_000))M"
        }
    }

    /// Throughput with room to spell it out, for the popup.
    static func rate(_ bytesPerSecond: Double) -> String {
        "\(bytes(Int(max(0, bytesPerSecond))))/s"
    }
}

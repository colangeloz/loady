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
}

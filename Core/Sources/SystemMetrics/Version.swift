/// Comparison of dotted version strings, e.g. "0.10.0" against "0.9.2".
///
/// Pure and separate from any networking so it can be tested exhaustively —
/// the failure everyone ships is string comparison, under which "0.10.0" is
/// older than "0.9.2" because "1" sorts before "9".
public struct SemanticVersion: Sendable, Comparable, CustomStringConvertible {

    public let components: [Int]
    public let description: String

    /// Accepts a leading "v" and any number of components. Anything that is
    /// not a run of digits ends parsing, so "1.2.0-beta.1" is read as 1.2.0 —
    /// pre-release ordering is not something this app needs to get right.
    public init?(_ raw: String) {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("v") || text.hasPrefix("V") { text.removeFirst() }

        var parsed: [Int] = []
        for part in text.split(separator: ".") {
            let digits = part.prefix { $0.isNumber }
            guard !digits.isEmpty, let value = Int(digits) else { break }
            parsed.append(value)
            if digits.count != part.count { break }
        }
        guard !parsed.isEmpty else { return nil }
        components = parsed
        description = text
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        // Compared position by position, treating a missing component as zero,
        // so "1.2" and "1.2.0" are equal rather than one being older.
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let l = index < lhs.components.count ? lhs.components[index] : 0
            let r = index < rhs.components.count ? rhs.components[index] : 0
            if l != r { return l < r }
        }
        return false
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}

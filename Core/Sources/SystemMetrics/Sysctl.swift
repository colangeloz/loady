import Darwin

/// Reads values from the kernel's `sysctl` key-value store.
///
/// A caseless `enum` used purely as a namespace. It has no cases, so it can
/// never be instantiated — `Sysctl()` is a compile error. That's the Swift
/// idiom for "this is a place to hang functions, not a thing you make".
public enum Sysctl {

    /// Reads a string value, or `nil` if the key doesn't exist.
    public static func string(_ name: String) -> String? {
        // sysctl uses the classic C two-call idiom: ask how big the answer is,
        // then ask again with a buffer that size. Passing `nil` for the buffer
        // means "just tell me the length".
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }

        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }

        // `size` counts the trailing NUL — 8 bytes for the 7-character
        // "Mac17,9". Decoding it as-is would leave an invisible \0 on the end.
        if buffer.last == 0 { buffer.removeLast() }

        return String(decoding: buffer, as: UTF8.self)
    }

    /// Reads an integer value, or `nil` if the key doesn't exist.
    ///
    /// The width varies per key and is not documented anywhere convenient:
    /// `hw.ncpu` is 32-bit, `hw.memsize` is 64-bit. Reading a 32-bit key into
    /// a 64-bit variable leaves the top four bytes as garbage, so we ask the
    /// kernel how wide the value is and decode accordingly.
    public static func integer(_ name: String) -> Int? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0 else { return nil }

        switch size {
        case 4:
            var value: UInt32 = 0
            guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
            return Int(value)
        case 8:
            var value: UInt64 = 0
            guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
            return Int(value)
        default:
            return nil
        }
    }

    /// Reads a flag key as a boolean. The kernel expresses these as 0 or 1.
    public static func flag(_ name: String) -> Bool? {
        guard let value = integer(name) else { return nil }
        return value != 0
    }
}

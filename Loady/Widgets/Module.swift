import AppKit

/// The metric modules Loady can show, and how each presents itself.
///
/// Every module gets an SF Symbol. They're template images, which means the
/// menu bar tints them automatically for contrast against whatever wallpaper
/// is behind Tahoe's transparent bar — the same treatment Apple's own items
/// get. A bitmap or a coloured icon would not participate in that.
enum Module: String, CaseIterable, Sendable {
    case cpu
    case memory
    case disk
    case network
    case gpu
    case sensors

    /// Which modules are on before the user has said otherwise. CPU and
    /// memory are what people actually glance at; the rest are opt-in so the
    /// default item stays narrow enough not to be truncated by Tahoe.
    var enabledByDefault: Bool {
        switch self {
        case .cpu, .memory: true
        default: false
        }
    }

    var displayName: String {
        switch self {
        case .cpu:     "CPU"
        case .memory:  "Memory"
        case .disk:    "Disk"
        case .network: "Network"
        case .gpu:     "GPU"
        case .sensors: "Sensors"
        }
    }

    /// Verified present on macOS 14+. SF Symbols has no GPU glyph — Apple's own
    /// keyword index maps "gpu" to `cpu` and `memorychip`, both already taken —
    /// so the GPU borrows `cube.transparent`.
    var symbolName: String {
        switch self {
        case .cpu:     "cpu"
        case .memory:  "memorychip"
        case .disk:    "internaldrive"
        case .network: "network"
        case .gpu:     "cube.transparent"
        case .sensors: "thermometer.medium"
        }
    }

    /// A menu-bar-sized template image, or `nil` if the symbol is missing on
    /// this OS version — in which case the caller should just omit the icon
    /// rather than showing a broken-image placeholder.
    func icon(pointSize: CGFloat = 12) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: displayName)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true   // tint follows the menu bar, not a fixed colour
        return image
    }
}

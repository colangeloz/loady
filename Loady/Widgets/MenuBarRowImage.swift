import AppKit

/// The whole menu bar row as one template image.
///
/// Not subviews: NSStatusItem refreshes its replicant copies by snapshotting
/// the button's view tree, and on Tahoe that re-arms itself — measured at ~480
/// layout and draw passes a second, ~36% of a core. An image is one blit.
enum MenuBarRowImage {

    static let iconSize: CGFloat = 15
    static let gap: CGFloat = 3
    /// Fixed, so the item never resizes as digits change.
    static let valueWidth: CGFloat = 30
    static let moduleSpacing: CGFloat = 6
    static let inset: CGFloat = 6

    private static let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)

    static func compact(height: CGFloat) -> NSImage {
        make(entries: [(icon: appIcon, text: nil)], height: height)
    }

    private static let appIcon: NSImage? =
        LoadyGlyph.image(size: NSSize(width: 17, height: 11))

    static func width(moduleCount: Int, hasValues: Bool) -> CGFloat {
        guard moduleCount > 0 else { return inset * 2 }
        let each = hasValues ? iconSize + gap + valueWidth : iconSize
        return inset * 2
            + CGFloat(moduleCount) * each
            + CGFloat(moduleCount - 1) * moduleSpacing
    }

    /// A `nil` text draws the icon alone. `dimmed` is for the placeholder
    /// shown when nothing is enabled, not for compact mode.
    static func make(entries: [(icon: NSImage?, text: String?)],
                     height: CGFloat,
                     dimmed: Bool = false) -> NSImage {
        let hasValues = entries.contains { $0.text != nil }
        let size = NSSize(width: width(moduleCount: max(entries.count, 1), hasValues: hasValues),
                          height: height)

        let image = NSImage(size: size, flipped: false) { _ in
            var x = inset
            for entry in entries {
                if let icon = entry.icon {
                    let box = NSRect(x: x, y: (height - iconSize) / 2,
                                     width: iconSize, height: iconSize)
                    icon.draw(in: box.fitting(icon.size), from: .zero,
                              operation: .sourceOver, fraction: dimmed ? 0.5 : 1)
                }
                guard let text = entry.text else {
                    x += iconSize + moduleSpacing
                    continue
                }
                let attributed = NSAttributedString(
                    string: text,
                    attributes: [.font: font, .foregroundColor: NSColor.black]
                )
                let textSize = attributed.size()
                attributed.draw(at: NSPoint(x: x + iconSize + gap,
                                            y: (height - textSize.height) / 2))
                x += iconSize + gap + valueWidth + moduleSpacing
            }
            return true
        }

        // Template: the menu bar tints it, hence the opaque black above.
        image.isTemplate = true
        return image
    }
}

private extension NSRect {
    /// Centres `size` inside the receiver without distorting its aspect ratio.
    func fitting(_ size: NSSize) -> NSRect {
        guard size.width > 0, size.height > 0 else { return self }
        let scale = min(width / size.width, height / size.height)
        let fitted = NSSize(width: size.width * scale, height: size.height * scale)
        return NSRect(x: midX - fitted.width / 2, y: midY - fitted.height / 2,
                      width: fitted.width, height: fitted.height)
    }
}

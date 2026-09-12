import AppKit

/// Renders the whole menu bar row — every enabled module's icon and readout —
/// into a single template image.
///
/// Why an image rather than a view hierarchy: `NSStatusItem` keeps "replicant"
/// copies of its item, and refreshes them by snapshotting the button's view
/// tree with `cacheDisplayInRect:toBitmapImageRep:`. With custom subviews that
/// snapshot re-runs layout and draws every `NSTextField` through the full cell
/// machinery — bezel configuration, text tightening, appearance resolution —
/// and it re-arms itself, measured at ~480 passes a second for a value that
/// changes once a second. Handing AppKit a finished image collapses that to a
/// single blit, the same path a plain `title` takes.
enum MenuBarRowImage {

    static let iconSize: CGFloat = 15
    static let gap: CGFloat = 3
    /// Fixed, so the item never resizes as digits change.
    static let valueWidth: CGFloat = 30
    static let moduleSpacing: CGFloat = 6
    static let inset: CGFloat = 6

    private static let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)

    static func width(moduleCount: Int, hasValues: Bool) -> CGFloat {
        guard moduleCount > 0 else { return inset * 2 }
        let each = hasValues ? iconSize + gap + valueWidth : iconSize
        return inset * 2
            + CGFloat(moduleCount) * each
            + CGFloat(moduleCount - 1) * moduleSpacing
    }

    /// - Parameter entries: icon and readout per module, in display order.
    ///   A `nil` text draws the icon alone, used for the placeholder item.
    static func make(entries: [(icon: NSImage?, text: String?)], height: CGFloat) -> NSImage {
        let hasValues = entries.contains { $0.text != nil }
        let size = NSSize(width: width(moduleCount: max(entries.count, 1), hasValues: hasValues),
                          height: height)

        let image = NSImage(size: size, flipped: false) { _ in
            var x = inset
            for entry in entries {
                if let icon = entry.icon {
                    let box = NSRect(x: x, y: (height - iconSize) / 2,
                                     width: iconSize, height: iconSize)
                    // The icon-only placeholder is dimmed, to read as a handle
                    // back to the popup rather than as a metric.
                    icon.draw(in: box.fitting(icon.size), from: .zero,
                              operation: .sourceOver,
                              fraction: entry.text == nil ? 0.5 : 1)
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

        // Template, so the menu bar tints it for whatever is behind it — the
        // reason every colour above is drawn as opaque black.
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

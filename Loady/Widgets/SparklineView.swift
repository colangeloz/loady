import AppKit

/// A compact bar chart of recent values, sized for the menu bar.
///
/// Monochrome on purpose: Tahoe's menu bar is transparent and tints its
/// content for legibility, so a coloured widget disappears on a light
/// wallpaper and clashes with the system's own items.
final class SparklineView: NSView {

    // MARK: Appearance

    private let barWidth: CGFloat = 3
    private let barGap: CGFloat = 1.5
    private let barCount: Int = 5

    /// An idle machine shows dots rather than an empty box.
    private let minimumBarHeight: CGFloat = 2.5

    /// Vertical inset from the menu bar's full height.
    private let verticalInset: CGFloat = 5

    // MARK: State

    /// Newest value last. Each entry is 0...1.
    private var values: [Double] = []

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barGap,
            height: NSStatusBar.system.thickness
        )
    }

    override var isFlipped: Bool { false }

    // MARK: Input

    func append(_ value: Double) {
        values.append(min(max(value, 0), 1))
        if values.count > barCount {
            values.removeFirst(values.count - barCount)
        }
        needsDisplay = true
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard !values.isEmpty else { return }

        // Resolve at draw time. Caching a CGColor across an appearance
        // change is the classic bug in this kind of view.
        let ink = NSColor.labelColor

        let usableHeight = bounds.height - (verticalInset * 2)
        let step = barWidth + barGap

        // Right-align, so the newest bar always sits at the same place and the
        // chart fills leftwards as history accumulates.
        let firstX = bounds.width - CGFloat(values.count) * step + barGap

        for (index, value) in values.enumerated() {
            let height = max(minimumBarHeight, CGFloat(value) * usableHeight)

            let rect = NSRect(
                // Snapping to whole pixels keeps 3pt bars crisp instead of
                // smeared across two columns on a Retina display.
                x: (firstX + CGFloat(index) * step).rounded(),
                y: verticalInset,
                width: barWidth,
                height: height.rounded()
            )

            let age = Double(values.count - 1 - index) / Double(max(barCount - 1, 1))
            let alpha = 1.0 - (age * 0.55)

            ink.withAlphaComponent(alpha).setFill()

            NSBezierPath(roundedRect: rect, xRadius: barWidth / 2, yRadius: barWidth / 2)
                .fill()
        }
    }

    /// Re-draw when the user switches between light and dark.
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

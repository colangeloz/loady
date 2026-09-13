import AppKit

enum LoadyGlyph {

    /// Baseline at 0.51, peak at 1, valley at 0 — y up.
    private static let points: [CGPoint] = [
        CGPoint(x: 0.00, y: 0.51),
        CGPoint(x: 0.30, y: 0.51),
        CGPoint(x: 0.33, y: 0.43),   // the small notch before the upstroke
        CGPoint(x: 0.36, y: 0.51),
        CGPoint(x: 0.43, y: 1.00),   // peak
        CGPoint(x: 0.51, y: 0.00),   // valley
        CGPoint(x: 0.57, y: 0.40),
        CGPoint(x: 0.61, y: 0.55),   // the small bump after it
        CGPoint(x: 0.66, y: 0.51),
        CGPoint(x: 1.00, y: 0.51),
    ]

    static func image(size: NSSize, lineWidth: CGFloat = 1.4) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            let inset = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            let path = NSBezierPath()
            for (index, point) in points.enumerated() {
                let p = NSPoint(x: inset.minX + point.x * inset.width,
                                y: inset.minY + point.y * inset.height)
                index == 0 ? path.move(to: p) : path.line(to: p)
            }
            path.lineWidth = lineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            NSColor.black.setStroke()
            path.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}

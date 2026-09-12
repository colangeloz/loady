import AppKit

/// One module's readout inside the menu bar item: icon plus a short value.
final class MenuBarModuleView: NSView {

    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "--")

    private let iconSize: CGFloat = 15
    private let gap: CGFloat = 3
    private let labelWidth: CGFloat = 30   // fixed: "100%" is the widest case
    private lazy var labelHeight: CGFloat = { label.sizeToFit(); return label.frame.height }()

    init(module: Module, placeholder: Bool = false) {
        super.init(frame: .zero)

        // Template image, so the menu bar tints it like its own items.
        iconView.image = module.icon(pointSize: 13)
        iconView.contentTintColor = .labelColor
        iconView.imageScaling = .scaleProportionallyDown
        iconView.alphaValue = placeholder ? 0.5 : 1

        // Monospaced digits stop the item resizing as values change.
        label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        label.textColor = .labelColor
        label.alignment = .left
        label.isHidden = placeholder

        addSubview(iconView)
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: label.isHidden ? iconSize : iconSize + gap + labelWidth,
            height: NSStatusBar.system.thickness
        )
    }

    override func layout() {
        super.layout()
        let height = bounds.height
        iconView.frame = NSRect(x: 0, y: 0, width: iconSize, height: height)
        label.frame = NSRect(
            x: iconSize + gap,
            y: (height - labelHeight) / 2,
            width: labelWidth,
            height: labelHeight
        )
    }

    func update(with presentation: MenuBarPresentation?) {
        let text = presentation?.text ?? "--"
        guard text != label.stringValue else { return }   // avoid needless invalidation
        label.stringValue = text
        needsLayout = true
    }
}

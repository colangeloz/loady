import AppKit
import SwiftUI

/// A borderless floating panel used instead of `NSPopover`.
///
/// Two reasons `NSPopover` doesn't work here:
///
///  1. **The arrow is not optional.** There is no public API to hide it.
///  2. **It recentres when its content resizes.** Toggling a module changes the
///     panel's height, and the popover animates itself to a new position —
///     which reads as the whole panel jumping.
///
/// A panel we position ourselves fixes both: no chrome at all, and we anchor
/// the *top* edge so height changes only ever grow downward.
@MainActor
final class PopupPanel: NSPanel {

    private let hosting: NSHostingView<AnyView>
    private var dismissMonitor: Any?
    private let onDismiss: () -> Void

    /// Gap below the menu bar, matching the system's own menus.
    private let topGap: CGFloat = 4
    private let cornerRadius: CGFloat = 16

    init(content: AnyView, onDismiss: @escaping () -> Void = {}) {
        self.onDismiss = onDismiss
        hosting = NSHostingView(rootView: content)
        hosting.translatesAutoresizingMaskIntoConstraints = false

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 268, height: 200),
            // `.nonactivatingPanel` lets the panel take clicks without making
            // the whole app active — essential for an LSUIElement app, which
            // would otherwise steal focus from whatever you were using.
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        // ARC owns this panel: NSWindow otherwise releases itself on close,
        // which with our own strong reference is an over-release.
        isReleasedWhenClosed = false

        isFloatingPanel = true
        level = .popUpMenu              // above normal windows, below the menu bar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        animationBehavior = .none       // we control appearance; no system fade
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        contentView = Self.makeBackground(hosting: hosting, cornerRadius: cornerRadius)
    }

    // MARK: Presentation

    var isOpen: Bool { isVisible }

    func show(below button: NSStatusBarButton) {
        guard let buttonWindow = button.window, let screen = buttonWindow.screen else { return }

        // Let SwiftUI decide the height from its content.
        let size = hosting.fittingSize
        setContentSize(size)

        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))

        var x = buttonRect.midX - size.width / 2
        let margin: CGFloat = 8
        x = min(max(x, screen.visibleFrame.minX + margin),
                screen.visibleFrame.maxX - size.width - margin)

        // Anchor the TOP edge. Cocoa's origin is bottom-left, so a taller panel
        // extends downward from here rather than shifting the whole frame.
        let y = buttonRect.minY - topGap - size.height

        setFrameOrigin(NSPoint(x: x.rounded(), y: y.rounded()))

        // macOS caches the shadow shape for a borderless transparent window and
        // does not recompute it on resize. Without this the previous, larger
        // rectangular shadow is left behind as a hard-edged grey block.
        invalidateShadow()

        orderFrontRegardless()
        startWatchingForDismissal()
    }

    /// Not named `close`: `NSWindow.close()` already exists, and a subclass
    /// `close(...)` with every parameter defaulted does not shadow it, so the
    /// body silently never runs. This is also the only place the monitor can be
    /// removed — Swift 6 bars a nonisolated `deinit` from touching `NSEvent`'s
    /// `Any` token.
    func dismiss() {
        stopWatchingForDismissal()

        // A live NSHostingView keeps re-evaluating its body even off screen.
        hosting.rootView = AnyView(EmptyView())

        orderOut(nil)
        close()
    }

    /// Re-measures after the content's height changes, keeping the top edge
    /// where it is. Without this, the panel would clip its own content when a
    /// module is toggled on.
    func resizeKeepingTopEdge() {
        guard isVisible else { return }
        let size = hosting.fittingSize
        guard size.height != frame.height || size.width != frame.width else { return }

        let top = frame.maxY
        setContentSize(size)
        setFrameOrigin(NSPoint(x: frame.origin.x, y: top - size.height))
        invalidateShadow()
    }

    // MARK: Click-outside dismissal

    private func startWatchingForDismissal() {
        guard dismissMonitor == nil else { return }
        // A *global* monitor sees clicks in other applications, which a
        // borderless panel otherwise has no way to learn about.
        dismissMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in self?.onDismiss() }
        }
    }

    private func stopWatchingForDismissal() {
        if let dismissMonitor { NSEvent.removeMonitor(dismissMonitor) }
        dismissMonitor = nil
    }

    /// Deliberately false.
    ///
    /// Clicking a key-capable borderless panel makes it key, and
    /// `NSGlassEffectView` renders differently for active vs inactive windows —
    /// which showed up as a grey block behind the content on mouse-down. Mouse
    /// events still reach a nonactivating panel, so controls keep working; only
    /// keyboard focus is lost, which a click-away panel doesn't need.
    override var canBecomeKey: Bool { false }

    /// Liquid Glass where the OS has it, the older material everywhere else.
    ///
    /// `NSGlassEffectView` is macOS 26 only. `NSVisualEffectView` is the
    /// previous generation and genuinely cannot reproduce the Tahoe look —
    /// which is why the panel looked unlike the system's own popups.
    private static func makeBackground(
        hosting: NSView,
        cornerRadius: CGFloat
    ) -> NSView {
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = cornerRadius
            hosting.translatesAutoresizingMaskIntoConstraints = true
            glass.contentView = hosting
            return glass
        }

        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = cornerRadius
        effect.layer?.cornerCurve = .continuous   // squircle, as Apple draws them
        effect.layer?.masksToBounds = true

        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        hosting.layer?.cornerRadius = cornerRadius
        hosting.layer?.cornerCurve = .continuous
        hosting.layer?.masksToBounds = true

        effect.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: effect.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])
        return effect
    }
}

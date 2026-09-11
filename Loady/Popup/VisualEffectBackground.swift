import SwiftUI
import AppKit

/// Bridges `NSVisualEffectView` into SwiftUI.
///
/// This is the real system material — the same one Finder sidebars and Control
/// Centre use. It samples and blurs what's actually behind the window, adapts
/// to light and dark automatically, and honours "Reduce transparency" in
/// Accessibility settings without any code from us.
///
/// SwiftUI's own `.ultraThinMaterial` is close, but `NSVisualEffectView` gives
/// direct control over the material, the blending mode, and whether it stays
/// active when the window loses focus.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode

        // `.active` keeps the blur alive even when the app isn't frontmost.
        // The default, `.followsWindowActiveState`, makes the panel go flat
        // and grey the instant you click elsewhere — which for a menu bar
        // popup is almost always the wrong look.
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
    }
}

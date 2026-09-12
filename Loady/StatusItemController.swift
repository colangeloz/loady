import AppKit
import Foundation
import SwiftUI
import SystemMetrics

/// Owns the single menu bar item and keeps it showing whichever modules are
/// enabled, side by side.
@MainActor
final class StatusItemController {

    private let statusItem: NSStatusItem
    private let profile = SystemProfile.current()
    private let registry: ModuleRegistry

    /// Built on open, torn down on close. A live `NSHostingView` keeps
    /// re-running SwiftUI layout on every observable change even when its
    /// window is hidden, which costs more than rebuilding it each time.
    private var panel: PopupPanel?

    /// Which modules the current image was built for. Compared each tick so
    /// the item rebuilds when the user toggles something. Optional rather than
    /// empty, because "no modules enabled" is a real state that still needs a
    /// first build — of the placeholder.
    private var laidOutModules: [Module]?

    /// Icons are stable for the life of a layout, so they're resolved once per
    /// rebuild rather than once per tick.
    private var icons: [NSImage?] = []

    private var refreshTask: Task<Void, Never>?

    // Last values written to AppKit. Each costs an IPC round-trip, so they're
    // only written when they actually change.
    private var lastLength: CGFloat = -1
    private var lastSummary = ""
    private var lastTexts: [String?] = []

    init() {
        registry = ModuleRegistry(profile: profile)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "me.colangelo.loady.statusitem"

        configureButton()
        registry.sync()
        startRefreshing()
    }

    deinit {
        refreshTask?.cancel()
    }

    // MARK: Menu bar item

    private func configureButton() {
        guard let button = statusItem.button else { return }

        // The button gets an image, never subviews.
        //
        // NSStatusItem mirrors its item into "replicants" and refreshes them by
        // snapshotting the button's view tree with cacheDisplayInRect. On Tahoe
        // that snapshot re-arms itself continuously: measured at ~480 layout
        // and draw passes a second, ~36% of a core, for a readout that changes
        // once a second — and it ran at that rate no matter what we wrote, or
        // whether we wrote anything at all. Rendering the row ourselves and
        // assigning one image gives AppKit nothing to walk. Do not put custom
        // subviews in this button.
        button.imagePosition = .imageOnly
        button.image = MenuBarRowImage.make(entries: [], height: NSStatusBar.system.thickness)

        button.target = self
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    /// Re-resolves the module icons when the enabled set changes. Not on every
    /// tick: icons are stable for a given layout, and looking up six SF Symbols
    /// a second to draw the same glyphs would be wasted work.
    private func rebuildIfNeeded() {
        let current = registry.enabled.map(\.module)
        guard current != laidOutModules else { return }
        laidOutModules = current
        registry.sync()

        // Only if it's actually on screen — never create one to resize it.
        panel?.resizeKeepingTopEdge()

        // An empty item would be invisible and unclickable, so keep a single
        // icon as a handle back to the popup.
        icons = current.isEmpty
            ? [Module.cpu.icon(pointSize: 13)]
            : current.map { $0.icon(pointSize: 13) }

        lastTexts = []   // force the next refresh to redraw
    }

    private func startRefreshing() {
        // Display refresh is deliberately separate from sampling. Modules tick
        // at their own rates (CPU 1s, memory 2s); this just reads whatever
        // each currently has and paints it.
        refreshTask = Task { [weak self] in
            let clock = ContinuousClock()
            var deadline = clock.now

            while !Task.isCancelled {
                deadline = deadline.advanced(by: .seconds(1))
                try? await clock.sleep(until: deadline, tolerance: .milliseconds(100))
                if clock.now - deadline > .seconds(4) { deadline = clock.now }

                guard let self else { return }
                self.rebuildIfNeeded()
                self.refresh()
            }
        }
    }

    private func refresh() {
        // nil text means "icon only", used for the placeholder item.
        let texts: [String?] = registry.enabled.isEmpty
            ? [nil]
            : registry.enabled.map { $0.presentation?.text ?? "--" }

        // Redrawing and reassigning the image is an IPC round-trip, so it
        // happens only when a readout actually changed.
        if texts != lastTexts {
            lastTexts = texts
            let height = NSStatusBar.system.thickness
            let entries = Array(zip(icons, texts)).map { (icon: $0.0, text: $0.1) }
            let image = MenuBarRowImage.make(entries: entries, height: height)
            statusItem.button?.image = image

            if image.size.width != lastLength {
                lastLength = image.size.width
                statusItem.length = image.size.width
            }
        }

        let summary = registry.enabled
            .compactMap { m in m.presentation.map { "\(m.module.displayName) \($0.text)" } }
            .joined(separator: ", ")

        if summary != lastSummary {
            lastSummary = summary
            statusItem.button?.toolTip = summary
            statusItem.button?.setAccessibilityLabel(summary.isEmpty ? "Loady" : summary)
        }
    }

    // MARK: Clicks

    @objc private func handleClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Quit Loady",
                     action: #selector(NSApplication.terminate(_:)),
                     keyEquivalent: "q")

        // Assign, click to present, then clear — a permanently-assigned menu
        // would intercept left-clicks and the popover could never open.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }

        if let panel, panel.isOpen {
            closePanel()
            return
        }

        let panel = PopupPanel(
            content: AnyView(PopupView(registry: registry)),
            onDismiss: { [weak self] in self?.closePanel() }
        )
        self.panel = panel
        panel.show(below: button)
    }

    private func closePanel() {
        panel?.dismiss()
        panel = nil
    }
}

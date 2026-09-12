import AppKit
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

    /// One row of module readouts inside the button.
    private let stack = NSStackView()

    /// Which modules the current layout was built for. Compared each tick so
    /// the item rebuilds when the user toggles something.
    private var laidOutModules: [Module] = []

    private var refreshTask: Task<Void, Never>?

    // Last values written to AppKit. Each of these costs a layout solve or an
    // IPC round-trip, so they're only written when they actually change.
    private var lastLength: CGFloat = -1
    private var lastSummary = ""

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

        stack.orientation = .horizontal
        stack.spacing = 10
        stack.alignment = .centerY
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 6, bottom: 0, right: 6)
        stack.translatesAutoresizingMaskIntoConstraints = false

        button.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: button.centerYAnchor),
        ])

        button.target = self
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    /// Rebuilds the row when the enabled set changes. Not on every tick —
    /// tearing down and rebuilding views once a second would be wasteful and
    /// would make the item visibly flicker.
    private func rebuildIfNeeded() {
        let current = registry.enabled.map(\.module)
        guard current != laidOutModules else { return }
        laidOutModules = current
        registry.sync()

        // Only if it's actually on screen — never create one to resize it.
        panel?.resizeKeepingTopEdge()

        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        for module in registry.enabled {
            stack.addArrangedSubview(MenuBarModuleView(module: module.module))
        }

        // An empty item would be invisible and unclickable, so keep a single
        // icon as a handle back to the popup.
        if registry.enabled.isEmpty {
            stack.addArrangedSubview(MenuBarModuleView(module: .cpu, placeholder: true))
        }

        statusItem.length = stack.fittingSize.width
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
        for (view, module) in zip(stack.arrangedSubviews, registry.enabled) {
            (view as? MenuBarModuleView)?.update(with: module.presentation)
        }

        let width = stack.fittingSize.width
        if width != lastLength {
            lastLength = width
            statusItem.length = width
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
        panel?.close()
        panel = nil
    }
}

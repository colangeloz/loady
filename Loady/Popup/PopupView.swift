import SwiftUI
import UniformTypeIdentifiers

struct PopupView: View {
    let registry: ModuleRegistry

    /// Re-reads on every change to any module's `isEnabled`, so toggling one
    /// updates the sections immediately.
    private var enabled: [any MetricModule] { registry.enabled }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // What to show, above what is shown; the actions stay at the
            // bottom, which is where macOS menus put them.
            ModuleToggleRow(registry: registry)
            Divider()

            if enabled.isEmpty {
                Text("No modules enabled")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(Array(enabled.enumerated()), id: \.element.module) { index, module in
                    module.popupSection()
                    if index < enabled.count - 1 { Divider() }
                }
            }

            Divider()
            PopupActions()
        }
        .padding(16)
        .frame(width: 268)
        // The panel is borderless, so AppKit's focus ring gets drawn as a
        // square around the whole content instead of following the corners.
        .focusEffectDisabled()
    }
}

/// Preferences, Activity Monitor and Quit.
///
/// On their own row rather than sharing one with the module toggles: six
/// toggles plus three actions needs about 260pt and the popup is 268pt wide
/// with padding, so they collided — the Spacer between them collapsed and
/// "Quit" wrapped mid-word.
private struct PopupActions: View {
    var body: some View {
        HStack(spacing: 4) {
            Spacer(minLength: 0)

            if let icon = ActivityMonitor.icon {
                Button { ActivityMonitor.open() } label: {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .frame(width: 26, height: 22)
                }
                .buttonStyle(.plain)
                .help("Open Activity Monitor")
            }

            Button { PreferencesWindowController.shared.show() } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .frame(width: 26, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Preferences")

            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                // Never wrap: it is the last thing in the row, so any shortfall
                // lands here first.
                .lineLimit(1)
                .fixedSize()
        }
    }
}

/// The bottom strip: one tappable icon per module, lit when enabled.
///
/// This replaces a settings window entirely for now. Six icons in a row is
/// faster to use than a preferences pane, and it keeps the toggle next to the
/// thing it toggles.
struct ModuleToggleRow: View {
    let registry: ModuleRegistry

    private let step: CGFloat = 30   // icon width plus HStack spacing

    @State private var dragging: Module?
    @State private var offset: CGFloat = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(registry.all, id: \.module) { module in
                ModuleToggle(module: module, isDragging: dragging == module.module)
                    .offset(x: shift(for: module.module))
                    .animation(dragging == module.module ? nil : .spring(response: 0.25, dampingFraction: 1.0), value: offset)
                    .zIndex(dragging == module.module ? 1 : 0)
                    .gesture(dragOrTap(module))
            }

            Spacer(minLength: 0)
        }
    }

    /// Where the drag would land, clamped to the row.
    private func destination(from: Int) -> Int {
        min(max(from + Int((offset / step).rounded()), 0), registry.order.count - 1)
    }

    /// The dragged icon follows the cursor; everything between its old and new
    /// slot slides one place to make room.
    ///
    /// This is visual only — the real order is committed on release. Reordering
    /// the ForEach mid-gesture recreates the dragged view, which cancels the
    /// gesture and snaps it home.
    private func shift(for module: Module) -> CGFloat {
        guard let dragging, let from = registry.order.firstIndex(of: dragging) else { return 0 }
        if module == dragging { return offset }

        guard let index = registry.order.firstIndex(of: module) else { return 0 }
        let to = destination(from: from)

        if from < to, index > from, index <= to { return -step }
        if from > to, index < from, index >= to { return step }
        return 0
    }

    /// One gesture decides both outcomes.
    ///
    /// A Button plus a simultaneous drag means both fire — you reorder *and*
    /// toggle. With `minimumDistance: 0` this sees the press from the start and
    /// only commits to a drag once it passes the threshold; anything shorter is
    /// a click.
    private func dragOrTap(_ entry: any MetricModule) -> some Gesture {
        let module = entry.module
        return DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard dragging != nil || abs(value.translation.width) > 4 else { return }
                dragging = module
                offset = value.translation.width
            }
            .onEnded { _ in
                if dragging == module {
                    if let from = registry.order.firstIndex(of: module) {
                        let to = destination(from: from)
                        if to != from { registry.move(module, to: to) }
                    }
                } else {
                    entry.isEnabled.toggle()   // never became a drag
                }
                dragging = nil
                offset = 0
            }
    }
}

private struct ModuleToggle: View {
    @Bindable var module: AnyBindableModule
    let isDragging: Bool

    init(module: any MetricModule, isDragging: Bool) {
        self.module = AnyBindableModule(module)
        self.isDragging = isDragging
    }

    var body: some View {
        Image(systemName: module.symbolName)
            .font(.system(size: 12, weight: .medium))
            .frame(width: 26, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(module.isEnabled ? Color.accentColor.opacity(0.18) : .clear)
            )
            .foregroundStyle(module.isEnabled ? Color.accentColor : .secondary)
            .contentShape(Rectangle())
            .help(module.displayName)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(module.displayName)
        .accessibilityValue(module.isEnabled ? "on" : "off")
        .scaleEffect(isDragging ? 1.12 : 1)
        .shadow(color: .black.opacity(isDragging ? 0.2 : 0), radius: 4, y: 2)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isDragging)
    }
}

/// Bridges `any MetricModule` into something `@Bindable` accepts.
///
/// `@Observable` gives us change tracking, but an existential (`any Protocol`)
/// can't be used with `@Bindable` directly. This thin wrapper forwards the one
/// property the toggle needs to write.
@MainActor
@Observable
final class AnyBindableModule {
    private let wrapped: any MetricModule

    init(_ wrapped: any MetricModule) { self.wrapped = wrapped }

    var id: Module { wrapped.module }
    var rawValue: String { wrapped.module.rawValue }
    var symbolName: String { wrapped.module.symbolName }
    var displayName: String { wrapped.module.displayName }

    var isEnabled: Bool {
        get { wrapped.isEnabled }
        set { wrapped.isEnabled = newValue }
    }
}

#if DEBUG
#Preview("Panel") {
    PopupView(registry: ModuleRegistry(previewModules: [
        CPUModule.preview(),
        MemoryModule.preview(),
        DiskModule.preview(),
    ]))
}
#endif

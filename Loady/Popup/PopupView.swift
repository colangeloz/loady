import SwiftUI

struct PopupView: View {
    let registry: ModuleRegistry

    /// Re-reads on every change to any module's `isEnabled`, so toggling one
    /// updates the sections immediately.
    private var enabled: [any MetricModule] { registry.enabled }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
            ModuleToggleRow(registry: registry)
        }
        .padding(16)
        .frame(width: 268)
    }
}

/// The bottom strip: one tappable icon per module, lit when enabled.
///
/// This replaces a settings window entirely for now. Six icons in a row is
/// faster to use than a preferences pane, and it keeps the toggle next to the
/// thing it toggles.
struct ModuleToggleRow: View {
    let registry: ModuleRegistry

    var body: some View {
        HStack(spacing: 4) {
            ForEach(registry.all, id: \.module) { module in
                ModuleToggle(module: module)
            }

            Spacer()

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

            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

private struct ModuleToggle: View {
    @Bindable var module: AnyBindableModule

    init(module: any MetricModule) {
        self.module = AnyBindableModule(module)
    }

    var body: some View {
        Button {
            module.isEnabled.toggle()
        } label: {
            Image(systemName: module.symbolName)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 26, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(module.isEnabled ? Color.accentColor.opacity(0.18) : .clear)
                )
                .foregroundStyle(module.isEnabled ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .help(module.displayName)
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

    var symbolName: String { wrapped.module.symbolName }
    var displayName: String { wrapped.module.displayName }

    var isEnabled: Bool {
        get { wrapped.isEnabled }
        set { wrapped.isEnabled = newValue }
    }
}

import SwiftUI

/// The ⌘, window. Deliberately small: the popup already handles enabling and
/// reordering modules, so this covers only what has nowhere else to live.
struct PreferencesView: View {
    /// Only the width is fixed. Height follows the tab's content, so a tab
    /// with one setting is not a window of empty space.
    ///
    /// A grouped `Form` has no intrinsic height — it expands to fill whatever
    /// it is given, which collapsed this window to 92 points when it was given
    /// nothing. `.fixedSize(vertical:)` on each tab is what makes it report an
    /// ideal height instead.
    static let width: CGFloat = 460

    /// Called with the height the selected tab wants. The window sets its own
    /// frame from this; letting AppKit negotiate it with the hosting view
    /// recurses until it throws.
    let onHeightChange: (CGFloat) -> Void

    @State private var selection: Tab = .general

    private enum Tab: Hashable {
        case general, updates, about

        /// Measured, not computed: a grouped Form has no intrinsic height, and
        /// asking AppKit to work it out is what caused the layout recursion.
        var windowHeight: CGFloat {
            switch self {
            case .general: 150
            case .updates: 210
            case .about:   330
            }
        }
    }

    var body: some View {
        TabView(selection: $selection) {
            GeneralTab()
                .tag(Tab.general)
                .tabItem { Label("General", systemImage: "gearshape") }
            UpdatesTab()
                .tag(Tab.updates)
                .tabItem { Label("Updates", systemImage: "arrow.trianglehead.2.clockwise") }
            AboutTab()
                .tag(Tab.about)
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: Self.width)
        .onChange(of: selection, initial: true) { _, tab in
            onHeightChange(tab.windowHeight)
        }
    }
}

private struct GeneralTab: View {
    @State private var launchAtLogin = LaunchAtLogin.shared

    var body: some View {
        Form {
            Section {
                Toggle("Show values in the menu bar", isOn: Binding(
                    get: { Preferences.shared.menuBarShowsValues },
                    set: { Preferences.shared.menuBarShowsValues = $0 }
                ))

                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.set($0) }
                ))

                if launchAtLogin.needsApprovalInSystemSettings {
                    LabeledContent("") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Turned off in System Settings.")
                                .font(.callout)
                            Button("Open Login Items…") {
                                launchAtLogin.openSystemSettings()
                            }
                        }
                    }
                }

                if let failure = launchAtLogin.failure {
                    Text(failure)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        // The user can revoke this in System Settings without telling the app.
        .onAppear { launchAtLogin.refresh() }
    }
}

private struct UpdatesTab: View {
    @State private var updates = UpdateChecker.shared

    var body: some View {
        Form {
            Section {
                LabeledContent("Current version") {
                    Text(updates.currentVersion).monospacedDigit()
                }
                Toggle("Check for updates automatically",
                       isOn: Binding(get: { updates.checksAutomatically },
                                     set: { updates.checksAutomatically = $0 }))
                Button("Check Now") { updates.check() }
                    .disabled(!updates.canCheck)
            } footer: {
                Text("This is the only part of Loady that uses the network. "
                     + "Off unless you turn it on.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct AboutTab: View {
    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 12) {
            if let icon = NSImage(named: "AppIcon") {
                Image(nsImage: icon)
                    .resizable().frame(width: 72, height: 72)
            }
            Text("Loady").font(.title2).bold()
            Text(version).font(.callout).foregroundStyle(.secondary).monospacedDigit()

            Text("No telemetry. The only network request is the update check, "
                 + "and it is off unless you enable it.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 320)
                // Without this the text truncates rather than wrapping: the
                // frame above constrains the width, and nothing tells SwiftUI
                // the text may take as much height as it needs.
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Link("GitHub", destination: URL(string: "https://github.com/colangeloz/loady")!)
                Link("Releases", destination: URL(string: "https://github.com/colangeloz/loady/releases")!)
            }
            .font(.callout)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

#if DEBUG
#Preview("Preferences") { PreferencesView { _ in } }
#endif

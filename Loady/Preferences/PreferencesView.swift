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

    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: Self.width)
    }
}

private struct GeneralTab: View {
    @State private var launchAtLogin = LaunchAtLogin.shared

    var body: some View {
        Form {
            Section {
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

            HStack {
                Link("GitHub", destination: URL(string: "https://github.com/colangeloz/loady")!)
                Link("Releases", destination: URL(string: "https://github.com/colangeloz/loady/releases")!)
            }
            .font(.callout)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

#if DEBUG
#Preview("Preferences") { PreferencesView() }
#endif

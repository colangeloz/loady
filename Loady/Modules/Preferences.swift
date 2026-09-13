import Foundation

/// Persisted preferences.
///
/// Named `Preferences`, not `Settings`, because SwiftUI already defines a
/// `Settings` scene — and a same-named type in your own module silently wins
/// at the use site, which produces baffling errors far from the definition.
///
/// Deliberately not `@AppStorage`: that scatters string keys across view files,
/// can't be injected for testing, and can't be exported. One store, namespaced
/// keys, one place to look.
@MainActor
@Observable
final class Preferences {

    static let shared = Preferences()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func key(for module: Module) -> String { "module.\(module.rawValue).enabled" }

    func isEnabled(_ module: Module) -> Bool {
        // `object(forKey:)` rather than `bool(forKey:)` so we can tell
        // "never set" from "explicitly set to false" and apply a default.
        guard let stored = defaults.object(forKey: key(for: module)) as? Bool else {
            return module.enabledByDefault
        }
        return stored
    }

    func setEnabled(_ enabled: Bool, for module: Module) {
        defaults.set(enabled, forKey: key(for: module))
    }

    /// Off by default, deliberately: the app makes no network connections
    /// until someone asks it to.
    var checkForUpdatesOnLaunch: Bool {
        get { defaults.bool(forKey: "updates.checkOnLaunch") }
        set { defaults.set(newValue, forKey: "updates.checkOnLaunch") }
    }

    private let orderKey = "module.order"

    /// Display order. Modules added in a later version won't be in a stored
    /// order, so they're appended rather than silently dropped.
    var moduleOrder: [Module] {
        get {
            let stored = (defaults.array(forKey: orderKey) as? [String] ?? [])
                .compactMap(Module.init(rawValue:))
            let missing = Module.allCases.filter { !stored.contains($0) }
            return stored + missing
        }
        set {
            defaults.set(newValue.map(\.rawValue), forKey: orderKey)
        }
    }
}

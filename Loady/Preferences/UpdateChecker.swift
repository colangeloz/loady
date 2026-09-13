import Foundation
import SystemMetrics

/// Asks GitHub whether a newer release exists.
///
/// **This is the only code in Loady that touches the network, and it is off
/// until you turn it on.** Nothing here runs at launch unless `checkOnLaunch`
/// is enabled, and a manual check happens only when you press the button.
///
/// It reports an update; it does not install one. Installing in place means
/// Sparkle — an appcast, an EdDSA key, and a framework that phones home on a
/// schedule. That trade is worth making deliberately, not by accident.
@MainActor
@Observable
final class UpdateChecker {

    static let shared = UpdateChecker()

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String, url: URL)
        case failed(String)
    }

    private(set) var state: State = .idle

    /// Persisted, and false by default. Opting in is what makes the network
    /// claim in the README precise rather than a lie.
    var checkOnLaunch: Bool {
        didSet { Preferences.shared.checkForUpdatesOnLaunch = checkOnLaunch }
    }

    private let releasesAPI = URL(string: "https://api.github.com/repos/colangeloz/loady/releases/latest")!

    private init() {
        checkOnLaunch = Preferences.shared.checkForUpdatesOnLaunch
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    func checkIfEnabled() async {
        guard checkOnLaunch else { return }
        await check()
    }

    func check() async {
        state = .checking
        do {
            var request = URLRequest(url: releasesAPI)
            request.timeoutInterval = 15
            // GitHub rejects unidentified clients, and asking for the versioned
            // media type stops a future API default from changing the shape.
            request.setValue("Loady/\(currentVersion)", forHTTPHeaderField: "User-Agent")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                state = .failed("GitHub returned \(code)")
                return
            }

            let release = try JSONDecoder().decode(Release.self, from: data)
            guard let latest = SemanticVersion(release.tagName),
                  let current = SemanticVersion(currentVersion) else {
                state = .failed("Could not read the version number")
                return
            }

            if latest > current, let url = URL(string: release.htmlURL) {
                state = .available(version: release.tagName, url: url)
            } else {
                state = .upToDate
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private struct Release: Decodable {
        let tagName: String
        let htmlURL: String

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }
}

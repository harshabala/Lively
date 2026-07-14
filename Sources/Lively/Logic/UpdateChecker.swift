import Foundation
import Combine
import AppKit

/// Lightweight GitHub Releases update check. Surfaces availability in the UI;
/// does not download or install automatically.
@MainActor
public final class UpdateChecker: ObservableObject {
    public static let shared = UpdateChecker()

    @Published public private(set) var availableVersion: String?
    @Published public private(set) var releaseURL: URL?
    @Published public private(set) var lastChecked: Date?
    @Published public private(set) var isChecking = false
    @Published public private(set) var lastError: String?

    public var isUpdateAvailable: Bool { availableVersion != nil }

    private let releasesAPI = URL(string: "https://api.github.com/repos/harshabala/Lively/releases/latest")!
    private let releasesPage = URL(string: "https://github.com/harshabala/Lively/releases/latest")!

    private init() {}

    public func checkIfEnabled() async {
        guard AppPreferences.shared.checkForUpdates else { return }
        await checkNow()
    }

    public func checkNow() async {
        guard !isChecking else { return }
        isChecking = true
        lastError = nil
        defer { isChecking = false }

        var request = URLRequest(url: releasesAPI)
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        request.setValue("Lively/\(version)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 12

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.httpCookieAcceptPolicy = .never
        config.urlCache = nil
        let session = URLSession(configuration: config)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }
            // 404 = no releases published yet — not an error for users.
            if http.statusCode == 404 {
                availableVersion = nil
                releaseURL = nil
                lastChecked = Date()
                LivelyLogger.updater.info("No GitHub releases found yet")
                return
            }
            guard (200..<300).contains(http.statusCode) else {
                lastError = "Update check returned HTTP \(http.statusCode)"
                LivelyLogger.updater.debug(lastError!)
                return
            }
            guard
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let tag = json["tag_name"] as? String
            else {
                lastError = "Could not parse release info"
                return
            }

            let remote = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            let current = version
            lastChecked = Date()

            if isRemoteNewer(remote: remote, current: current) {
                availableVersion = remote
                if let html = json["html_url"] as? String,
                   let url = URL(string: html),
                   Self.isTrustedGitHubURL(url) {
                    releaseURL = url
                } else {
                    releaseURL = releasesPage
                }
                LivelyLogger.updater.info("Update available: \(tag) (you have \(current))")
            } else {
                availableVersion = nil
                releaseURL = nil
                LivelyLogger.updater.info("Lively is up to date (\(current))")
            }
        } catch {
            lastError = error.localizedDescription
            LivelyLogger.updater.debug("Update check skipped: \(error.localizedDescription)")
        }
    }

    public func openReleasePage() {
        let url = releaseURL.flatMap { Self.isTrustedGitHubURL($0) ? $0 : nil } ?? releasesPage
        NSWorkspace.shared.open(url)
    }

    /// Only allow https://github.com/... (defense-in-depth for json html_url).
    private static func isTrustedGitHubURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" else { return false }
        guard let host = url.host?.lowercased() else { return false }
        return host == "github.com" || host.hasSuffix(".github.com")
    }

    /// Simple dotted-version compare (1.1.1 vs 1.2.0). Non-numeric segments ignored.
    private func isRemoteNewer(remote: String, current: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let c = current.split(separator: ".").compactMap { Int($0) }
        let count = max(r.count, c.count)
        for i in 0..<count {
            let rv = i < r.count ? r[i] : 0
            let cv = i < c.count ? c[i] : 0
            if rv != cv { return rv > cv }
        }
        return false
    }
}

import Foundation
import Combine
import AppKit

/// Lightweight GitHub Releases update check. Surfaces availability in the UI;
/// does not download or install automatically.
///
/// Opt-in only: nothing touches the network unless `checkForUpdates` is on
/// (`checkIfEnabled`) or the user explicitly asks (`checkNow`).
@MainActor
public final class UpdateChecker: ObservableObject {
    public static let shared = UpdateChecker()

    /// Performs one HTTP request. Injected so tests never hit the network.
    public typealias Fetch = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    @Published public private(set) var availableVersion: String?
    @Published public private(set) var releaseURL: URL?
    @Published public private(set) var lastChecked: Date?
    @Published public private(set) var isChecking = false
    @Published public private(set) var lastError: String?

    public var isUpdateAvailable: Bool { availableVersion != nil }

    /// Hard cap on the whole request; GitHub being unreachable must never hang the UI.
    nonisolated static let requestTimeout: TimeInterval = 12

    private let releasesAPI = URL(string: "https://api.github.com/repos/harshabala/Lively/releases/latest")!
    private let releasesPage = URL(string: "https://github.com/harshabala/Lively/releases/latest")!

    private let preferences: AppPreferences
    private let currentVersion: String
    private let fetch: Fetch

    init(
        preferences: AppPreferences = .shared,
        currentVersion: String? = nil,
        fetch: @escaping Fetch = UpdateChecker.liveFetch
    ) {
        self.preferences = preferences
        self.currentVersion = currentVersion
            ?? Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "0"
        self.fetch = fetch
    }

    public func checkIfEnabled() async {
        guard preferences.checkForUpdates else { return }
        await checkNow()
    }

    public func checkNow() async {
        guard !isChecking else { return }
        isChecking = true
        lastError = nil
        defer { isChecking = false }

        var request = URLRequest(url: releasesAPI)
        request.setValue("Lively/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = Self.requestTimeout
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await fetch(request)
        } catch {
            lastError = "Couldn’t reach GitHub. Try again later."
            LivelyLogger.updater.debug("Update check skipped: \(error.localizedDescription)")
            return
        }

        guard let http = response as? HTTPURLResponse else {
            lastError = "Unexpected response from GitHub."
            return
        }
        // 404 = no releases published yet — not an error for users.
        if http.statusCode == 404 {
            availableVersion = nil
            releaseURL = nil
            lastChecked = Date()
            LivelyLogger.updater.info("No GitHub releases found yet")
            return
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = "Update check returned HTTP \(http.statusCode)"
            lastError = message
            LivelyLogger.updater.debug("\(message)")
            return
        }
        guard let release = Self.parseRelease(data) else {
            lastError = "Could not parse release info"
            return
        }

        lastChecked = Date()
        let remote = Self.normalizedVersion(release.tag)
        if Self.isVersion(remote, newerThan: currentVersion) {
            availableVersion = remote
            releaseURL = release.htmlURL.flatMap { Self.isTrustedGitHubURL($0) ? $0 : nil } ?? releasesPage
            LivelyLogger.updater.info("Update available: \(release.tag) (you have \(self.currentVersion))")
        } else {
            availableVersion = nil
            releaseURL = nil
            LivelyLogger.updater.info("Lively is up to date (\(self.currentVersion))")
        }
    }

    public func openReleasePage() {
        let url = releaseURL.flatMap { Self.isTrustedGitHubURL($0) ? $0 : nil } ?? releasesPage
        NSWorkspace.shared.open(url)
    }

    // MARK: - Pure helpers (unit-tested)

    struct Release: Equatable {
        let tag: String
        let htmlURL: URL?
    }

    /// Decodes the subset of the GitHub release payload we use. Returns nil for
    /// junk, HTML error pages, or payloads without a usable tag.
    nonisolated static func parseRelease(_ data: Data) -> Release? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tag = json["tag_name"] as? String,
            !normalizedVersion(tag).isEmpty,
            numericComponents(normalizedVersion(tag)).first != nil
        else { return nil }
        let html = (json["html_url"] as? String).flatMap(URL.init(string:))
        return Release(tag: tag, htmlURL: html)
    }

    /// "v1.2.0" → "1.2.0"; trims whitespace and a leading v/V.
    nonisolated static func normalizedVersion(_ tag: String) -> String {
        var s = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = s.first, first == "v" || first == "V" { s.removeFirst() }
        return s
    }

    /// Only allow https://github.com/... (defense-in-depth for json html_url).
    nonisolated static func isTrustedGitHubURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" else { return false }
        guard let host = url.host?.lowercased() else { return false }
        return host == "github.com" || host.hasSuffix(".github.com")
    }

    /// Numeric dotted-version compare: 1.10.0 > 1.9.0, 1.2 == 1.2.0.
    /// A pre-release suffix ("1.3.0-beta.1") sorts *below* the same release,
    /// so a beta is never offered to someone already on the final build.
    nonisolated static func isVersion(_ remote: String, newerThan current: String) -> Bool {
        let r = numericComponents(remote)
        let c = numericComponents(current)
        guard !r.isEmpty else { return false }
        for i in 0..<max(r.count, c.count) {
            let rv = i < r.count ? r[i] : 0
            let cv = i < c.count ? c[i] : 0
            if rv != cv { return rv > cv }
        }
        // Same numeric core: a final release beats a pre-release, not vice versa.
        return isPrerelease(current) && !isPrerelease(remote)
    }

    nonisolated private static func core(_ version: String) -> Substring {
        let v = normalizedVersion(version)
        return v.split(whereSeparator: { $0 == "-" || $0 == "+" }).first ?? Substring(v)
    }

    nonisolated private static func isPrerelease(_ version: String) -> Bool {
        normalizedVersion(version).contains("-")
    }

    /// Leading integer of each dot-separated core component; stops at the
    /// first component with no leading digits.
    nonisolated static func numericComponents(_ version: String) -> [Int] {
        var out: [Int] = []
        for part in core(version).split(separator: ".") {
            let digits = part.prefix(while: \.isNumber)
            guard let n = Int(digits) else { break }
            out.append(n)
        }
        return out
    }

    // MARK: - Networking

    /// Ephemeral, cookie-less, cache-less session per check; invalidated after
    /// use so no URLSession (and its delegate queue) outlives the request.
    nonisolated static let liveFetch: Fetch = { request in
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = requestTimeout
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        config.urlCache = nil
        config.waitsForConnectivity = false
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }
        return try await session.data(for: request)
    }
}

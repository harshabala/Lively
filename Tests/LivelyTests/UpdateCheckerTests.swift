import Testing
@testable import LivelyCore
import Foundation

@MainActor
struct UpdateCheckerTests {

    // MARK: - Version comparison

    @Test(arguments: [
        ("1.10.0", "1.9.0", true),
        ("1.9.0", "1.10.0", false),
        ("1.2.1", "1.2.0", true),
        ("1.2.0", "1.2.0", false),
        ("1.2", "1.2.0", false),
        ("1.2.0.1", "1.2", true),
        ("2.0.0", "1.99.99", true),
        ("v1.3.0", "1.2.0", true),
        ("1.3.0-beta.1", "1.3.0", false),
        ("1.3.0", "1.3.0-beta.1", true),
        ("1.3.0-rc1", "1.2.0", true),
        ("", "1.2.0", false),
        ("garbage", "1.2.0", false),
    ])
    func versionComparison(remote: String, current: String, expected: Bool) {
        #expect(UpdateChecker.isVersion(remote, newerThan: current) == expected)
    }

    @Test func numericComponentsStopAtNonNumeric() {
        #expect(UpdateChecker.numericComponents("1.4.2") == [1, 4, 2])
        #expect(UpdateChecker.numericComponents("v2.0b.7") == [2, 0, 7])
        #expect(UpdateChecker.numericComponents("1.x.3") == [1])
    }

    // MARK: - Parsing

    @Test func parsesValidRelease() {
        let json = #"{"tag_name":"v1.4.0","html_url":"https://github.com/harshabala/Lively/releases/tag/v1.4.0"}"#
        let release = UpdateChecker.parseRelease(Data(json.utf8))
        #expect(release?.tag == "v1.4.0")
        #expect(release?.htmlURL?.host == "github.com")
    }

    @Test(arguments: [
        "",
        "<html>rate limited</html>",
        "[]",
        #"{"message":"API rate limit exceeded"}"#,
        #"{"tag_name":42}"#,
        #"{"tag_name":"latest"}"#,
    ])
    func rejectsJunkPayloads(_ body: String) {
        #expect(UpdateChecker.parseRelease(Data(body.utf8)) == nil)
    }

    @Test func untrustedReleaseURLsAreRejected() {
        #expect(UpdateChecker.isTrustedGitHubURL(URL(string: "https://github.com/x")!))
        #expect(!UpdateChecker.isTrustedGitHubURL(URL(string: "http://github.com/x")!))
        #expect(!UpdateChecker.isTrustedGitHubURL(URL(string: "https://github.com.evil.io/x")!))
        #expect(!UpdateChecker.isTrustedGitHubURL(URL(string: "https://evilgithub.com/x")!))
    }

    // MARK: - End-to-end with a stubbed network

    private func prefs(enabled: Bool) -> (AppPreferences, UserDefaults, String) {
        let suite = "lively.tests.update.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let prefs = AppPreferences(defaults: defaults)
        prefs.checkForUpdates = enabled
        return (prefs, defaults, suite)
    }

    nonisolated private static func response(_ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://api.github.com")!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    @Test func disabledCheckNeverTouchesNetwork() async {
        let (prefs, defaults, suite) = prefs(enabled: false)
        defer { defaults.removePersistentDomain(forName: suite) }
        let calls = Counter()
        let checker = UpdateChecker(preferences: prefs, currentVersion: "1.0.0") { _ in
            await calls.increment()
            throw URLError(.notConnectedToInternet)
        }
        await checker.checkIfEnabled()
        #expect(await calls.value == 0)
        #expect(checker.lastChecked == nil)
    }

    @Test func newerReleaseIsSurfaced() async {
        let (prefs, defaults, suite) = prefs(enabled: true)
        defer { defaults.removePersistentDomain(forName: suite) }
        let body = Data(#"{"tag_name":"v1.10.0","html_url":"https://evil.example/x"}"#.utf8)
        let checker = UpdateChecker(preferences: prefs, currentVersion: "1.9.0") { request in
            #expect(request.timeoutInterval <= 15)
            return (body, Self.response(200))
        }
        await checker.checkIfEnabled()
        #expect(checker.availableVersion == "1.10.0")
        // Untrusted html_url falls back to the canonical Releases page.
        #expect(checker.releaseURL?.host == "github.com")
        #expect(!checker.isChecking)
    }

    @Test func unreachableGitHubSetsErrorWithoutCrashing() async {
        let (prefs, defaults, suite) = prefs(enabled: true)
        defer { defaults.removePersistentDomain(forName: suite) }
        let checker = UpdateChecker(preferences: prefs, currentVersion: "1.0.0") { _ in
            throw URLError(.timedOut)
        }
        await checker.checkNow()
        #expect(checker.lastError != nil)
        #expect(checker.availableVersion == nil)
        #expect(!checker.isChecking)
    }

    @Test func junkBodyAndServerErrorsAreHandled() async {
        let (prefs, defaults, suite) = prefs(enabled: true)
        defer { defaults.removePersistentDomain(forName: suite) }

        let junk = UpdateChecker(preferences: prefs, currentVersion: "1.0.0") { _ in
            (Data("<html>".utf8), Self.response(200))
        }
        await junk.checkNow()
        #expect(junk.lastError != nil)
        #expect(junk.availableVersion == nil)

        let server = UpdateChecker(preferences: prefs, currentVersion: "1.0.0") { _ in
            (Data(), Self.response(503))
        }
        await server.checkNow()
        #expect(server.lastError?.contains("503") == true)

        let none = UpdateChecker(preferences: prefs, currentVersion: "1.0.0") { _ in
            (Data(), Self.response(404))
        }
        await none.checkNow()
        #expect(none.lastError == nil)
        #expect(none.availableVersion == nil)
    }
}

private actor Counter {
    private(set) var value = 0
    func increment() { value += 1 }
}

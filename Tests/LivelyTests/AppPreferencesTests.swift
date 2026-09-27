import Testing
@testable import LivelyCore
import Foundation

@MainActor
struct AppPreferencesTests {

    private func makeDefaults() -> (UserDefaults, String) {
        let suite = "lively.tests.prefs.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite)!, suite)
    }

    @Test func updateCheckIsOffOnFreshInstall() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let prefs = AppPreferences(defaults: defaults)
        #expect(prefs.checkForUpdates == false)
    }

    @Test func legacyDefaultOnIsResetOnceThenRespected() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        // Builds ≤ 1.2.0 wrote `true` as the first-launch default.
        defaults.set(true, forKey: "prefs.checkForUpdates")
        let migrated = AppPreferences(defaults: defaults)
        #expect(migrated.checkForUpdates == false)

        // After migration an explicit opt-in sticks across launches.
        migrated.checkForUpdates = true
        let relaunched = AppPreferences(defaults: defaults)
        #expect(relaunched.checkForUpdates == true)
    }

    @Test func unknownEnumValuesFallBackToDefaults() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set("ultra", forKey: "prefs.playbackQuality")
        defaults.set("bounce", forKey: "prefs.loopBehavior")
        defaults.set("8k", forKey: "prefs.maxResolution")
        defaults.set("neon", forKey: "prefs.appearance")
        defaults.set(3.0, forKey: "prefs.batteryPauseThreshold")

        let prefs = AppPreferences(defaults: defaults)
        #expect(prefs.playbackQuality == .high)
        #expect(prefs.loopBehavior == .loop)
        #expect(prefs.maxResolution == .matchSource)
        #expect(prefs.appearance == .system)
        #expect(prefs.batteryPauseThreshold == AppPreferences.batteryThresholdRange.lowerBound)
    }

    @Test func legacyFrameRateCapMigratesToMaxResolution() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set("fps30", forKey: "prefs.frameRateCap")
        #expect(AppPreferences(defaults: defaults).maxResolution == .p1080)
    }
}

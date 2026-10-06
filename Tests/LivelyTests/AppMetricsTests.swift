import Testing
@testable import LivelyCore
import Foundation

@MainActor
struct AppMetricsTests {
    private let keys = [
        "wallpaper_applied_once",
        "days_with_wallpaper_active",
        "last_wallpaper_active_date",
    ]

    private func withCleanMetrics(_ body: () -> Void) {
        let d = UserDefaults.standard
        let saved: [(String, Any?)] = keys.map { ($0, d.object(forKey: $0)) }
        defer {
            for (key, value) in saved {
                if let value {
                    d.set(value, forKey: key)
                } else {
                    d.removeObject(forKey: key)
                }
            }
        }
        for key in keys { d.removeObject(forKey: key) }
        body()
    }

    @Test func recordWallpaperAppliedCountsOncePerDay() {
        withCleanMetrics {
            let metrics = AppMetrics.shared
            #expect(metrics.daysWithWallpaperActive == 0)
            metrics.recordWallpaperApplied()
            let afterFirst = metrics.daysWithWallpaperActive
            #expect(afterFirst == 1)
            #expect(metrics.isActivated)
            metrics.recordWallpaperApplied()
            #expect(metrics.daysWithWallpaperActive == afterFirst)
        }
    }
}

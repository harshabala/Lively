import Foundation

@MainActor
public final class AppMetrics {
    public static let shared = AppMetrics()

    private let defaults = UserDefaults.standard

    private let activatedKey = "wallpaper_applied_once"
    private let daysActiveKey = "days_with_wallpaper_active"
    private let lastActiveDateKey = "last_wallpaper_active_date"

    // en_US_POSIX + Gregorian keeps "yyyy-MM-dd" stable across locales.
    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        return f
    }()
    
    private init() {}
    
    public var isActivated: Bool {
        defaults.bool(forKey: activatedKey)
    }

    public var daysWithWallpaperActive: Int {
        defaults.integer(forKey: daysActiveKey)
    }
    
    public func recordWallpaperApplied() {
        if !isActivated {
            defaults.set(true, forKey: activatedKey)
        }
        
        let todayString = dayFormatter.string(from: Date())
        let lastDateString = defaults.string(forKey: lastActiveDateKey)
        
        if lastDateString != todayString {
            let newDays = daysWithWallpaperActive + 1
            defaults.set(newDays, forKey: daysActiveKey)
            defaults.set(todayString, forKey: lastActiveDateKey)
        }
    }
}

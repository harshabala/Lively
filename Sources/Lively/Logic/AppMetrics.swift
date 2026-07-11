import Foundation

// I-3: @MainActor matches actual usage — both call sites (ScreenCardView.onDrop
// and ConfigStore.assign) run on the main thread. This is safer than @unchecked
// Sendable, which promised thread-safety without a lock.
@MainActor
public final class AppMetrics {
    public static let shared = AppMetrics()
    
    private let defaults = UserDefaults.standard
    
    private let activatedKey = "wallpaper_applied_once"
    private let daysActiveKey = "days_with_wallpaper_active"
    private let lastActiveDateKey = "last_wallpaper_active_date"
    
    // I-1/I-2: Create DateFormatter once; en_US_POSIX + Gregorian ensures
    // "yyyy-MM-dd" is stable across all device locales (Arabic, Hebrew, etc.).
    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        return f
    }()
    
    private init() {}
    
    public var isActivated: Bool {
        return defaults.bool(forKey: activatedKey)
    }
    
    public var daysWithWallpaperActive: Int {
        return defaults.integer(forKey: daysActiveKey)
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

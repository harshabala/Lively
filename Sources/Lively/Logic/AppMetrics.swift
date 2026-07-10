import Foundation

public final class AppMetrics: @unchecked Sendable {
    public static let shared = AppMetrics()
    
    private let defaults = UserDefaults.standard
    
    private let activatedKey = "wallpaper_applied_once"
    private let daysActiveKey = "days_with_wallpaper_active"
    private let lastActiveDateKey = "last_wallpaper_active_date"
    
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
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        
        let lastDateString = defaults.string(forKey: lastActiveDateKey)
        
        if lastDateString != todayString {
            let newDays = daysWithWallpaperActive + 1
            defaults.set(newDays, forKey: daysActiveKey)
            defaults.set(todayString, forKey: lastActiveDateKey)
        }
    }
}

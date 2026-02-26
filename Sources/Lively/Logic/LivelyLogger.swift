import Foundation
import os

enum LivelyLogger {
    private static let subsystem: String = {
        Bundle.main.bundleIdentifier ?? "Lively"
    }()

    static let config = Logger(subsystem: subsystem, category: "ConfigStore")
    static let wallpaper = Logger(subsystem: subsystem, category: "WallpaperController")
    static let videoPreview = Logger(subsystem: subsystem, category: "VideoPlayerView")
    static let spaceMonitor = Logger(subsystem: subsystem, category: "SpaceMonitor")
}


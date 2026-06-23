import Foundation
import os
import Combine

@MainActor
public final class LogStore: ObservableObject {
    public static let shared = LogStore()
    
    @Published public private(set) var entries: [String] = []
    
    private init() {}
    
    public func add(_ message: String) {
        entries.append(message)
        if entries.count > 1000 {
            entries.removeFirst(entries.count - 1000)
        }
    }
    
    public func clear() {
        entries.removeAll()
    }
    
    public var allLogsFormatted: String {
        entries.joined(separator: "\n")
    }
}

public struct LivelyCategoryLogger: Sendable {
    let category: String
    private let osLogger: Logger
    
    init(category: String) {
        self.category = category
        self.osLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Lively", category: category)
    }
    
    public func info(_ message: String) {
        osLogger.info("\(message, privacy: .public)")
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            let ts = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
            Task { @MainActor in
                LogStore.shared.add("[\(ts)] [\(category)] INFO: \(message)")
            }
        }
    }
    
    public func error(_ message: String) {
        osLogger.error("\(message, privacy: .public)")
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            let ts = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
            Task { @MainActor in
                LogStore.shared.add("[\(ts)] [\(category)] ERROR: \(message)")
            }
        }
    }
    
    public func debug(_ message: String) {
        osLogger.debug("\(message, privacy: .public)")
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            let ts = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
            Task { @MainActor in
                LogStore.shared.add("[\(ts)] [\(category)] DEBUG: \(message)")
            }
        }
    }
}

public enum LivelyLogger {
    public static let config = LivelyCategoryLogger(category: "ConfigStore")
    public static let wallpaper = LivelyCategoryLogger(category: "WallpaperController")
    public static let videoPreview = LivelyCategoryLogger(category: "VideoPlayerView")
    public static let spaceMonitor = LivelyCategoryLogger(category: "SpaceMonitor")
    public static let updater = LivelyCategoryLogger(category: "Updater")
}

import Foundation
import os
import Combine

public enum LogLevel: String, Sendable {
    case info = "Info"
    case warning = "Warning"
    case error = "Error"
    case debug = "Debug"
}

public struct LogEntry: Identifiable, Sendable {
    public let id = UUID()
    public let level: LogLevel
    public let message: String
    public let timestamp: Date
    public let category: String

    public var isError: Bool { level == .error || level == .warning }

    public var text: String {
        let ts = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .medium)
        return "[\(ts)] [\(category)] \(level.rawValue.uppercased()): \(message)"
    }

    public var timeString: String {
        Self.timeFormatter.string(from: timestamp)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy h:mm:ss a"
        return f
    }()
}

@MainActor
public final class LogStore: ObservableObject {
    public static let shared = LogStore()

    @Published public private(set) var entries: [LogEntry] = []

    private init() {}

    public func add(_ message: String, level: LogLevel = .info, category: String = "App") {
        entries.append(LogEntry(level: level, message: message, timestamp: Date(), category: category))
        if entries.count > 1000 {
            entries.removeFirst(entries.count - 1000)
        }
    }

    /// Backward-compatible convenience used by older call sites.
    public func add(_ message: String, isError: Bool = false) {
        add(message, level: isError ? .error : .info, category: "App")
    }

    public func clear() {
        entries.removeAll()
    }

    public var allLogsFormatted: String {
        entries.map(\.text).joined(separator: "\n")
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
            Task { @MainActor in
                LogStore.shared.add(message, level: .info, category: category)
            }
        }
    }
    
    public func error(_ message: String) {
        osLogger.error("\(message, privacy: .public)")
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            Task { @MainActor in
                LogStore.shared.add(message, level: .error, category: category)
            }
        }
    }
    
    public func debug(_ message: String) {
        osLogger.debug("\(message, privacy: .public)")
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            Task { @MainActor in
                LogStore.shared.add(message, level: .debug, category: category)
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

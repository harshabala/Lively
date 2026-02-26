import Foundation
import AppKit
import Combine

// MARK: - SpaceConfig

public struct SpaceConfig: Codable {
    /// Composite key: "displayID:desktopImageURL.absoluteString"
    public let spaceKey: String
    
    /// The dynamic wallpaper configuration.
    public let dynamicWallpaper: DynamicWallpaper
    
    /// Bookmarks for all relevant URLs.
    /// Key: "static", "light", "dark".
    public let bookmarks: [String: Data]
    
    public let addedAt: Date
}

// MARK: - ConfigStore

@MainActor
public class ConfigStore: ObservableObject {

    @Published public private(set) var configs: [String: SpaceConfig] = [:]

    public enum Error: Swift.Error {
        case directoryCreationFailed(Swift.Error)
        case persistFailed(Swift.Error)
        case loadFailed(Swift.Error)
        case bookmarkRefreshFailed(String)
    }

    public let errors = PassthroughSubject<Error, Never>()

    private let configFileURL: URL
    private let persistQueue = DispatchQueue(label: "Lively.ConfigStore.persist")
    private var pendingPersistWorkItem: DispatchWorkItem?

    public init(configFileURL: URL? = nil) {
        if let provided = configFileURL {
            self.configFileURL = provided
        } else {
            if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let dir = appSupport.appendingPathComponent("Lively")
                do {
                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                } catch {
                    LivelyLogger.config.error("Failed to create config directory: \(error.localizedDescription)")
                    errors.send(.directoryCreationFailed(error))
                }
                self.configFileURL = dir.appendingPathComponent("config_v2.json")
            } else {
                self.configFileURL = URL(fileURLWithPath: "/tmp/lively_config.json")
            }
        }
        load()
    }

    // MARK: - Public API

    /// Assigns a dynamic wallpaper configuration to a space.
    public func assign(dynamicWallpaper: DynamicWallpaper, toSpaceKey key: String) {
        var bookmarks: [String: Data] = [:]
        
        // Create security-scoped bookmarks so files remain accessible after relaunch
        func bookmark(for url: URL?) -> Data? {
            guard let url = url else { return nil }
            return try? url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }
        
        if let data = bookmark(for: dynamicWallpaper.staticURL) { bookmarks["static"] = data }
        if let data = bookmark(for: dynamicWallpaper.lightURL) { bookmarks["light"] = data }
        if let data = bookmark(for: dynamicWallpaper.darkURL) { bookmarks["dark"] = data }
        
        let config = SpaceConfig(
            spaceKey: key,
            dynamicWallpaper: dynamicWallpaper,
            bookmarks: bookmarks,
            addedAt: Date()
        )
        configs[key] = config
        persist()
        LivelyLogger.config.info("Assigned dynamic wallpaper to \(key)")
    }

    /// Resolves the URL for the current mode/appearance.
    ///
    /// This method only decodes the bookmark — it does NOT call
    /// `startAccessingSecurityScopedResource`. The caller (WallpaperController)
    /// is responsible for calling start/stop to balance the access handles.
    public func resolvedURL(for spaceKey: String, appearance: NSAppearance?) -> URL? {
        guard let config = configs[spaceKey] else { return nil }
        
        let targetURL = config.dynamicWallpaper.url(for: appearance)
        guard let url = targetURL else { return nil }
        
        // Determine the bookmark key for this mode + URL
        let bookmarkKey: String
        switch config.dynamicWallpaper.mode {
        case .staticVideo: bookmarkKey = "static"
        case .appearance:
            if url == config.dynamicWallpaper.darkURL { bookmarkKey = "dark" }
            else { bookmarkKey = "light" }
        }
        
        guard let data = config.bookmarks[bookmarkKey] else {
            LivelyLogger.config.debug("No bookmark for \(bookmarkKey), using raw path")
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }

        var isStale = false

        do {
            // Try 1: resolve with security scope (new bookmarks saved with .withSecurityScope)
            let resolved = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                LivelyLogger.config.info("Refreshing stale bookmark for \(bookmarkKey)")
                refreshBookmark(spaceKey: spaceKey, bookmarkKey: bookmarkKey, url: resolved)
            }

            LivelyLogger.config.info("Resolved \(bookmarkKey) via security-scoped bookmark → \(resolved.lastPathComponent)")
            return resolved
        } catch {
            LivelyLogger.config.error("Failed to resolve security-scoped bookmark for \(bookmarkKey): \(error.localizedDescription)")
        }

        do {
            // Try 2: resolve without security scope (legacy bookmarks from older app versions)
            let legacyResolved = try URL(
                resolvingBookmarkData: data,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            LivelyLogger.config.info("Legacy bookmark resolved for \(bookmarkKey), upgrading to security-scoped")
            // Auto-upgrade: re-save with security scope for future launches
            refreshBookmark(spaceKey: spaceKey, bookmarkKey: bookmarkKey, url: legacyResolved)
            return legacyResolved
        } catch {
            LivelyLogger.config.error("Failed to resolve legacy bookmark for \(bookmarkKey): \(error.localizedDescription)")
        }

        LivelyLogger.config.error("Bookmark resolution failed for \(bookmarkKey), falling back to raw path")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    
    /// Re-creates a bookmark for a URL with security scope.
    private func refreshBookmark(spaceKey: String, bookmarkKey: String, url: URL) {
        // Temporarily access the URL to re-bookmark it
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }
        
        guard let config = configs[spaceKey] else {
            errors.send(.bookmarkRefreshFailed(bookmarkKey))
            LivelyLogger.config.error("No config found while refreshing bookmark for \(bookmarkKey)")
            return
        }

        let newData: Data
        do {
            newData = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            errors.send(.bookmarkRefreshFailed(bookmarkKey))
            LivelyLogger.config.error("Failed to refresh bookmark for \(bookmarkKey): \(error.localizedDescription)")
            return
        }
        
        var updatedBookmarks = config.bookmarks
        updatedBookmarks[bookmarkKey] = newData
        
        let refreshed = SpaceConfig(
            spaceKey: config.spaceKey,
            dynamicWallpaper: config.dynamicWallpaper,
            bookmarks: updatedBookmarks,
            addedAt: config.addedAt
        )
        configs[spaceKey] = refreshed
        persist()
        LivelyLogger.config.info("Bookmark upgraded to security-scoped for \(bookmarkKey)")
    }

    public func remove(spaceKey: String) {
        configs.removeValue(forKey: spaceKey)
        persist()
        LivelyLogger.config.info("Removed assignment for \(spaceKey)")
    }

    // MARK: - Persistence

    private func persist() {
        let snapshot = configs

        let workItem = DispatchWorkItem { [configFileURL, weak self] in
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: configFileURL, options: .atomic)
            } catch {
                DispatchQueue.main.async {
                    self?.errors.send(.persistFailed(error))
                    LivelyLogger.config.error("Failed to save config: \(error.localizedDescription)")
                }
            }
        }

        pendingPersistWorkItem?.cancel()
        pendingPersistWorkItem = workItem

        persistQueue.asyncAfter(deadline: .now() + .milliseconds(300), execute: workItem)
    }

    private func load() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: configFileURL.path) else {
            LivelyLogger.config.info("Starting fresh (no existing config)")
            return
        }

        do {
            let data = try Data(contentsOf: configFileURL)
            let decoded = try JSONDecoder().decode([String: SpaceConfig].self, from: data)
            configs = decoded
            LivelyLogger.config.info("Loaded \(self.configs.count) assignment(s)")
        } catch {
            errors.send(.loadFailed(error))
            LivelyLogger.config.error("Failed to load existing config, starting fresh: \(error.localizedDescription)")
            configs = [:]
        }
    }
}

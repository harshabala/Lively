import Foundation
import AppKit
import Combine

// MARK: - SpaceConfig

public struct SpaceConfig: Codable, Sendable {
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
            // Try 2: resolve without security scope (legacy bookmarks from older app versions)
            do {
                var legacyStale = false
                let legacyResolved = try URL(
                    resolvingBookmarkData: data,
                    options: [],
                    relativeTo: nil,
                    bookmarkDataIsStale: &legacyStale
                )
                LivelyLogger.config.info("Legacy bookmark resolved for \(bookmarkKey), upgrading to security-scoped")
                // Auto-upgrade: re-save with security scope for future launches
                refreshBookmark(spaceKey: spaceKey, bookmarkKey: bookmarkKey, url: legacyResolved)
                return legacyResolved
            } catch let legacyError {
                LivelyLogger.config.error("Bookmark resolution failed for \(bookmarkKey). Primary error: \(error.localizedDescription). Legacy fallback error: \(legacyError.localizedDescription)")
                return FileManager.default.fileExists(atPath: url.path) ? url : nil
            }
        }
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

    /// Updates only the display settings (gravity, mute, volume) for an existing config.
    /// This is a lightweight path that skips security-scoped bookmark re-creation,
    /// avoiding the expensive bookmark + full re-sync triggered by `assign(...)`.
    public func updateDisplaySettings(for key: String, gravity: VideoGravity, isMuted: Bool, volume: Float) {
        guard let existing = configs[key] else { return }

        var updated = existing.dynamicWallpaper
        updated.videoGravity = gravity
        updated.isMuted = isMuted
        updated.volume = volume

        // Only persist if something actually changed
        guard updated != existing.dynamicWallpaper else { return }

        let refreshed = SpaceConfig(
            spaceKey: existing.spaceKey,
            dynamicWallpaper: updated,
            bookmarks: existing.bookmarks,
            addedAt: existing.addedAt
        )
        configs[key] = refreshed
        persist()
    }

    /// Removes configs whose spaceKeys don't match any currently active screen space.
    /// Call periodically (e.g. on app launch) to prevent unbounded config growth.
    public func pruneOrphanedConfigs(activeSpaceKeys: Set<String>) {
        let orphaned = configs.keys.filter { !activeSpaceKeys.contains($0) }
        guard !orphaned.isEmpty else { return }
        for key in orphaned {
            configs.removeValue(forKey: key)
        }
        persist()
        LivelyLogger.config.info("Pruned \(orphaned.count) orphaned config(s)")
    }

    public func remove(spaceKey: String) {
        configs.removeValue(forKey: spaceKey)
        persist()
        LivelyLogger.config.info("Removed assignment for \(spaceKey)")
    }

    /// Deletes all saved configuration data from disk and memory.
    public func clearAllData() {
        configs.removeAll()
        persist()
        let fm = FileManager.default
        let dir = configFileURL.deletingLastPathComponent()
        if fm.fileExists(atPath: dir.path) {
            do {
                try fm.removeItem(at: dir)
                LivelyLogger.config.info("Successfully deleted all application data from \(dir.path)")
            } catch {
                LivelyLogger.config.error("Failed to delete application data: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Persistence

    private func persist() {
        let snapshot = configs

        let workItem = DispatchWorkItem { @Sendable [configFileURL, weak self] in
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

    /// Synchronously flushes any debounced pending write to disk.
    /// Must be called before the process exits to prevent data loss.
    public func flushPendingPersist() {
        guard let pending = pendingPersistWorkItem else { return }
        pending.cancel()
        pendingPersistWorkItem = nil

        let snapshot = configs
        let fileURL = self.configFileURL  // capture before crossing isolation boundary
        persistQueue.sync {
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: fileURL, options: .atomic)
                LivelyLogger.config.info("Config flushed synchronously on exit")
            } catch {
                LivelyLogger.config.error("Failed to flush config on exit: \(error.localizedDescription)")
            }
        }
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

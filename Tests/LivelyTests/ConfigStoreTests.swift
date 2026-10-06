import Testing
@testable import LivelyCore
import Foundation

@MainActor
struct ConfigStoreTests {

    private func makeJSONURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
    }

    private func makeVideo(suffix: String = "video") -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_\(suffix).mp4")
        FileManager.default.createFile(atPath: url.path, contents: Data(), attributes: nil)
        return url
    }

    private func staticWallpaper(_ url: URL) -> DynamicWallpaper {
        var wallpaper = DynamicWallpaper()
        wallpaper.mode = .staticVideo
        wallpaper.staticURL = url
        return wallpaper
    }

    // MARK: - Static Video Mode

    @Test func assignAndRetrieve() async {
        let tempFile = makeJSONURL()
        defer { try? FileManager.default.removeItem(at: tempFile) }
        let configStore = ConfigStore(configFileURL: tempFile)

        let spaceKey = "test-display:file:///test/wallpaper.png"
        let tempVideo = makeVideo()
        defer { try? FileManager.default.removeItem(at: tempVideo) }

        configStore.assign(dynamicWallpaper: staticWallpaper(tempVideo), toSpaceKey: spaceKey)

        #expect(configStore.configs[spaceKey] != nil)
        #expect(configStore.configs[spaceKey]?.dynamicWallpaper.staticURL == tempVideo)
        #expect(configStore.configs[spaceKey]?.dynamicWallpaper.mode == .staticVideo)
    }

    @Test func persistenceRoundTrip() async throws {
        let tempFile = makeJSONURL()
        defer { try? FileManager.default.removeItem(at: tempFile) }
        let configStore = ConfigStore(configFileURL: tempFile)

        let spaceKey = "test-display:file:///test/roundtrip.png"
        let tempVideo = makeVideo(suffix: "roundtrip")
        defer { try? FileManager.default.removeItem(at: tempVideo) }

        configStore.assign(dynamicWallpaper: staticWallpaper(tempVideo), toSpaceKey: spaceKey)
        configStore.flushPendingPersist()

        let freshStore = ConfigStore(configFileURL: tempFile)
        #expect(freshStore.configs[spaceKey] != nil, "Config should survive a process restart")
        #expect(freshStore.configs[spaceKey]?.dynamicWallpaper.mode == .staticVideo)
    }

    @Test func remove() async {
        let tempFile = makeJSONURL()
        defer { try? FileManager.default.removeItem(at: tempFile) }
        let configStore = ConfigStore(configFileURL: tempFile)
        let spaceKey = "test-display:file:///test/remove.png"
        let tempVideo = makeVideo(suffix: "remove")
        defer { try? FileManager.default.removeItem(at: tempVideo) }

        configStore.assign(dynamicWallpaper: staticWallpaper(tempVideo), toSpaceKey: spaceKey)
        configStore.remove(spaceKey: spaceKey)

        #expect(configStore.configs[spaceKey] == nil)
    }

    // MARK: - Appearance Mode

    @Test func appearanceModeAssignment() async {
        let tempFile = makeJSONURL()
        defer { try? FileManager.default.removeItem(at: tempFile) }
        let configStore = ConfigStore(configFileURL: tempFile)

        let spaceKey = "test-display:file:///test/appearance.png"
        let lightVideo = makeVideo(suffix: "light")
        let darkVideo = makeVideo(suffix: "dark")
        defer {
            try? FileManager.default.removeItem(at: lightVideo)
            try? FileManager.default.removeItem(at: darkVideo)
        }

        var wallpaper = DynamicWallpaper()
        wallpaper.mode = .appearance
        wallpaper.lightURL = lightVideo
        wallpaper.darkURL = darkVideo

        configStore.assign(dynamicWallpaper: wallpaper, toSpaceKey: spaceKey)

        let stored = configStore.configs[spaceKey]
        #expect(stored != nil)
        #expect(stored?.dynamicWallpaper.mode == .appearance)
        #expect(stored?.dynamicWallpaper.lightURL == lightVideo)
        #expect(stored?.dynamicWallpaper.darkURL == darkVideo)
    }

    // MARK: - Resolved URL

    @Test func resolvedURLStaticMode() async {
        let tempFile = makeJSONURL()
        defer { try? FileManager.default.removeItem(at: tempFile) }
        let configStore = ConfigStore(configFileURL: tempFile)
        let spaceKey = "test-display:file:///test/resolved.png"
        let tempVideo = makeVideo(suffix: "resolved")
        defer { try? FileManager.default.removeItem(at: tempVideo) }

        configStore.assign(dynamicWallpaper: staticWallpaper(tempVideo), toSpaceKey: spaceKey)

        let resolved = configStore.resolvedURL(for: spaceKey, appearance: nil)
        #expect(resolved != nil)
    }

    @Test func resolvedURLMissingKey() async {
        let tempFile = makeJSONURL()
        defer { try? FileManager.default.removeItem(at: tempFile) }
        let configStore = ConfigStore(configFileURL: tempFile)

        let resolved = configStore.resolvedURL(for: "nonexistent", appearance: nil)
        #expect(resolved == nil)
    }

    /// Regression: assignments for Spaces that are not currently visible, or for
    /// displays that are unplugged, used to be deleted whenever the screen
    /// layout was re-read (every Space switch, config change, and launch).
    @Test func inactiveSpaceAssignmentsSurviveControllerSync() async {
        let tempFile = makeJSONURL()
        defer { try? FileManager.default.removeItem(at: tempFile) }
        let configStore = ConfigStore(configFileURL: tempFile)
        let tempVideo = makeVideo(suffix: "inactive")
        defer { try? FileManager.default.removeItem(at: tempVideo) }

        let wallpaper = staticWallpaper(tempVideo)
        let otherSpace = "999999:file:///Library/Desktop%20Pictures/Other%20Space.heic"
        let unpluggedDisplay = "424242:file:///Library/Desktop%20Pictures/External.heic"
        configStore.assign(dynamicWallpaper: wallpaper, toSpaceKey: otherSpace)
        configStore.assign(dynamicWallpaper: wallpaper, toSpaceKey: unpluggedDisplay)

        let monitor = SpaceMonitor()
        let controller = WallpaperController(spaceMonitor: monitor, configStore: configStore)
        monitor.refresh()
        _ = controller

        #expect(configStore.configs[otherSpace] != nil)
        #expect(configStore.configs[unpluggedDisplay] != nil)
    }

    @Test func clearAllDataCancelsPendingPersist() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configStore = ConfigStore(configFileURL: tempDir.appendingPathComponent("config_v2.json"))
        let tempVideo = makeVideo(suffix: "clear")
        defer { try? FileManager.default.removeItem(at: tempVideo) }

        configStore.assign(dynamicWallpaper: staticWallpaper(tempVideo), toSpaceKey: "clear:test")

        configStore.clearAllData()
        #expect(configStore.configs.isEmpty)
        #expect(FileManager.default.fileExists(atPath: tempDir.path) == false)
    }
}

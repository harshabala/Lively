import Testing
@testable import LivelyCore
import Foundation

@MainActor
struct ConfigStoreTests {

    // MARK: - Static Video Mode

    @Test func assignAndRetrieve() async {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: tempFile) }
        let configStore = ConfigStore(configFileURL: tempFile)

        let spaceKey = "test-display:file:///test/wallpaper.png"
        let tempVideo = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_video.mp4")
        FileManager.default.createFile(atPath: tempVideo.path, contents: Data(), attributes: nil)
        defer { try? FileManager.default.removeItem(at: tempVideo) }

        var wallpaper = DynamicWallpaper()
        wallpaper.mode = .staticVideo
        wallpaper.staticURL = tempVideo

        configStore.assign(dynamicWallpaper: wallpaper, toSpaceKey: spaceKey)

        #expect(configStore.configs[spaceKey] != nil)
        #expect(configStore.configs[spaceKey]?.dynamicWallpaper.staticURL == tempVideo)
        #expect(configStore.configs[spaceKey]?.dynamicWallpaper.mode == .staticVideo)
    }

    @Test func persistenceRoundTrip() async throws {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: tempFile) }
        let configStore = ConfigStore(configFileURL: tempFile)

        let spaceKey = "test-display:file:///test/roundtrip.png"
        let tempVideo = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_roundtrip.mp4")
        FileManager.default.createFile(atPath: tempVideo.path, contents: Data(), attributes: nil)
        defer { try? FileManager.default.removeItem(at: tempVideo) }

        var wallpaper = DynamicWallpaper()
        wallpaper.mode = .staticVideo
        wallpaper.staticURL = tempVideo

        configStore.assign(dynamicWallpaper: wallpaper, toSpaceKey: spaceKey)
        configStore.flushPendingPersist()

        let freshStore = ConfigStore(configFileURL: tempFile)
        #expect(freshStore.configs[spaceKey] != nil, "Config should survive a process restart")
        #expect(freshStore.configs[spaceKey]?.dynamicWallpaper.mode == .staticVideo)
    }

    @Test func remove() async {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: tempFile) }
        let configStore = ConfigStore(configFileURL: tempFile)

        let spaceKey = "test-display:file:///test/remove.png"
        let tempVideo = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_remove.mp4")
        FileManager.default.createFile(atPath: tempVideo.path, contents: Data(), attributes: nil)
        defer { try? FileManager.default.removeItem(at: tempVideo) }

        var wallpaper = DynamicWallpaper()
        wallpaper.mode = .staticVideo
        wallpaper.staticURL = tempVideo

        configStore.assign(dynamicWallpaper: wallpaper, toSpaceKey: spaceKey)
        configStore.remove(spaceKey: spaceKey)

        #expect(configStore.configs[spaceKey] == nil)
    }

    // MARK: - Appearance Mode

    @Test func appearanceModeAssignment() async {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: tempFile) }
        let configStore = ConfigStore(configFileURL: tempFile)

        let spaceKey = "test-display:file:///test/appearance.png"
        let lightVideo = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_light.mp4")
        let darkVideo = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_dark.mp4")
        FileManager.default.createFile(atPath: lightVideo.path, contents: Data(), attributes: nil)
        FileManager.default.createFile(atPath: darkVideo.path, contents: Data(), attributes: nil)
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
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: tempFile) }
        let configStore = ConfigStore(configFileURL: tempFile)

        let spaceKey = "test-display:file:///test/resolved.png"
        let tempVideo = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_resolved.mp4")
        FileManager.default.createFile(atPath: tempVideo.path, contents: Data(), attributes: nil)
        defer { try? FileManager.default.removeItem(at: tempVideo) }

        var wallpaper = DynamicWallpaper()
        wallpaper.mode = .staticVideo
        wallpaper.staticURL = tempVideo

        configStore.assign(dynamicWallpaper: wallpaper, toSpaceKey: spaceKey)

        let resolved = configStore.resolvedURL(for: spaceKey, appearance: nil)
        #expect(resolved != nil)
    }

    @Test func resolvedURLMissingKey() async {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: tempFile) }
        let configStore = ConfigStore(configFileURL: tempFile)

        let resolved = configStore.resolvedURL(for: "nonexistent", appearance: nil)
        #expect(resolved == nil)
    }
}

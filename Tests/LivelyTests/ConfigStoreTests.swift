import XCTest
@testable import LivelyCore

@MainActor
final class ConfigStoreTests: XCTestCase {
    
    var tempFileURL: URL!
    var configStore: ConfigStore!

    override func setUp() async throws {
        // Create a temporary file for testing
        tempFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        configStore = ConfigStore(configFileURL: tempFileURL)
    }

    override func tearDown() async throws {
        // Clean up
        try? FileManager.default.removeItem(at: tempFileURL)
    }

    // MARK: - Static Video Mode

    func testAssignAndRetrieve() async {
        let spaceKey = "test-display:file:///test/wallpaper.png"
        let tempVideo = FileManager.default.temporaryDirectory.appendingPathComponent("video.mp4")
        FileManager.default.createFile(atPath: tempVideo.path, contents: Data(), attributes: nil)
        defer { try? FileManager.default.removeItem(at: tempVideo) }
        
        var wallpaper = DynamicWallpaper()
        wallpaper.mode = .staticVideo
        wallpaper.staticURL = tempVideo
        
        configStore.assign(dynamicWallpaper: wallpaper, toSpaceKey: spaceKey)
        
        XCTAssertNotNil(configStore.configs[spaceKey])
        XCTAssertEqual(configStore.configs[spaceKey]?.dynamicWallpaper.staticURL, tempVideo)
        XCTAssertEqual(configStore.configs[spaceKey]?.dynamicWallpaper.mode, .staticVideo)
    }

    func testPersistenceRoundTrip() async throws {
        let spaceKey = "test-display:file:///test/roundtrip.png"
        let tempVideo = FileManager.default.temporaryDirectory.appendingPathComponent("roundtrip.mp4")
        FileManager.default.createFile(atPath: tempVideo.path, contents: Data(), attributes: nil)
        defer { try? FileManager.default.removeItem(at: tempVideo) }

        var wallpaper = DynamicWallpaper()
        wallpaper.mode = .staticVideo
        wallpaper.staticURL = tempVideo

        configStore.assign(dynamicWallpaper: wallpaper, toSpaceKey: spaceKey)
        // Bypass the 300 ms debounce and write synchronously
        configStore.flushPendingPersist()

        // Load a brand-new ConfigStore from the same file — this proves the disk round-trip
        let freshStore = ConfigStore(configFileURL: tempFileURL)
        XCTAssertNotNil(freshStore.configs[spaceKey], "Config should survive a process restart")
        XCTAssertEqual(freshStore.configs[spaceKey]?.dynamicWallpaper.mode, .staticVideo)
    }
    
    func testRemove() async {
        let spaceKey = "test-display:file:///test/remove.png"
        let tempVideo = FileManager.default.temporaryDirectory.appendingPathComponent("remove_video.mp4")
        FileManager.default.createFile(atPath: tempVideo.path, contents: Data(), attributes: nil)
        defer { try? FileManager.default.removeItem(at: tempVideo) }
        
        var wallpaper = DynamicWallpaper()
        wallpaper.mode = .staticVideo
        wallpaper.staticURL = tempVideo
        
        configStore.assign(dynamicWallpaper: wallpaper, toSpaceKey: spaceKey)
        configStore.remove(spaceKey: spaceKey)
        
        XCTAssertNil(configStore.configs[spaceKey])
    }

    // MARK: - Appearance Mode

    func testAppearanceModeAssignment() async {
        let spaceKey = "test-display:file:///test/appearance.png"
        let lightVideo = FileManager.default.temporaryDirectory.appendingPathComponent("light.mp4")
        let darkVideo = FileManager.default.temporaryDirectory.appendingPathComponent("dark.mp4")
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
        XCTAssertNotNil(stored)
        XCTAssertEqual(stored?.dynamicWallpaper.mode, .appearance)
        XCTAssertEqual(stored?.dynamicWallpaper.lightURL, lightVideo)
        XCTAssertEqual(stored?.dynamicWallpaper.darkURL, darkVideo)
    }
    
    // MARK: - Resolved URL

    func testResolvedURLStaticMode() async {
        let spaceKey = "test-display:file:///test/resolved.png"
        let tempVideo = FileManager.default.temporaryDirectory.appendingPathComponent("resolved.mp4")
        FileManager.default.createFile(atPath: tempVideo.path, contents: Data(), attributes: nil)
        defer { try? FileManager.default.removeItem(at: tempVideo) }
        
        var wallpaper = DynamicWallpaper()
        wallpaper.mode = .staticVideo
        wallpaper.staticURL = tempVideo
        
        configStore.assign(dynamicWallpaper: wallpaper, toSpaceKey: spaceKey)
        
        // resolvedURL should return the video regardless of appearance
        let resolved = configStore.resolvedURL(for: spaceKey, appearance: nil)
        XCTAssertNotNil(resolved)
    }
    
    func testResolvedURLMissing() async {
        let resolved = configStore.resolvedURL(for: "nonexistent", appearance: nil)
        XCTAssertNil(resolved)
    }
}

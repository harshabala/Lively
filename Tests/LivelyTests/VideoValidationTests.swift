import XCTest
@testable import LivelyCore

final class VideoValidationTests: XCTestCase {
    
    // MARK: - File Extension Validation
    
    private let supportedExtensions: Set<String> = ["mp4", "mov", "m4v"]
    
    private func isValidVideoFile(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }
    
    func testAcceptsMP4() {
        let url = URL(fileURLWithPath: "/tmp/test.mp4")
        XCTAssertTrue(isValidVideoFile(url))
    }
    
    func testAcceptsMOV() {
        let url = URL(fileURLWithPath: "/tmp/test.mov")
        XCTAssertTrue(isValidVideoFile(url))
    }
    
    func testAcceptsM4V() {
        let url = URL(fileURLWithPath: "/tmp/test.m4v")
        XCTAssertTrue(isValidVideoFile(url))
    }
    
    func testAcceptsUppercaseExtension() {
        let url = URL(fileURLWithPath: "/tmp/test.MP4")
        XCTAssertTrue(isValidVideoFile(url))
    }
    
    func testRejectsPNG() {
        let url = URL(fileURLWithPath: "/tmp/test.png")
        XCTAssertFalse(isValidVideoFile(url))
    }
    
    func testRejectsTXT() {
        let url = URL(fileURLWithPath: "/tmp/test.txt")
        XCTAssertFalse(isValidVideoFile(url))
    }
    
    func testRejectsGIF() {
        let url = URL(fileURLWithPath: "/tmp/test.gif")
        XCTAssertFalse(isValidVideoFile(url))
    }
    
    func testRejectsNoExtension() {
        let url = URL(fileURLWithPath: "/tmp/testfile")
        XCTAssertFalse(isValidVideoFile(url))
    }
    
    // MARK: - DynamicWallpaper Display Settings
    
    func testDefaultDisplaySettings() {
        let wallpaper = DynamicWallpaper()
        XCTAssertEqual(wallpaper.videoGravity, .fill)
        XCTAssertTrue(wallpaper.isMuted)
        XCTAssertEqual(wallpaper.volume, 0.0)
    }
    
    func testVideoGravityCodable() throws {
        var wallpaper = DynamicWallpaper()
        wallpaper.videoGravity = .fit
        wallpaper.isMuted = false
        wallpaper.volume = 0.5
        
        let data = try JSONEncoder().encode(wallpaper)
        let decoded = try JSONDecoder().decode(DynamicWallpaper.self, from: data)
        
        XCTAssertEqual(decoded.videoGravity, .fit)
        XCTAssertFalse(decoded.isMuted)
        XCTAssertEqual(decoded.volume, 0.5)
    }
    
    func testVideoGravityEnum() {
        XCTAssertEqual(VideoGravity.fill.rawValue, "fill")
        XCTAssertEqual(VideoGravity.fit.rawValue, "fit")
        XCTAssertEqual(VideoGravity.allCases.count, 2)
    }
    
    // MARK: - ConfigStore Bookmark Integration
    
    @MainActor
    func testResolvedURLReturnsNilForMissingKey() async {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: tempFile) }
        
        let store = ConfigStore(configFileURL: tempFile)
        let result = store.resolvedURL(for: "nonexistent-key", appearance: nil)
        XCTAssertNil(result)
    }
    
    @MainActor
    func testResolvedURLReturnsValueForValidConfig() async {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let tempVideo = FileManager.default.temporaryDirectory.appendingPathComponent("test_resolved.mp4")
        FileManager.default.createFile(atPath: tempVideo.path, contents: Data(), attributes: nil)
        defer {
            try? FileManager.default.removeItem(at: tempFile)
            try? FileManager.default.removeItem(at: tempVideo)
        }
        
        let store = ConfigStore(configFileURL: tempFile)
        var wallpaper = DynamicWallpaper()
        wallpaper.mode = .staticVideo
        wallpaper.staticURL = tempVideo
        
        store.assign(dynamicWallpaper: wallpaper, toSpaceKey: "test-key")
        let result = store.resolvedURL(for: "test-key", appearance: nil)
        XCTAssertNotNil(result)
    }
    
    // MARK: - Backward Compatibility
    
    func testOldConfigWithoutNewFieldsDecodes() throws {
        // Simulate a config saved before videoGravity/isMuted/volume were added
        let json = """
        {
            "mode": "static",
            "staticURL": "file:///tmp/video.mp4"
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(DynamicWallpaper.self, from: data)
        
        // New fields should fall back to defaults
        XCTAssertEqual(decoded.videoGravity, .fill)
        XCTAssertTrue(decoded.isMuted)
        XCTAssertEqual(decoded.volume, 0.0)
        XCTAssertEqual(decoded.mode, .staticVideo)
    }
}

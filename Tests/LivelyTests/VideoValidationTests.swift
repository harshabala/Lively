import Testing
@testable import LivelyCore
import Foundation

struct VideoValidationTests {

    // MARK: - File Extension Validation

    @Test func acceptsMP4() {
        #expect(isValidLivelyVideoFile(URL(fileURLWithPath: "/tmp/test.mp4")))
    }

    @Test func acceptsMOV() {
        #expect(isValidLivelyVideoFile(URL(fileURLWithPath: "/tmp/test.mov")))
    }

    @Test func acceptsM4V() {
        #expect(isValidLivelyVideoFile(URL(fileURLWithPath: "/tmp/test.m4v")))
    }

    @Test func acceptsUppercaseExtension() {
        #expect(isValidLivelyVideoFile(URL(fileURLWithPath: "/tmp/test.MP4")))
    }

    @Test func rejectsPNG() {
        #expect(!isValidLivelyVideoFile(URL(fileURLWithPath: "/tmp/test.png")))
    }

    @Test func rejectsTXT() {
        #expect(!isValidLivelyVideoFile(URL(fileURLWithPath: "/tmp/test.txt")))
    }

    @Test func rejectsGIF() {
        #expect(!isValidLivelyVideoFile(URL(fileURLWithPath: "/tmp/test.gif")))
    }

    @Test func rejectsNoExtension() {
        #expect(!isValidLivelyVideoFile(URL(fileURLWithPath: "/tmp/testfile")))
    }

    // MARK: - DynamicWallpaper Display Settings

    @Test func defaultDisplaySettings() {
        let wallpaper = DynamicWallpaper()
        #expect(wallpaper.videoGravity == .fill)
        #expect(wallpaper.isMuted)
        #expect(wallpaper.volume == 0.0)
    }

    @Test func videoGravityCodable() throws {
        var wallpaper = DynamicWallpaper()
        wallpaper.videoGravity = .fit
        wallpaper.isMuted = false
        wallpaper.volume = 0.5

        let data = try JSONEncoder().encode(wallpaper)
        let decoded = try JSONDecoder().decode(DynamicWallpaper.self, from: data)

        #expect(decoded.videoGravity == .fit)
        #expect(!decoded.isMuted)
        #expect(decoded.volume == 0.5)
    }

    @Test func videoGravityEnum() {
        #expect(VideoGravity.fill.rawValue == "fill")
        #expect(VideoGravity.fit.rawValue == "fit")
        #expect(VideoGravity.allCases.count == 2)
    }

    // MARK: - ConfigStore Bookmark Integration

    @Test @MainActor func resolvedURLReturnsNilForMissingKey() async {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let store = ConfigStore(configFileURL: tempFile)
        let result = store.resolvedURL(for: "nonexistent-key", appearance: nil)
        #expect(result == nil)
    }

    @Test @MainActor func resolvedURLReturnsValueForValidConfig() async {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let tempVideo = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_resolved.mp4")
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
        #expect(result != nil)
    }

    // MARK: - Backward Compatibility

    @Test func oldConfigWithoutNewFieldsDecodes() throws {
        let json = """
        {
            "mode": "static",
            "staticURL": "file:///tmp/video.mp4"
        }
        """
        let data = try #require(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(DynamicWallpaper.self, from: data)

        #expect(decoded.videoGravity == .fill)
        #expect(decoded.isMuted)
        #expect(decoded.volume == 0.0)
        #expect(decoded.mode == .staticVideo)
    }
}

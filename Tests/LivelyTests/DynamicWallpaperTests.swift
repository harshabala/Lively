import XCTest
@testable import LivelyCore

final class DynamicWallpaperTests: XCTestCase {

    // MARK: - Static Mode

    func testStaticModeReturnsStaticURL() {
        var wallpaper = DynamicWallpaper()
        wallpaper.mode = .staticVideo
        wallpaper.staticURL = URL(fileURLWithPath: "/tmp/static.mp4")
        
        // Should return staticURL regardless of appearance
        XCTAssertEqual(wallpaper.url(for: nil), wallpaper.staticURL)
    }

    // MARK: - Appearance Mode

    func testAppearanceModeLight() {
        var wallpaper = DynamicWallpaper()
        wallpaper.mode = .appearance
        wallpaper.lightURL = URL(fileURLWithPath: "/tmp/light.mp4")
        wallpaper.darkURL = URL(fileURLWithPath: "/tmp/dark.mp4")

        let lightAppearance = NSAppearance(named: .aqua)
        XCTAssertEqual(wallpaper.url(for: lightAppearance), wallpaper.lightURL)
    }

    func testAppearanceModeDark() {
        var wallpaper = DynamicWallpaper()
        wallpaper.mode = .appearance
        wallpaper.lightURL = URL(fileURLWithPath: "/tmp/light.mp4")
        wallpaper.darkURL = URL(fileURLWithPath: "/tmp/dark.mp4")

        let darkAppearance = NSAppearance(named: .darkAqua)
        XCTAssertEqual(wallpaper.url(for: darkAppearance), wallpaper.darkURL)
    }

    func testAppearanceModeFallbackWhenLightMissing() {
        var wallpaper = DynamicWallpaper()
        wallpaper.mode = .appearance
        wallpaper.lightURL = nil
        wallpaper.darkURL = URL(fileURLWithPath: "/tmp/dark.mp4")

        // Light appearance but lightURL is nil → should fallback to darkURL
        let lightAppearance = NSAppearance(named: .aqua)
        XCTAssertEqual(wallpaper.url(for: lightAppearance), wallpaper.darkURL)
    }

    func testAppearanceModeFallbackWhenDarkMissing() {
        var wallpaper = DynamicWallpaper()
        wallpaper.mode = .appearance
        wallpaper.lightURL = URL(fileURLWithPath: "/tmp/light.mp4")
        wallpaper.darkURL = nil

        // Dark appearance but darkURL is nil → should fallback to lightURL
        let darkAppearance = NSAppearance(named: .darkAqua)
        XCTAssertEqual(wallpaper.url(for: darkAppearance), wallpaper.lightURL)
    }

    // MARK: - Codable

    func testCodableRoundTrip() throws {
        var wallpaper = DynamicWallpaper()
        wallpaper.mode = .appearance
        wallpaper.lightURL = URL(fileURLWithPath: "/tmp/light.mp4")
        wallpaper.darkURL = URL(fileURLWithPath: "/tmp/dark.mp4")
        wallpaper.staticURL = URL(fileURLWithPath: "/tmp/static.mp4")

        let data = try JSONEncoder().encode(wallpaper)
        let decoded = try JSONDecoder().decode(DynamicWallpaper.self, from: data)

        XCTAssertEqual(decoded, wallpaper)
        XCTAssertEqual(decoded.mode, .appearance)
        XCTAssertEqual(decoded.lightURL, wallpaper.lightURL)
        XCTAssertEqual(decoded.darkURL, wallpaper.darkURL)
        XCTAssertEqual(decoded.staticURL, wallpaper.staticURL)
    }
    
    // MARK: - Default Init
    
    func testDefaultInit() {
        let wallpaper = DynamicWallpaper()
        XCTAssertEqual(wallpaper.mode, .staticVideo)
        XCTAssertNil(wallpaper.staticURL)
        XCTAssertNil(wallpaper.lightURL)
        XCTAssertNil(wallpaper.darkURL)
    }
    
    func testNilAppearanceInStaticMode() {
        var wallpaper = DynamicWallpaper()
        wallpaper.mode = .staticVideo
        wallpaper.staticURL = URL(fileURLWithPath: "/tmp/video.mp4")
        
        // nil appearance should still return staticURL in static mode
        XCTAssertEqual(wallpaper.url(for: nil), wallpaper.staticURL)
    }
}

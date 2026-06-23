import Testing
@testable import LivelyCore
import AppKit

struct DynamicWallpaperTests {

    // MARK: - Static Mode

    @Test func staticModeReturnsStaticURL() {
        var wallpaper = DynamicWallpaper()
        wallpaper.mode = .staticVideo
        wallpaper.staticURL = URL(fileURLWithPath: "/tmp/static.mp4")
        #expect(wallpaper.url(for: nil) == wallpaper.staticURL)
    }

    // MARK: - Appearance Mode

    @Test func appearanceModeLightReturnsLightURL() {
        var wallpaper = DynamicWallpaper()
        wallpaper.mode = .appearance
        wallpaper.lightURL = URL(fileURLWithPath: "/tmp/light.mp4")
        wallpaper.darkURL = URL(fileURLWithPath: "/tmp/dark.mp4")
        let lightAppearance = NSAppearance(named: .aqua)
        #expect(wallpaper.url(for: lightAppearance) == wallpaper.lightURL)
    }

    @Test func appearanceModeDarkReturnsDarkURL() {
        var wallpaper = DynamicWallpaper()
        wallpaper.mode = .appearance
        wallpaper.lightURL = URL(fileURLWithPath: "/tmp/light.mp4")
        wallpaper.darkURL = URL(fileURLWithPath: "/tmp/dark.mp4")
        let darkAppearance = NSAppearance(named: .darkAqua)
        #expect(wallpaper.url(for: darkAppearance) == wallpaper.darkURL)
    }

    @Test func appearanceModeFallbackWhenLightMissing() {
        var wallpaper = DynamicWallpaper()
        wallpaper.mode = .appearance
        wallpaper.lightURL = nil
        wallpaper.darkURL = URL(fileURLWithPath: "/tmp/dark.mp4")
        let lightAppearance = NSAppearance(named: .aqua)
        #expect(wallpaper.url(for: lightAppearance) == wallpaper.darkURL)
    }

    @Test func appearanceModeFallbackWhenDarkMissing() {
        var wallpaper = DynamicWallpaper()
        wallpaper.mode = .appearance
        wallpaper.lightURL = URL(fileURLWithPath: "/tmp/light.mp4")
        wallpaper.darkURL = nil
        let darkAppearance = NSAppearance(named: .darkAqua)
        #expect(wallpaper.url(for: darkAppearance) == wallpaper.lightURL)
    }

    // MARK: - Codable

    @Test func codableRoundTrip() throws {
        var wallpaper = DynamicWallpaper()
        wallpaper.mode = .appearance
        wallpaper.lightURL = URL(fileURLWithPath: "/tmp/light.mp4")
        wallpaper.darkURL = URL(fileURLWithPath: "/tmp/dark.mp4")
        wallpaper.staticURL = URL(fileURLWithPath: "/tmp/static.mp4")

        let data = try JSONEncoder().encode(wallpaper)
        let decoded = try JSONDecoder().decode(DynamicWallpaper.self, from: data)

        #expect(decoded == wallpaper)
        #expect(decoded.mode == .appearance)
        #expect(decoded.lightURL == wallpaper.lightURL)
        #expect(decoded.darkURL == wallpaper.darkURL)
        #expect(decoded.staticURL == wallpaper.staticURL)
    }

    // MARK: - Default Init

    @Test func defaultInit() {
        let wallpaper = DynamicWallpaper()
        #expect(wallpaper.mode == .staticVideo)
        #expect(wallpaper.staticURL == nil)
        #expect(wallpaper.lightURL == nil)
        #expect(wallpaper.darkURL == nil)
    }

    @Test func nilAppearanceInStaticMode() {
        var wallpaper = DynamicWallpaper()
        wallpaper.mode = .staticVideo
        wallpaper.staticURL = URL(fileURLWithPath: "/tmp/video.mp4")
        #expect(wallpaper.url(for: nil) == wallpaper.staticURL)
    }
}

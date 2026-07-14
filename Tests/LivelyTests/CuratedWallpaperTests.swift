import Testing
@testable import LivelyCore
import Foundation

struct CuratedWallpaperTests {
    @Test func curatedListIsNotEmptyAndHasValidURLs() {
        #expect(!CuratedWallpaper.curatedList.isEmpty)
        for wallpaper in CuratedWallpaper.curatedList {
            #expect(!wallpaper.id.isEmpty)
            #expect(!wallpaper.name.isEmpty)
            #expect(!wallpaper.creator.isEmpty)
            #expect(wallpaper.remoteURL.scheme == "https")
            #expect(wallpaper.thumbnailURL.scheme == "https")
        }
    }
}

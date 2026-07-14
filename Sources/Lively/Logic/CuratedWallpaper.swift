import Foundation

public struct CuratedWallpaper: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let creator: String
    public let remoteURL: URL
    public let thumbnailURL: URL

    public init(id: String, name: String, creator: String, remoteURL: URL, thumbnailURL: URL) {
        self.id = id
        self.name = name
        self.creator = creator
        self.remoteURL = remoteURL
        self.thumbnailURL = thumbnailURL
    }

    public static let curatedList: [CuratedWallpaper] = [
        CuratedWallpaper(
            id: "forest-stream",
            name: "Forest Stream",
            creator: "Mixkit",
            remoteURL: URL(string: "https://assets.mixkit.co/videos/preview/mixkit-forest-stream-in-the-sunlight-529-large.mp4")!,
            thumbnailURL: URL(string: "https://images.unsplash.com/photo-1475113548554-5a36f1f523d6?w=300")!
        ),
        CuratedWallpaper(
            id: "foggy-pine",
            name: "Foggy Pine Forest",
            creator: "Mixkit",
            remoteURL: URL(string: "https://assets.mixkit.co/videos/preview/mixkit-cinematic-foggy-pine-forest-5100-large.mp4")!,
            thumbnailURL: URL(string: "https://images.unsplash.com/photo-1502082553048-f009c37129b9?w=300")!
        ),
        CuratedWallpaper(
            id: "rain-window",
            name: "Rain on Window",
            creator: "Mixkit",
            remoteURL: URL(string: "https://assets.mixkit.co/videos/preview/mixkit-rain-falling-on-a-window-at-night-1522-large.mp4")!,
            thumbnailURL: URL(string: "https://images.unsplash.com/photo-1428908728789-d2de25dbd4e2?w=300")!
        ),
        CuratedWallpaper(
            id: "aurora",
            name: "Aurora Borealis",
            creator: "Mixkit",
            remoteURL: URL(string: "https://assets.mixkit.co/videos/preview/mixkit-mysterious-aurora-borealis-in-the-sky-12151-large.mp4")!,
            thumbnailURL: URL(string: "https://images.unsplash.com/photo-1579033461380-adb47c3eb938?w=300")!
        )
    ]
}

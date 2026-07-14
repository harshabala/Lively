import Foundation

/// A user-saved video kept in the library for reuse as a wallpaper.
public struct LibraryWallpaper: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var name: String
    /// Relative filename under the library directory (e.g. `{id}.mp4`).
    public let fileName: String
    public let addedAt: Date

    public init(id: String, name: String, fileName: String, addedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.addedAt = addedAt
    }
}

import Foundation
import AppKit

public enum DynamicMode: String, Codable, CaseIterable, Sendable {
    case staticVideo = "static"
    case appearance = "appearance" // Light/Dark
}

public enum VideoGravity: String, Codable, CaseIterable, Sendable {
    case fill = "fill"    // resizeAspectFill — crops to fill screen
    case fit = "fit"      // resizeAspect — letterboxes to fit screen
}

public struct DynamicWallpaper: Codable, Equatable, Sendable {
    public var mode: DynamicMode = .staticVideo
    
    // For .staticVideo
    public var staticURL: URL?
    
    // For .appearance
    public var lightURL: URL?
    public var darkURL: URL?
    
    // Display settings
    public var videoGravity: VideoGravity = .fill
    public var isMuted: Bool = true
    public var volume: Float = 0.0

    public init() {}
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decode(DynamicMode.self, forKey: .mode)
        staticURL = try container.decodeIfPresent(URL.self, forKey: .staticURL)
        lightURL = try container.decodeIfPresent(URL.self, forKey: .lightURL)
        darkURL = try container.decodeIfPresent(URL.self, forKey: .darkURL)
        // New fields — fall back to defaults if missing (backward compatibility)
        videoGravity = try container.decodeIfPresent(VideoGravity.self, forKey: .videoGravity) ?? .fill
        isMuted = try container.decodeIfPresent(Bool.self, forKey: .isMuted) ?? true
        volume = try container.decodeIfPresent(Float.self, forKey: .volume) ?? 0.0
    }
    
    // Helpers
    
    public func url(for appearance: NSAppearance?) -> URL? {
        switch mode {
        case .staticVideo:
            return staticURL
        case .appearance:
            let isDark = appearance?.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return isDark ? (darkURL ?? lightURL) : (lightURL ?? darkURL)
        }
    }
}

// MARK: - Video Validation

/// The video file extensions that Lively accepts as wallpapers.
public let supportedVideoExtensions: Set<String> = ["mp4", "mov", "m4v"]

/// Returns `true` when `url` points to a video file format supported by Lively.
public func isValidLivelyVideoFile(_ url: URL) -> Bool {
    supportedVideoExtensions.contains(url.pathExtension.lowercased())
}

import Foundation
import AVFoundation
import CoreMedia

/// Video codecs Lively plays. Everything else is rejected before assignment.
public let supportedVideoCodecs: Set<FourCharCode> = [
    kCMVideoCodecType_H264,
    kCMVideoCodecType_HEVC,
]

/// Validates a candidate wallpaper file: extension, readability, container
/// integrity, and codec allow-list. Used by every path that accepts a file
/// (display cards, drag-and-drop, and the library) so the README promise
/// "other codecs are rejected with a clear error" holds everywhere.
public enum VideoValidator {

    public enum Outcome: Equatable, Sendable {
        case valid
        case invalid(String)
    }

    public static let unsupportedFormatMessage = "Unsupported format. Use .mp4, .mov, or .m4v"
    public static let unsupportedCodecMessage = "Only H.264 and HEVC are supported. Re-encode this file."
    public static let missingFileMessage = "File not found or not accessible."
    public static let unreadableMessage = "This file is damaged or incomplete and can’t be played."
    public static let noVideoTrackMessage = "No video track found in this file."

    /// Pure codec decision for the codec FourCCs of every video track format.
    public static func evaluate(codecs: [FourCharCode]) -> Outcome {
        guard !codecs.isEmpty else { return .invalid(unsupportedCodecMessage) }
        return codecs.allSatisfy(supportedVideoCodecs.contains) ? .valid : .invalid(unsupportedCodecMessage)
    }

    public static func validate(_ url: URL) async -> Outcome {
        guard isValidLivelyVideoFile(url) else { return .invalid(unsupportedFormatMessage) }

        let scopeGranted = url.startAccessingSecurityScopedResource()
        defer { if scopeGranted { url.stopAccessingSecurityScopedResource() } }

        guard FileManager.default.isReadableFile(atPath: url.path) else {
            return .invalid(missingFileMessage)
        }

        let asset = AVURLAsset(url: url)
        // A truncated or corrupt container fails here (missing moov atom, etc.).
        guard let (isPlayable, duration) = try? await asset.load(.isPlayable, .duration) else {
            return .invalid(unreadableMessage)
        }
        guard let tracks = try? await asset.loadTracks(withMediaType: .video), !tracks.isEmpty else {
            return .invalid(noVideoTrackMessage)
        }

        var codecs: [FourCharCode] = []
        for track in tracks {
            guard let descriptions = try? await track.load(.formatDescriptions) else {
                return .invalid(unreadableMessage)
            }
            codecs.append(contentsOf: descriptions.map(CMFormatDescriptionGetMediaSubType))
        }

        let codecOutcome = evaluate(codecs: codecs)
        guard codecOutcome == .valid else { return codecOutcome }

        guard isPlayable, duration.isNumeric, duration.seconds > 0 else {
            return .invalid(unreadableMessage)
        }
        return .valid
    }
}

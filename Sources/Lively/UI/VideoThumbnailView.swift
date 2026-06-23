import SwiftUI
import AppKit
import AVFoundation

// MARK: - Video Thumbnail Generator

@MainActor private let thumbnailCache = NSCache<NSURL, NSImage>()

@MainActor func generateThumbnail(for url: URL) async -> NSImage? {
    if let cached = thumbnailCache.object(forKey: url as NSURL) {
        return cached
    }

    let nsImage = await Task.detached { () -> NSImage? in
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 240)
        
        do {
            let (image, _) = try await generator.image(at: .init(seconds: 1, preferredTimescale: 600))
            return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        } catch {
            LivelyLogger.videoPreview.error("Thumbnail generation failed: \(error.localizedDescription)")
            return nil
        }
    }.value
    
    if let nsImage {
        thumbnailCache.setObject(nsImage, forKey: url as NSURL)
    }
    
    return nsImage
}

// MARK: - Video Thumbnail View

struct VideoThumbnailView: View {
    let url: URL
    @State private var thumbnail: NSImage?
    @State private var isLoading = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 90)
                    .clipped()
                    .cornerRadius(6)
                    .transition(.opacity.combined(with: .blurReplace))
            } else if isLoading {
                // Loading state
                RoundedRectangle(cornerRadius: 6)
                    .fill(LivelyBrand.accent.opacity(0.72))
                    .frame(maxWidth: .infinity)
                    .frame(height: 90)
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
            } else {
                // Failed to generate
                RoundedRectangle(cornerRadius: 6)
                    .fill(LivelyBrand.accent.opacity(0.72))
                    .frame(maxWidth: .infinity)
                    .frame(height: 90)
                    .overlay {
                        VStack(spacing: 4) {
                            Image(systemName: "film")
                                .font(.system(size: 18))
                                .foregroundStyle(LivelyBrand.mutedForeground)
                            Text("No preview")
                                .font(.system(size: 10))
                                .foregroundStyle(LivelyBrand.mutedForeground)
                        }
                    }
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.0), value: thumbnail != nil)
        .accessibilityHidden(true)
        .task(id: url) {
            isLoading = true
            thumbnail = await generateThumbnail(for: url)
            isLoading = false
        }
    }
}

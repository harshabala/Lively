import SwiftUI
import AppKit
import AVFoundation

// MARK: - Video Thumbnail Generator

@MainActor private let thumbnailCache = NSCache<NSURL, NSImage>()

@MainActor func generateThumbnail(for url: URL) async -> NSImage? {
    if let cached = thumbnailCache.object(forKey: url as NSURL) {
        return cached
    }

    let hasAccess = url.startAccessingSecurityScopedResource()
    defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }

    let asset = AVURLAsset(url: url)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 400, height: 240)

    do {
        let (image, _) = try await generator.image(at: .init(seconds: 1, preferredTimescale: 600))
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        thumbnailCache.setObject(nsImage, forKey: url as NSURL)
        return nsImage
    } catch {
        LivelyLogger.videoPreview.error("Thumbnail generation failed: \(error.localizedDescription)")
        return nil
    }
}

// MARK: - Video Thumbnail View

@Observable
@MainActor
private final class ThumbnailLoader {
    var image: NSImage?
    var isLoading = true

    func load(url: URL) async {
        isLoading = true
        image = await generateThumbnail(for: url)
        isLoading = false
    }

    func reset() {
        image = nil
        isLoading = true
    }
}

struct VideoThumbnailView: View {
    let url: URL
    @State private var loader = ThumbnailLoader()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let thumbnail = loader.image {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 90)
                    .clipped()
                    .clipShape(.rect(cornerRadius: LivelyBrand.Radius.sm))
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 4)),
                        removal: .opacity
                    ))
            } else if loader.isLoading {
                RoundedRectangle(cornerRadius: LivelyBrand.Radius.sm)
                    .fill(LivelyBrand.accent.opacity(0.72))
                    .frame(maxWidth: .infinity)
                    .frame(height: 90)
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                    .transition(.opacity)
            } else {
                RoundedRectangle(cornerRadius: LivelyBrand.Radius.sm)
                    .fill(LivelyBrand.accent.opacity(0.72))
                    .frame(maxWidth: .infinity)
                    .frame(height: 90)
                    .overlay {
                        VStack(spacing: 4) {
                            Image(systemName: "film")
                                .font(.system(size: 18))
                                .foregroundStyle(LivelyBrand.mutedForeground)
                            Text("No preview")
                                .font(LivelyBrand.Typography.footnote)
                                .foregroundStyle(LivelyBrand.mutedForeground)
                        }
                    }
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : LivelyBrand.Motion.normal, value: loader.image != nil)
        .animation(reduceMotion ? nil : LivelyBrand.Motion.fast, value: loader.isLoading)
        .onChange(of: url) { _, _ in loader.reset() }
        .task(id: url) { await loader.load(url: url) }
    }
}

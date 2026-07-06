import SwiftUI
import AppKit

public struct AboutView: View {
    public init() {}

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    public var body: some View {
        HStack(alignment: .top, spacing: LivelyBrand.Spacing.xl) {
            VStack(alignment: .leading, spacing: LivelyBrand.Spacing.lg) {
                HStack(alignment: .top, spacing: LivelyBrand.Spacing.lg) {
                    if let appIcon = NSImage(named: NSImage.applicationIconName) {
                        Image(nsImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    } else {
                        Image(systemName: "play.tv.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                            .foregroundStyle(LivelyBrand.accent)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lively")
                            .font(LivelyBrand.Typography.title)
                            .foregroundStyle(LivelyBrand.foreground)

                        Text(appVersion)
                            .font(LivelyBrand.Typography.mono)
                            .foregroundStyle(LivelyBrand.mutedForeground)

                        Text("Video wallpapers for each Space on your Mac.")
                            .font(LivelyBrand.Typography.caption)
                            .foregroundStyle(LivelyBrand.mutedForeground)
                            .padding(.top, LivelyBrand.Spacing.sm)
                    }
                }

                if let releasesURL = URL(string: "https://github.com/harshabala/Lively/releases") {
                    Link("View releases on GitHub", destination: releasesURL)
                        .font(LivelyBrand.Typography.caption)
                }
            }

            Divider()
                .overlay(LivelyBrand.border.opacity(0.35))
                .padding(.horizontal, LivelyBrand.Spacing.sm)

            VStack(alignment: .leading, spacing: LivelyBrand.Spacing.lg) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Formats")
                        .font(LivelyBrand.Typography.caption.weight(.bold))
                        .foregroundStyle(LivelyBrand.foreground.opacity(0.8))
                    Text("H.264 · HEVC (H.265)")
                        .font(LivelyBrand.Typography.caption)
                        .foregroundStyle(LivelyBrand.mutedForeground)
                    Text("MP4 · MOV · M4V · Up to 4K")
                        .font(LivelyBrand.Typography.caption)
                        .foregroundStyle(LivelyBrand.mutedForeground)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("File Size")
                        .font(LivelyBrand.Typography.caption.weight(.bold))
                        .foregroundStyle(LivelyBrand.foreground.opacity(0.8))
                    Text("No limit. Hardware-accelerated decoding for full 4K playback.")
                        .font(LivelyBrand.Typography.caption)
                        .foregroundStyle(LivelyBrand.mutedForeground)
                        .lineLimit(2)
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
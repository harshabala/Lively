import SwiftUI
import AppKit

public struct AboutView: View {
    /// Compact layout for the Settings sidebar pane (matches design collage).
    public var compact: Bool

    public init(compact: Bool = false) {
        self.compact = compact
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    public var body: some View {
        if compact {
            compactBody
        } else {
            legacyBody
        }
    }

    // MARK: - Settings → About (collage)

    private var compactBody: some View {
        VStack(spacing: LivelyBrand.Spacing.lg) {
            VStack(spacing: LivelyBrand.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LivelyBrand.primary.opacity(0.12))
                        .frame(width: 64, height: 64)
                    if let appIcon = NSImage(named: NSImage.applicationIconName) {
                        Image(nsImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                    } else {
                        Image(systemName: "play.tv.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(LivelyBrand.primary)
                    }
                }

                Text("Lively")
                    .font(LivelyBrand.Typography.title)
                Text(appVersion)
                    .font(LivelyBrand.Typography.mono)
                    .foregroundStyle(LivelyBrand.mutedForeground)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, LivelyBrand.Spacing.sm)

            VStack(spacing: 0) {
                linkRow(title: "View on GitHub", systemImage: "chevron.left.forwardslash.chevron.right", url: githubURL)
                Divider().overlay(LivelyBrand.border.opacity(0.3))
                linkRow(title: "Report an Issue", systemImage: "exclamationmark.bubble", url: issuesURL)
                Divider().overlay(LivelyBrand.border.opacity(0.3))
                linkRow(title: "Privacy Policy", systemImage: "hand.raised", url: privacyURL)
            }
            .background(
                RoundedRectangle(cornerRadius: LivelyBrand.Radius.lg)
                    .fill(LivelyBrand.card.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: LivelyBrand.Radius.lg)
                    .strokeBorder(LivelyBrand.border.opacity(0.35))
            )

            Text(String(format: "© %d Harsha Balakrishnan. All rights reserved.", Calendar.current.component(.year, from: Date())))
                .font(LivelyBrand.Typography.footnote)
                .foregroundStyle(LivelyBrand.mutedForeground)
                .frame(maxWidth: .infinity)
                .padding(.bottom, LivelyBrand.Spacing.sm)
        }
    }

    private func linkRow(title: String, systemImage: String, url: URL?) -> some View {
        Button {
            if let url {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: LivelyBrand.Spacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LivelyBrand.primary)
                    .frame(width: 20)
                Text(title)
                    .font(LivelyBrand.Typography.body.weight(.medium))
                    .foregroundStyle(LivelyBrand.foreground)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LivelyBrand.mutedForeground)
            }
            .padding(.horizontal, LivelyBrand.Spacing.lg)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .focusEffectDisabled()
        .disabled(url == nil)
        .accessibilityLabel(title)
        .accessibilityHint("Opens in browser")
    }

    private var githubURL: URL? {
        URL(string: "https://github.com/harshabala/Lively")
    }

    private var issuesURL: URL? {
        URL(string: "https://github.com/harshabala/Lively/issues")
    }

    private var privacyURL: URL? {
        URL(string: "https://github.com/harshabala/Lively/blob/master/README.md#privacy")
    }

    // MARK: - Legacy layout (if reused elsewhere)

    private var legacyBody: some View {
        HStack(alignment: .top, spacing: LivelyBrand.Spacing.xl) {
            VStack(alignment: .leading, spacing: LivelyBrand.Spacing.lg) {
                HStack(alignment: .top, spacing: LivelyBrand.Spacing.lg) {
                    if let appIcon = NSImage(named: NSImage.applicationIconName) {
                        Image(nsImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                            .shadow(
                                color: LivelyBrand.Shadow.color,
                                radius: LivelyBrand.Shadow.radius,
                                x: LivelyBrand.Shadow.x,
                                y: LivelyBrand.Shadow.y
                            )
                    } else {
                        Image(systemName: "play.tv.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                            .foregroundStyle(LivelyBrand.primary)
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

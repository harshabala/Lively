import SwiftUI
import AppKit

public enum LivelyTab: Hashable {
    case displays
    case settings
}

public struct SettingsContainerView: View {
    @ObservedObject public var spaceMonitor: SpaceMonitor
    public let configStore: ConfigStore
    @EnvironmentObject var wallpaperController: WallpaperController
    @ObservedObject private var preferences = AppPreferences.shared
    @ObservedObject private var updateChecker = UpdateChecker.shared

    @ViewState private var selectedTab: LivelyTab = .displays
    @ViewState private var settingsSection: SettingsSection = .general
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Fixed popover size — never grows with Logs content.
    public static let windowSize = CGSize(width: 620, height: 580)

    public init(spaceMonitor: SpaceMonitor, configStore: ConfigStore) {
        self.spaceMonitor = spaceMonitor
        self.configStore = configStore
    }

    public var body: some View {
        VStack(spacing: 0) {
            topChrome

            statusBanners

            ZStack {
                switch selectedTab {
                case .displays:
                    DisplaysView(spaceMonitor: spaceMonitor, configStore: configStore)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 6)),
                            removal: .opacity.combined(with: .offset(y: -4))
                        ))
                case .settings:
                    PreferencesView(
                        spaceMonitor: spaceMonitor,
                        configStore: configStore,
                        section: $settingsSection,
                        onOpenDisplays: {
                            withAnimation(reduceMotion ? nil : LivelyBrand.Motion.normal) {
                                selectedTab = .displays
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 6)),
                        removal: .opacity.combined(with: .offset(y: -4))
                    ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(reduceMotion ? nil : LivelyBrand.Motion.normal, value: selectedTab)
        }
        .frame(width: Self.windowSize.width, height: Self.windowSize.height)
        .background(LivelyBrand.background)
        .preferredColorScheme(preferences.appearance.colorScheme)
        .onChange(of: preferences.appearance) { _, newValue in
            AppPreferences.applyAppAppearance(newValue)
        }
    }

    // MARK: - Top chrome

    private var topChrome: some View {
        HStack(spacing: LivelyBrand.Spacing.md) {
            primaryTabs

            Spacer(minLength: LivelyBrand.Spacing.sm)

            HStack(spacing: LivelyBrand.Spacing.sm) {
                chromeActionButton(
                    title: wallpaperController.isPaused ? "Resume Lively" : "Pause Lively",
                    systemImage: wallpaperController.isPaused ? "play.fill" : "pause.fill",
                    tint: LivelyBrand.foreground,
                    isDestructive: false
                ) {
                    wallpaperController.togglePause()
                }
                .help(wallpaperController.isPaused ? "Resume wallpapers" : "Pause wallpapers")
                .accessibilityLabel(wallpaperController.isPaused ? "Resume Lively" : "Pause Lively")

                chromeActionButton(
                    title: "Quit Lively",
                    systemImage: "power",
                    tint: LivelyBrand.destructive,
                    isDestructive: true
                ) {
                    NSApp.terminate(nil)
                }
                .help("Quit Lively")
                .accessibilityLabel("Quit Lively")
            }
        }
        .padding(.horizontal, LivelyBrand.Spacing.lg)
        .padding(.top, LivelyBrand.Spacing.lg)
        .padding(.bottom, LivelyBrand.Spacing.md)
    }

    private var primaryTabs: some View {
        HStack(spacing: 4) {
            primaryTabButton(title: "Displays", systemImage: "display", tab: .displays)
            primaryTabButton(title: "Settings", systemImage: "gearshape", tab: .settings)
        }
    }

    private func primaryTabButton(title: String, systemImage: String, tab: LivelyTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(reduceMotion ? nil : LivelyBrand.Motion.normal) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    Text(title)
                        .font(LivelyBrand.Typography.caption.weight(.semibold))
                }
                .foregroundStyle(isSelected ? LivelyBrand.foreground : LivelyBrand.mutedForeground)
                .padding(.horizontal, LivelyBrand.Spacing.md)
                .padding(.vertical, LivelyBrand.Spacing.sm)

                Rectangle()
                    .fill(isSelected ? LivelyBrand.primary : Color.clear)
                    .frame(height: 2)
                    .padding(.horizontal, LivelyBrand.Spacing.sm)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func chromeActionButton(
        title: String,
        systemImage: String,
        tint: Color,
        isDestructive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(LivelyBrand.Typography.caption.weight(.medium))
                    .lineLimit(1)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                Capsule()
                    .strokeBorder(LivelyBrand.border.opacity(isDestructive ? 0.55 : 0.45), lineWidth: 1)
            )
        }
        .buttonStyle(PressScaleButtonStyle())
        .focusEffectDisabled()
    }

    // MARK: - Status banners

    @ViewBuilder
    private var statusBanners: some View {
        if let version = updateChecker.availableVersion {
            updateBanner(version: version)
        }

        if wallpaperController.isThrottled {
            statusBanner(
                icon: "thermometer.medium",
                text: "Mac running hot. Lively paused to save battery.",
                color: Color(nsColor: .systemOrange)
            )
        } else if wallpaperController.isBatteryPaused {
            statusBanner(
                icon: wallpaperController.isForcedBatteryPause ? "battery.0percent" : "battery.25",
                text: batteryBannerText,
                color: wallpaperController.isForcedBatteryPause
                    ? Color(nsColor: .systemOrange)
                    : LivelyBrand.mutedForeground
            )
        } else if wallpaperController.isPaused {
            statusBanner(
                icon: "pause.circle.fill",
                text: "Wallpapers paused. Press Resume Lively to play again.",
                color: LivelyBrand.mutedForeground
            )
        }
    }

    private var batteryBannerText: String {
        let pct = wallpaperController.batteryLevelPercent.map { "\(Int($0.rounded()))%" } ?? "unknown"
        if wallpaperController.isForcedBatteryPause {
            return "Battery \(pct). Wallpapers paused (required at \(Int(AppPreferences.forcedBatteryPausePercent))% or below)."
        }
        let threshold = Int(preferences.batteryPauseThreshold.rounded())
        return "Battery \(pct). Wallpapers paused (threshold \(threshold)%). Plug in to resume."
    }

    private func updateBanner(version: String) -> some View {
        HStack(spacing: LivelyBrand.Spacing.sm) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(LivelyBrand.primary)
            Text("Update available: v\(version)")
                .font(LivelyBrand.Typography.caption.weight(.semibold))
                .foregroundStyle(LivelyBrand.foreground)
                .lineLimit(1)
            Spacer(minLength: 4)
            Button("View") {
                updateChecker.openReleasePage()
            }
            .buttonStyle(.plain)
            .font(LivelyBrand.Typography.caption.weight(.semibold))
            .foregroundStyle(LivelyBrand.primary)
            .focusEffectDisabled()
            .accessibilityLabel("View update on GitHub")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, LivelyBrand.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: 36, alignment: .leading)
        .background(LivelyBrand.primary.opacity(0.12))
        .accessibilityElement(children: .combine)
    }

    private func statusBanner(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: LivelyBrand.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .font(LivelyBrand.Typography.caption)
                .foregroundStyle(LivelyBrand.foreground)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(text)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, LivelyBrand.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: 36, alignment: .leading)
        .background(color.opacity(0.10))
    }
}

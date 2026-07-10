import SwiftUI

public enum LivelyTab: Hashable {
    case displays
    case settings
}

public struct SettingsContainerView: View {
    @ObservedObject public var spaceMonitor: SpaceMonitor
    public let configStore: ConfigStore
    @EnvironmentObject var wallpaperController: WallpaperController
    
    @State private var selectedTab: LivelyTab = .displays
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(spaceMonitor: SpaceMonitor, configStore: ConfigStore) {
        self.spaceMonitor = spaceMonitor
        self.configStore = configStore
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                PillTabBar(
                    tabs: [("Displays", .displays), ("Settings", .settings)],
                    selection: $selectedTab
                )
                
                Spacer()
                
                Button(action: {
                    wallpaperController.togglePause()
                }) {
                    pauseButtonLabel
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel(wallpaperController.isPaused ? "Resume wallpapers" : "Pause wallpapers")
                .help(wallpaperController.isPaused ? "Resume wallpapers" : "Pause wallpapers")
                .padding(.horizontal, LivelyBrand.Spacing.sm)
                .padding(.vertical, LivelyBrand.Spacing.xs)
                .background(Capsule().fill(LivelyBrand.mutedForeground.opacity(0.12)))
            }
            .padding(.horizontal, LivelyBrand.Spacing.xl)
            .padding(.top, LivelyBrand.Spacing.lg)
            .padding(.bottom, LivelyBrand.Spacing.md)
            
            Divider()
                .overlay(LivelyBrand.border.opacity(0.45))
            
            if wallpaperController.isThrottled {
                HStack(spacing: LivelyBrand.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Mac running hot. Lively paused to save battery.")
                        .font(LivelyBrand.Typography.caption)
                        .foregroundColor(.primary)
                }
                .padding(.vertical, LivelyBrand.Spacing.sm)
                .padding(.horizontal, LivelyBrand.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.15))
            }
            
            ZStack {
                switch selectedTab {
                case .displays:
                    DisplaysView(spaceMonitor: spaceMonitor, configStore: configStore)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 6)),
                            removal: .opacity.combined(with: .offset(y: -4))
                        ))
                case .settings:
                    PreferencesView(configStore: configStore)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 6)),
                            removal: .opacity.combined(with: .offset(y: -4))
                        ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(reduceMotion ? nil : LivelyBrand.Motion.normal, value: selectedTab)
        }
        .frame(width: 480, height: 560)
        .background(
            ZStack {
                LivelyBrand.backgroundGradient
                    .ignoresSafeArea()
                    .opacity(0.72)
                
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
            }
        )
    }

    @ViewBuilder
    private var pauseButtonLabel: some View {
        let image = Image(systemName: wallpaperController.isPaused ? "play.fill" : "pause.fill")
            .font(.system(size: 11, weight: .semibold))
            .frame(minWidth: 32, minHeight: 32)
            .contentShape(Rectangle())

        if reduceMotion {
            image
        } else {
            image.contentTransition(.symbolEffect(.replace))
        }
    }
}
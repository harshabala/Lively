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
    
    public init(spaceMonitor: SpaceMonitor, configStore: ConfigStore) {
        self.spaceMonitor = spaceMonitor
        self.configStore = configStore
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Custom Navigation Header
            HStack {
                Picker("", selection: $selectedTab) {
                    Text("Displays").tag(LivelyTab.displays)
                    Text("Settings").tag(LivelyTab.settings)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                
                Spacer()
                
                // Action Chip
                HStack(spacing: 12) {
                    Button(action: {
                        wallpaperController.togglePause()
                    }) {
                        Image(systemName: wallpaperController.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(wallpaperController.isPaused ? "Resume Wallpapers" : "Pause Wallpapers")
                    
                    Divider()
                        .frame(height: 12)
                        .background(Color.secondary.opacity(0.5))
                    
                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Quit Lively")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.secondary.opacity(0.15)))
            }
            .padding(.horizontal, LivelyBrand.Spacing.xl)
            .padding(.top, LivelyBrand.Spacing.lg)
            .padding(.bottom, LivelyBrand.Spacing.md)
            
            Divider()
                .overlay(LivelyBrand.border.opacity(0.45))
            
            // Content Area
            ZStack {
                switch selectedTab {
                case .displays:
                    DisplaysView(spaceMonitor: spaceMonitor, configStore: configStore)
                case .settings:
                    PreferencesView(configStore: configStore)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
}

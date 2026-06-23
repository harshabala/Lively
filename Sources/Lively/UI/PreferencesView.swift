import SwiftUI
import ServiceManagement

public struct PreferencesView: View {
    public let configStore: ConfigStore
    
    @State private var showResetConfirm = false
    
    public init(configStore: ConfigStore) {
        self.configStore = configStore
    }
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: LivelyBrand.Spacing.md) {
                // General Settings
                settingsRow(title: "General", icon: "person.fill", iconColor: LivelyBrand.primary) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Launch at Login")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Start Lively automatically when you log in to your Mac.")
                                .font(.system(size: 12))
                                .foregroundStyle(LivelyBrand.mutedForeground)
                        }
                        Spacer()
                        Toggle("", isOn: launchAtLoginBinding)
                            .toggleStyle(.switch)
                            .tint(LivelyBrand.primary)
                            .labelsHidden()
                    }
                }
                
                // Data & Reset
                settingsRow(title: "Data & Reset", icon: "cylinder.split.1x2.fill", iconColor: LivelyBrand.primary) {
                    HStack {
                        Text("Resetting will clear all wallpaper assignments, displays,\nand preferences.")
                            .font(.system(size: 12))
                            .foregroundStyle(LivelyBrand.mutedForeground)
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            showResetConfirm = true
                        } label: {
                            Text("Reset All Data...")
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                        .background(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.red.opacity(0.3), lineWidth: 1))
                        .alert("Reset All Data?", isPresented: $showResetConfirm) {
                            Button("Cancel", role: .cancel) { }
                            Button("Reset", role: .destructive) {
                                configStore.clearAllData()
                            }
                        } message: {
                            Text("This will remove all wallpapers and settings. This cannot be undone.")
                        }
                    }
                }
                
                // Logs
                settingsRow(title: "Logs", icon: "doc.text.fill", iconColor: LivelyBrand.primary) {
                    LoggerView()
                }
                
                // About
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(LivelyBrand.primary)
                            .frame(width: 24, alignment: .center)
                        
                        Text("About Lively")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(LivelyBrand.foreground)
                    }
                    
                    AboutView()
                }
                .padding(LivelyBrand.Spacing.lg)
                .background(RoundedRectangle(cornerRadius: LivelyBrand.Radius.lg).fill(.ultraThinMaterial))
                .overlay(RoundedRectangle(cornerRadius: LivelyBrand.Radius.lg).strokeBorder(LivelyBrand.border.opacity(0.35)))
                
                // Copyright
                Text(String(format: "© %d Lively App. All rights reserved.", Calendar.current.component(.year, from: Date())))
                    .font(.system(size: 11))
                    .foregroundStyle(LivelyBrand.mutedForeground.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            }
            .padding(.horizontal, LivelyBrand.Spacing.xl)
            .padding(.vertical, LivelyBrand.Spacing.xl)
        }
        .foregroundStyle(LivelyBrand.foreground)
    }
    
    private func settingsRow<Content: View>(
        title: String,
        icon: String,
        iconColor: Color = LivelyBrand.primary,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 20) {
            // Icon & Title
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 24, alignment: .center)
                
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LivelyBrand.foreground)
            }
            .frame(width: 130, alignment: .leading)
            .padding(.top, 2) // Align visually with content text
            
            // Content
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(LivelyBrand.Spacing.lg)
        .background(RoundedRectangle(cornerRadius: LivelyBrand.Radius.lg).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: LivelyBrand.Radius.lg).strokeBorder(LivelyBrand.border.opacity(0.35)))
    }
    
    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { newValue in
                try? newValue
                    ? SMAppService.mainApp.register()
                    : SMAppService.mainApp.unregister()
            }
        )
    }
}

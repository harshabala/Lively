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
            VStack(alignment: .leading, spacing: LivelyBrand.Spacing.lg) {
                // General Settings
                VStack(alignment: .leading, spacing: LivelyBrand.Spacing.md) {
                    sectionLabel("GENERAL", icon: "person.fill")
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(isOn: launchAtLoginBinding) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Launch at Login")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Start Lively automatically when you log in to your Mac.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(LivelyBrand.mutedForeground)
                            }
                        }
                        .toggleStyle(.switch)
                        .tint(LivelyBrand.primary)
                    }
                    .padding(LivelyBrand.Spacing.lg)
                    .background(RoundedRectangle(cornerRadius: LivelyBrand.Radius.lg).fill(.ultraThinMaterial))
                    .overlay(RoundedRectangle(cornerRadius: LivelyBrand.Radius.lg).strokeBorder(LivelyBrand.border.opacity(0.35)))
                }
                
                // Data
                VStack(alignment: .leading, spacing: LivelyBrand.Spacing.md) {
                    sectionLabel("DATA & RESET", icon: "cylinder.split.1x2.fill")
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Resetting will clear all wallpaper assignments, displays, and preferences.")
                            .font(.system(size: 12))
                            .foregroundStyle(LivelyBrand.mutedForeground)
                        
                        Button(role: .destructive) {
                            showResetConfirm = true
                        } label: {
                            Text("Reset All Data...")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.large)
                        .alert("Reset All Data?", isPresented: $showResetConfirm) {
                            Button("Cancel", role: .cancel) { }
                            Button("Reset", role: .destructive) {
                                configStore.clearAllData()
                            }
                        } message: {
                            Text("This will remove all wallpapers and settings. This cannot be undone.")
                        }
                    }
                    .padding(LivelyBrand.Spacing.lg)
                    .background(RoundedRectangle(cornerRadius: LivelyBrand.Radius.lg).fill(.ultraThinMaterial))
                    .overlay(RoundedRectangle(cornerRadius: LivelyBrand.Radius.lg).strokeBorder(LivelyBrand.border.opacity(0.35)))
                }
                
                // Logs
                VStack(alignment: .leading, spacing: LivelyBrand.Spacing.md) {
                    sectionLabel("LOGS", icon: "doc.text.fill")
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("View and copy application logs for troubleshooting.")
                            .font(.system(size: 12))
                            .foregroundStyle(LivelyBrand.mutedForeground)
                        
                        LoggerView()
                    }
                    .padding(LivelyBrand.Spacing.lg)
                    .background(RoundedRectangle(cornerRadius: LivelyBrand.Radius.lg).fill(.ultraThinMaterial))
                    .overlay(RoundedRectangle(cornerRadius: LivelyBrand.Radius.lg).strokeBorder(LivelyBrand.border.opacity(0.35)))
                }
                
                // About
                VStack(alignment: .leading, spacing: LivelyBrand.Spacing.md) {
                    sectionLabel("ABOUT LIVELY", icon: "info.circle.fill")
                    
                    AboutView()
                        .padding(LivelyBrand.Spacing.lg)
                        .background(RoundedRectangle(cornerRadius: LivelyBrand.Radius.lg).fill(.ultraThinMaterial))
                        .overlay(RoundedRectangle(cornerRadius: LivelyBrand.Radius.lg).strokeBorder(LivelyBrand.border.opacity(0.35)))
                }
                
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
    
    private func sectionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(LivelyBrand.mutedForeground.opacity(0.8))
            .textCase(.uppercase)
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

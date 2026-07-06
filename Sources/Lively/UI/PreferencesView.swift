import SwiftUI
import ServiceManagement

public struct PreferencesView: View {
    public let configStore: ConfigStore

    @State private var showResetConfirm = false
    @State private var configErrorMessage: String?
    @State private var launchAtLoginError: String?

    public init(configStore: ConfigStore) {
        self.configStore = configStore
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LivelyBrand.Spacing.md) {
                if let configErrorMessage {
                    HStack(spacing: LivelyBrand.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(LivelyBrand.destructive)
                        Text(configErrorMessage)
                            .font(LivelyBrand.Typography.caption)
                            .foregroundStyle(LivelyBrand.foreground)
                    }
                    .padding(LivelyBrand.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: LivelyBrand.Radius.md)
                            .fill(LivelyBrand.destructive.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: LivelyBrand.Radius.md)
                            .strokeBorder(LivelyBrand.destructive.opacity(0.3))
                    )
                }

                settingsRow(title: "General", icon: "gearshape.fill", iconColor: LivelyBrand.primary) {
                    VStack(alignment: .leading, spacing: LivelyBrand.Spacing.sm) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Launch at Login")
                                    .font(LivelyBrand.Typography.body.weight(.semibold))
                                Text("Start Lively automatically when you log in to your Mac.")
                                    .font(LivelyBrand.Typography.caption)
                                    .foregroundStyle(LivelyBrand.mutedForeground)
                            }
                            Spacer()
                            Toggle("", isOn: launchAtLoginBinding)
                                .toggleStyle(.switch)
                                .tint(LivelyBrand.primary)
                                .labelsHidden()
                                .accessibilityLabel("Launch at Login")
                                .accessibilityValue(launchAtLoginEnabled ? "On" : "Off")
                        }
                        if let launchAtLoginError {
                            Text(launchAtLoginError)
                                .font(LivelyBrand.Typography.footnote)
                                .foregroundStyle(LivelyBrand.destructive)
                        }
                    }
                }

                settingsRow(title: "Data & Reset", icon: "cylinder.split.1x2.fill", iconColor: LivelyBrand.primary) {
                    HStack {
                        Text("Clears wallpaper assignments, display pairings, and preferences.")
                            .font(LivelyBrand.Typography.caption)
                            .foregroundStyle(LivelyBrand.mutedForeground)

                        Spacer()

                        Button(role: .destructive) {
                            showResetConfirm = true
                        } label: {
                            Text("Reset All Data...")
                                .font(LivelyBrand.Typography.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .frame(minWidth: 32, minHeight: 32)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(LivelyBrand.destructive)
                        .background(
                            RoundedRectangle(cornerRadius: LivelyBrand.Radius.sm)
                                .strokeBorder(LivelyBrand.destructive.opacity(0.3), lineWidth: 1)
                        )
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

                settingsRow(title: "Logs", icon: "doc.text.fill", iconColor: LivelyBrand.primary) {
                    LoggerView()
                }

                settingsRow(title: "About", icon: "info.circle.fill", iconColor: LivelyBrand.primary) {
                    AboutView()
                }

                Text(String(format: "© %d Harsha Balakrishnan. All rights reserved.", Calendar.current.component(.year, from: Date())))
                    .font(LivelyBrand.Typography.footnote)
                    .foregroundStyle(LivelyBrand.mutedForeground)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, LivelyBrand.Spacing.sm)
            }
            .padding(.horizontal, LivelyBrand.Spacing.xl)
            .padding(.vertical, LivelyBrand.Spacing.xl)
        }
        .scrollIndicators(.hidden)
        .foregroundStyle(LivelyBrand.foreground)
        .onReceive(configStore.errors) { error in
            let message: String
            switch error {
            case .persistFailed:
                message = "Could not save settings. Check disk space and try again."
            case .loadFailed:
                message = "Could not load saved settings. Starting fresh."
            case .bookmarkRefreshFailed, .bookmarkCreationFailed:
                message = "Could not access a video file. Re-select it in Displays."
            case .directoryCreationFailed:
                message = "Could not create the Lively data folder."
            }
            configErrorMessage = message
            AccessibilityNotification.Announcement(message).post()
        }
        .onChange(of: launchAtLoginError) { _, newValue in
            if let newValue {
                AccessibilityNotification.Announcement(newValue).post()
            }
        }
    }

    private var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    private func settingsRow<Content: View>(
        title: String,
        icon: String,
        iconColor: Color = LivelyBrand.primary,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: LivelyBrand.Spacing.md) {
            Label(title, systemImage: icon)
                .font(LivelyBrand.Typography.section)
                .foregroundStyle(iconColor)

            content()
        }
        .padding(LivelyBrand.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: LivelyBrand.Radius.lg)
                .fill(LivelyBrand.card.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: LivelyBrand.Radius.lg)
                .strokeBorder(LivelyBrand.border.opacity(0.35))
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { newValue in
                launchAtLoginError = nil
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    launchAtLoginError = "Launch at login could not be updated. The app may need to be signed for distribution."
                    LivelyLogger.config.error("Launch at login failed: \(error.localizedDescription)")
                }
            }
        )
    }
}
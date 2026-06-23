import SwiftUI
import AppKit

public struct AboutView: View {
    @State private var isCheckingForUpdates = false
    @State private var showUpdateAlert = false
    @State private var updateMessage = ""

    public init() {}

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: LivelyBrand.Spacing.lg) {
            // Header - App Icon and Name
            HStack(spacing: 16) {
                if let appIcon = NSImage(named: NSImage.applicationIconName) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                } else {
                    // Fallback icon
                    Image(systemName: "play.tv.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .foregroundStyle(LivelyBrand.accent)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lively")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(LivelyBrand.foreground)
                    
                    Text(appVersion)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(LivelyBrand.mutedForeground)
                }
            }
            
            // Description
            VStack(alignment: .leading, spacing: LivelyBrand.Spacing.sm) {
                Text("Video wallpapers that bring every Space to life.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LivelyBrand.foreground)
                
                Text("Lively runs quietly in the menu bar and fills your displays and Spaces with beautiful, looping video. Thoughtfully designed for calm focus.")
                    .font(.system(size: 13))
                    .foregroundStyle(LivelyBrand.mutedForeground)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Formats")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LivelyBrand.foreground.opacity(0.8))
                        .padding(.top, 6)
                    Text("MP4, MOV, M4V • Up to 4K")
                        .font(.system(size: 12))
                        .foregroundStyle(LivelyBrand.mutedForeground)
                }
            }
            
            // Action Button
            Button {
                checkForUpdates()
            } label: {
                HStack {
                    if isCheckingForUpdates {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text("Check for Updates")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(LivelyBrand.primary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(LivelyBrand.primary.opacity(0.3), lineWidth: 1)
            )
            .disabled(isCheckingForUpdates)
            .alert("Software Update", isPresented: $showUpdateAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(updateMessage)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func checkForUpdates() {
        isCheckingForUpdates = true
        LivelyLogger.updater.info("Simulating check for updates...")
        
        // Simulate network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isCheckingForUpdates = false
            updateMessage = "You are up to date! Lively \(appVersion) is currently the newest version available."
            showUpdateAlert = true
            LivelyLogger.updater.info("App is up to date.")
        }
    }
}

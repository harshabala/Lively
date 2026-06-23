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
        HStack(alignment: .top, spacing: LivelyBrand.Spacing.xl) {
            // Left Side - App Info
            VStack(alignment: .leading, spacing: LivelyBrand.Spacing.sm) {
                HStack(spacing: 12) {
                    // App Icon (using generic folder if not found for testing, but typically NSImage.applicationIconName)
                    if let appIcon = NSImage(named: NSImage.applicationIconName) {
                        Image(nsImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    } else {
                        // Fallback icon matching the image
                        Image(systemName: "folder.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                            .foregroundStyle(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lively")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(LivelyBrand.foreground)
                        
                        Text(appVersion)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(LivelyBrand.mutedForeground)
                    }
                }
                
                Text("Bring your desktop to life with beautiful\nanimated wallpapers.")
                    .font(.system(size: 12))
                    .foregroundStyle(LivelyBrand.mutedForeground)
                    .lineLimit(2)
                    .padding(.top, 4)
                
                Button {
                    checkForUpdates()
                } label: {
                    HStack {
                        if isCheckingForUpdates {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isCheckingForUpdates ? "Checking..." : "Check for Updates...")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .background(RoundedRectangle(cornerRadius: 6).strokeBorder(LivelyBrand.border.opacity(0.35)))
                .disabled(isCheckingForUpdates)
                .alert("Software Update", isPresented: $showUpdateAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(updateMessage)
                }
                .padding(.top, 8)
            }
            
            Divider()
                .frame(height: 100)
                .overlay(LivelyBrand.border.opacity(0.35))
            
            // Right Side - Supported Formats
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Supported Formats:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LivelyBrand.foreground.opacity(0.8))
                    Text("MP4, MOV, M4V")
                        .font(.system(size: 12))
                        .foregroundStyle(LivelyBrand.mutedForeground)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Maximum Size:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LivelyBrand.foreground.opacity(0.8))
                    Text("Unlimited. Supports full 4K movies\nusing native hardware acceleration.")
                        .font(.system(size: 12))
                        .foregroundStyle(LivelyBrand.mutedForeground)
                        .lineLimit(2)
                }
            }
            .padding(.top, 4)
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

import SwiftUI
import AppKit
import AVFoundation
import ServiceManagement
import UniformTypeIdentifiers

// MARK: - SettingsView

public struct SettingsView: View {
    @ObservedObject public var spaceMonitor: SpaceMonitor
    @ObservedObject public var configStore: ConfigStore

    public init(spaceMonitor: SpaceMonitor, configStore: ConfigStore) {
        self.spaceMonitor = spaceMonitor
        self.configStore = configStore
    }

    public var body: some View {
        ZStack {
            // Thin material window background — lets the video wallpaper bleed through.
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom titlebar area (window is full-size content view)
                titlebar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                Divider().opacity(0.3)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        screensSection
                        footerSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
            }
        }
        .frame(width: 480, height: 560)
    }

    // MARK: - Titlebar

    private var titlebar: some View {
        HStack(spacing: 14) {
            ZStack {
                Image(systemName: "play.tv.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
            }
            .liquidGlass(.regular.tint(.blue), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text("Lively")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text("Video wallpapers for every Space")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Screens Section

    private var screensSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Displays", icon: "display.2")

            if spaceMonitor.screenSpaces.isEmpty {
                detectingView
            } else {
                VStack(spacing: 10) {
                    ForEach(spaceMonitor.screenSpaces) { space in
                        ScreenCard(space: space, configStore: configStore)
                    }
                }
            }
        }
    }

    private var detectingView: some View {
        HStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.75)
            Text("Detecting displays…")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(.regular, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Toggle(isOn: launchAtLoginBinding) {
                    Label("Launch at Login", systemImage: "power")
                        .font(.system(size: 13))
                }
                .toggleStyle(.switch)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .liquidGlass(.regular, in: RoundedRectangle(cornerRadius: 12))

                Spacer()

                PauseResumeButton()

                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "xmark.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.glass)
                .tint(.red)
            }

            // Version info
            Text("Lively v1.0 — Made with ♥")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
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

// MARK: - Pause / Resume Button

private struct PauseResumeButton: View {
    @EnvironmentObject var wallpaperController: WallpaperController

    var body: some View {
        Button {
            wallpaperController.togglePause()
        } label: {
            Label(
                wallpaperController.isPaused ? "Resume" : "Pause",
                systemImage: wallpaperController.isPaused ? "play.fill" : "pause.fill"
            )
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.glass)
        .tint(wallpaperController.isPaused ? .green : .orange)
    }
}

// MARK: - Supported Video Types

private let supportedVideoTypes: [UTType] = [.mpeg4Movie, .quickTimeMovie, .movie]
private let supportedExtensions: Set<String> = ["mp4", "mov", "m4v"]

private func isValidVideoFile(_ url: URL) -> Bool {
    supportedExtensions.contains(url.pathExtension.lowercased())
}

// MARK: - Video Thumbnail Generator

@MainActor private let thumbnailCache = NSCache<NSURL, NSImage>()

@MainActor private func generateThumbnail(for url: URL) async -> NSImage? {
    if let cached = thumbnailCache.object(forKey: url as NSURL) {
        return cached
    }

    let asset = AVURLAsset(url: url)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 400, height: 240)
    
    do {
        let (image, _) = try await generator.image(at: .init(seconds: 1, preferredTimescale: 600))
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        thumbnailCache.setObject(nsImage, forKey: url as NSURL)
        return nsImage
    } catch {
        LivelyLogger.videoPreview.error("Thumbnail generation failed: \(error.localizedDescription)")
        return nil
    }
}

// MARK: - ScreenCard

private struct ScreenCard: View {
    let space: ScreenSpace
    @ObservedObject var configStore: ConfigStore
    
    // Drop targeting states
    @State private var isTargetedMain = false
    @State private var isTargetedLight = false
    @State private var isTargetedDark = false
    
    // Settings disclosure
    @State private var showSettings = false
    
    // Remove confirmation
    @State private var showRemoveConfirm = false
    
    // Environment
    @EnvironmentObject var wallpaperController: WallpaperController
    
    // Error feedback
    @State private var errorMessage: String?
    @State private var errorClearTask: Task<Void, Swift.Error>?

    private var config: SpaceConfig? {
        configStore.configs[space.spaceKey]
    }
    
    private var currentWallpaper: DynamicWallpaper {
        config?.dynamicWallpaper ?? DynamicWallpaper()
    }

    var body: some View {
        VStack(spacing: 0) {
            displayHeader
            
            Divider().opacity(0.15)
            
            // Mode Selection
            Picker("Mode", selection: Binding(
                get: { currentWallpaper.mode },
                set: { newMode in
                    var updated = currentWallpaper
                    updated.mode = newMode
                    configStore.assign(dynamicWallpaper: updated, toSpaceKey: space.spaceKey)
                }
            )) {
                Text("Static Video").tag(DynamicMode.staticVideo)
                Text("Appearance (Light/Dark)").tag(DynamicMode.appearance)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            
            if currentWallpaper.mode == .appearance {
                HStack(spacing: 12) {
                    dropZone(
                        title: "Light Mode",
                        icon: "sun.max.fill",
                        url: currentWallpaper.lightURL,
                        isTargeted: $isTargetedLight,
                        onDrop: { url in
                            var updated = currentWallpaper
                            updated.lightURL = url
                            configStore.assign(dynamicWallpaper: updated, toSpaceKey: space.spaceKey)
                        }
                    )
                    
                    dropZone(
                        title: "Dark Mode",
                        icon: "moon.stars.fill",
                        url: currentWallpaper.darkURL,
                        isTargeted: $isTargetedDark,
                        onDrop: { url in
                            var updated = currentWallpaper
                            updated.darkURL = url
                            configStore.assign(dynamicWallpaper: updated, toSpaceKey: space.spaceKey)
                        }
                    )
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            } else {
                dropZone(
                    title: "Static Wallpaper",
                    icon: "film",
                    url: currentWallpaper.staticURL,
                    isTargeted: $isTargetedMain,
                    onDrop: { url in
                        var updated = currentWallpaper
                        updated.staticURL = url
                        configStore.assign(dynamicWallpaper: updated, toSpaceKey: space.spaceKey)
                    }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            
            // Per-video display settings (only when a wallpaper is assigned)
            if config != nil {
                displaySettingsSection
            }
        }
        .liquidGlass(.regular, in: RoundedRectangle(cornerRadius: 14))
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
        .animation(.easeInOut(duration: 0.25), value: showSettings)
        .overlay(alignment: .top) {
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.9))
                    .cornerRadius(8)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .onReceive(wallpaperController.playbackErrors) { (targetSpaceKey, message) in
            // Only show the error on the card for the display that failed
            if targetSpaceKey == space.spaceKey {
                errorMessage = "Playback failed: \(message)"
                
                // Cancel any pending clear
                errorClearTask?.cancel()
                
                // Auto-clear after 5 seconds
                errorClearTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(5))
                    if !Task.isCancelled {
                        errorMessage = nil
                    }
                }
            }
        }
    }

    // MARK: Header

    private var displayHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "display")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(space.displayName)
                    .font(.system(size: 14, weight: .semibold))
                if let url = space.desktopImageURL {
                    Text(url.lastPathComponent)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()
            
            if config != nil {
                Button {
                    showRemoveConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.glass)
                .popover(isPresented: $showRemoveConfirm) {
                    VStack(spacing: 12) {
                        Text("Remove wallpaper?")
                            .font(.system(size: 13, weight: .semibold))
                        
                        HStack(spacing: 8) {
                            Button("Cancel") {
                                showRemoveConfirm = false
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Remove") {
                                configStore.remove(spaceKey: space.spaceKey)
                                showRemoveConfirm = false
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    // MARK: - Display Settings
    
    private var displaySettingsSection: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.15)
            
            Button {
                showSettings.toggle()
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11))
                    Text("Display Settings")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Image(systemName: showSettings ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            
            if showSettings {
                VStack(spacing: 10) {
                    // Video Gravity
                    HStack {
                        Label("Scaling", systemImage: "aspectratio")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { currentWallpaper.videoGravity },
                            set: { newValue in
                                var updated = currentWallpaper
                                updated.videoGravity = newValue
                                configStore.assign(dynamicWallpaper: updated, toSpaceKey: space.spaceKey)
                            }
                        )) {
                            Text("Fill").tag(VideoGravity.fill)
                            Text("Fit").tag(VideoGravity.fit)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                    
                    // Mute toggle
                    Toggle(isOn: Binding(
                        get: { currentWallpaper.isMuted },
                        set: { newValue in
                            var updated = currentWallpaper
                            updated.isMuted = newValue
                            if newValue { updated.volume = 0 }
                            configStore.assign(dynamicWallpaper: updated, toSpaceKey: space.spaceKey)
                        }
                    )) {
                        Label("Muted", systemImage: currentWallpaper.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    
                    // Volume slider (only when not muted)
                    if !currentWallpaper.isMuted {
                        HStack(spacing: 8) {
                            Image(systemName: "speaker.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            
                            Slider(
                                value: Binding(
                                    get: { currentWallpaper.volume },
                                    set: { newValue in
                                        var updated = currentWallpaper
                                        updated.volume = newValue
                                        configStore.assign(dynamicWallpaper: updated, toSpaceKey: space.spaceKey)
                                    }
                                ),
                                in: 0...1
                            )
                            .controlSize(.small)
                            
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: Drop Zone
    
    private func dropZone(
        title: String,
        icon: String,
        url: URL?,
        isTargeted: Binding<Bool>,
        onDrop: @escaping @MainActor (URL) -> Void
    ) -> some View {
        GlassEffectContainer {
            VStack(spacing: 8) {
                if let url = url {
                    // Show video thumbnail
                    VideoThumbnailView(url: url)
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 12))
                        Text(url.lastPathComponent)
                            .font(.system(size: 11))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.1))
                    .cornerRadius(6)
                    
                    Text(title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                } else {
                    // Empty state — attractive drop zone
                    VStack(spacing: 6) {
                        Image(systemName: isTargeted.wrappedValue ? "arrow.down.circle.fill" : icon)
                            .font(.system(size: 28))
                            .symbolEffect(.bounce, value: isTargeted.wrappedValue)
                            .foregroundStyle(isTargeted.wrappedValue ? .blue : .secondary)
                        
                        Text(isTargeted.wrappedValue ? "Drop Here" : title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(isTargeted.wrappedValue ? .primary : .secondary)
                        
                        Text("Drop or browse  ·  .mp4  .mov  .m4v")
                            .font(.system(size: 9))
                            .foregroundStyle(.quaternary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                            )
                            .foregroundStyle(
                                isTargeted.wrappedValue
                                    ? Color.blue.opacity(0.6)
                                    : Color.primary.opacity(0.12)
                            )
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 60)
            .liquidGlass(
                isTargeted.wrappedValue ? .regular.tint(.blue) : .regular,
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
        .onTapGesture {
            openFilePicker(onPick: onDrop)
        }
        .onDrop(of: [.fileURL], isTargeted: isTargeted) { providers in
            guard let provider = providers.first else { return false }
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                guard
                    let data = item as? Data,
                    let url = URL(dataRepresentation: data, relativeTo: nil)
                else { return }

                Task { @MainActor in
                    if isValidVideoFile(url) {
                        // Dead file check
                        // For dropped files from outside the app container, we need to check if they
                        // actually exist and are reachable before bookmarking them
                        var isReachable = false
                        if url.startAccessingSecurityScopedResource() {
                            isReachable = FileManager.default.fileExists(atPath: url.path)
                            url.stopAccessingSecurityScopedResource()
                        } else {
                            isReachable = FileManager.default.fileExists(atPath: url.path)
                        }
                        
                        if isReachable {
                            errorMessage = nil
                            onDrop(url)
                        } else {
                            errorMessage = "File not found or not accessible."
                            // Auto-dismiss after 3s
                            Task {
                                try? await Task.sleep(for: .seconds(3))
                                await MainActor.run { errorMessage = nil }
                            }
                        }
                    } else {
                        errorMessage = "Unsupported format. Use .mp4, .mov, or .m4v"
                        // Auto-dismiss after 3s
                        Task {
                            try? await Task.sleep(for: .seconds(3))
                            await MainActor.run { errorMessage = nil }
                        }
                    }
                }
            }
            return true
        }
    }

    // MARK: - Interactions

    private func openFilePicker(onPick: @escaping (URL) -> Void) {
        // Activate the app so the panel appears in front
        NSApp.activate(ignoringOtherApps: true)
        
        let panel = NSOpenPanel()
        panel.allowedContentTypes = supportedVideoTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a video wallpaper"
        panel.prompt = "Select"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            if isValidVideoFile(url) {
                onPick(url)
            }
        }
    }
}

// MARK: - Video Thumbnail View

private struct VideoThumbnailView: View {
    let url: URL
    @State private var thumbnail: NSImage?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 90)
                    .clipped()
                    .cornerRadius(6)
                    .transition(.opacity)
            } else if isLoading {
                // Loading state
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.05))
                    .frame(maxWidth: .infinity)
                    .frame(height: 90)
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
            } else {
                // Failed to generate
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.05))
                    .frame(maxWidth: .infinity)
                    .frame(height: 90)
                    .overlay {
                        VStack(spacing: 4) {
                            Image(systemName: "film")
                                .font(.system(size: 18))
                                .foregroundStyle(.quaternary)
                            Text("No preview")
                                .font(.system(size: 9))
                                .foregroundStyle(.quaternary)
                        }
                    }
            }
        }
        .animation(.easeIn(duration: 0.2), value: thumbnail != nil)
        .task(id: url) {
            isLoading = true
            thumbnail = await generateThumbnail(for: url)
            isLoading = false
        }
    }
}

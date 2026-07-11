import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers

private let supportedVideoTypes: [UTType] = [.mpeg4Movie, .quickTimeMovie, .movie]
private let supportedCodecs: [FourCharCode] = [kCMVideoCodecType_H264, kCMVideoCodecType_HEVC]

// MARK: - Screen Card View

struct ScreenCardView: View {
    let space: ScreenSpace
    let configStore: ConfigStore

    @State private var currentConfig: SpaceConfig?
    @State private var isTargetedMain = false
    @State private var isTargetedLight = false
    @State private var isTargetedDark = false
    @State private var isValidatingMain = false
    @State private var isValidatingLight = false
    @State private var isValidatingDark = false
    @State private var resolvedStaticURL: URL?
    @State private var resolvedLightURL: URL?
    @State private var resolvedDarkURL: URL?

    @EnvironmentObject var wallpaperController: WallpaperController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var errorMessage: String?
    @State private var errorClearTask: Task<Void, Swift.Error>?
    
    @State private var showSuccessToast = false
    @State private var toastTask: Task<Void, Swift.Error>?
    // auroraRotation is owned per-DropZoneView instance (see C-1 fix below)

    private var config: SpaceConfig? { currentConfig }

    private var currentWallpaper: DynamicWallpaper {
        config?.dynamicWallpaper ?? DynamicWallpaper()
    }

    private var assignedVideoLabel: String? {
        if let url = currentWallpaper.staticURL, currentWallpaper.mode == .staticVideo {
            return url.lastPathComponent
        }
        if currentWallpaper.mode == .appearance {
            if let light = currentWallpaper.lightURL, let dark = currentWallpaper.darkURL {
                return "\(light.lastPathComponent) · \(dark.lastPathComponent)"
            }
            return (currentWallpaper.lightURL ?? currentWallpaper.darkURL)?.lastPathComponent
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            displayHeader

            Divider()
                .overlay(LivelyBrand.border.opacity(0.35))

            VStack(spacing: LivelyBrand.Spacing.sm) {
                PillTabBar(
                    tabs: [("Wallpaper", DynamicMode.staticVideo), ("Light & Dark", DynamicMode.appearance)],
                    selection: Binding(
                        get: { currentWallpaper.mode },
                        set: { newMode in
                            var updated = currentWallpaper
                            updated.mode = newMode
                            configStore.assign(dynamicWallpaper: updated, toSpaceKey: space.spaceKey)
                        }
                    )
                )

                if currentWallpaper.mode == .appearance {
                    Text("Different videos for light and dark mode")
                        .font(LivelyBrand.Typography.footnote)
                        .foregroundStyle(LivelyBrand.mutedForeground)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, LivelyBrand.Spacing.md)
            .padding(.vertical, LivelyBrand.Spacing.md)

            HStack(spacing: 12) {
                dropZone(
                    title: currentWallpaper.mode == .appearance ? "Light mode" : "",
                    icon: currentWallpaper.mode == .appearance ? "sun.max.fill" : "film",
                    url: currentWallpaper.mode == .appearance ? resolvedLightURL : resolvedStaticURL,
                    isTargeted: currentWallpaper.mode == .appearance ? $isTargetedLight : $isTargetedMain,
                    isValidating: currentWallpaper.mode == .appearance ? $isValidatingLight : $isValidatingMain,
                    onDrop: { url in
                        let wasFirstTime = !AppMetrics.shared.isActivated
                        var updated = currentWallpaper
                        if updated.mode == .appearance {
                            updated.lightURL = url
                        } else {
                            updated.staticURL = url
                        }
                        configStore.assign(dynamicWallpaper: updated, toSpaceKey: space.spaceKey)
                        if wasFirstTime { showSuccessMessage() }
                    },
                    onClear: {
                        var updated = currentWallpaper
                        if updated.mode == .appearance {
                            updated.lightURL = nil
                            if updated.darkURL == nil {
                                configStore.remove(spaceKey: space.spaceKey)
                            } else {
                                configStore.assign(dynamicWallpaper: updated, toSpaceKey: space.spaceKey)
                            }
                        } else {
                            configStore.remove(spaceKey: space.spaceKey)
                        }
                    }
                )

                if currentWallpaper.mode == .appearance {
                    dropZone(
                        title: "Dark mode",
                        icon: "moon.stars.fill",
                        url: resolvedDarkURL,
                        isTargeted: $isTargetedDark,
                        isValidating: $isValidatingDark,
                        onDrop: { url in
                            let wasFirstTime = !AppMetrics.shared.isActivated
                            var updated = currentWallpaper
                            updated.darkURL = url
                            configStore.assign(dynamicWallpaper: updated, toSpaceKey: space.spaceKey)
                            if wasFirstTime { showSuccessMessage() }
                        },
                        onClear: {
                            var updated = currentWallpaper
                            updated.darkURL = nil
                            if updated.lightURL == nil {
                                configStore.remove(spaceKey: space.spaceKey)
                            } else {
                                configStore.assign(dynamicWallpaper: updated, toSpaceKey: space.spaceKey)
                            }
                        }
                    )
                    .transition(modeTransition)
                }
            }
            .padding(.horizontal, LivelyBrand.Spacing.md)
            .padding(.bottom, LivelyBrand.Spacing.md)

            if config != nil {
                displaySettingsSection
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 6)),
                        removal: .opacity
                    ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: LivelyBrand.Radius.lg)
                .fill(LivelyBrand.card.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: LivelyBrand.Radius.lg)
                .strokeBorder(LivelyBrand.border.opacity(0.45))
        )
        .animation(reduceMotion ? nil : LivelyBrand.Motion.fast, value: errorMessage)
        .animation(reduceMotion ? nil : LivelyBrand.Motion.normal, value: currentWallpaper.mode)
        .animation(reduceMotion ? nil : LivelyBrand.Motion.normal, value: config != nil)
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                if let error = errorMessage {
                    Text(error)
                        .font(LivelyBrand.Typography.footnote.weight(.medium))
                        .foregroundStyle(LivelyBrand.onDestructive)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(LivelyBrand.destructive.opacity(0.92))
                        .clipShape(.rect(cornerRadius: LivelyBrand.Radius.sm))
                        .padding(.top, LivelyBrand.Spacing.sm)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                        .zIndex(10)
                }
                
                if showSuccessToast {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(LivelyBrand.primary)
                        Text("Playing on this Space. Switch Spaces to set another.")
                    }
                    .font(LivelyBrand.Typography.footnote.weight(.medium))
                    .foregroundStyle(LivelyBrand.foreground)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(LivelyBrand.accent.opacity(0.95))
                    .clipShape(.rect(cornerRadius: LivelyBrand.Radius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: LivelyBrand.Radius.sm)
                            .strokeBorder(LivelyBrand.border.opacity(0.45))
                    )
                    .padding(.top, LivelyBrand.Spacing.sm)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .zIndex(11)
                }
            }
        }
        .onReceive(wallpaperController.playbackErrors) { (targetSpaceKey, message) in
            if targetSpaceKey == space.spaceKey {
                showError("Playback failed: \(message)")
            }
        }
        .onAppear {
            currentConfig = configStore.configs[space.spaceKey]
            refreshResolvedURLs()
        }
        .onReceive(configStore.$configs) { newConfigs in
            let newConfig = newConfigs[space.spaceKey]
            if currentConfig?.dynamicWallpaper != newConfig?.dynamicWallpaper
                || (currentConfig == nil && newConfig != nil)
                || (currentConfig != nil && newConfig == nil) {
                currentConfig = newConfig
                refreshResolvedURLs()
            }
        }
    }

    // MARK: Header

    private var displayHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "display")
                .font(LivelyBrand.Typography.section)
                .foregroundStyle(LivelyBrand.mutedForeground)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(space.displayName)
                    .font(LivelyBrand.Typography.title)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let label = assignedVideoLabel {
                    Text(label)
                        .font(LivelyBrand.Typography.mono)
                        .foregroundStyle(LivelyBrand.mutedForeground)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            if config != nil {
                Button {
                    configStore.remove(spaceKey: space.spaceKey)
                } label: {
                    Label("Remove wallpaper", systemImage: "trash")
                        .labelStyle(.iconOnly)
                        .font(LivelyBrand.Typography.footnote)
                        .foregroundStyle(LivelyBrand.destructive)
                        .frame(minWidth: 32, minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel("Remove wallpaper")
                .accessibilityHint("Removes the assigned wallpaper from this display")
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding(.horizontal, LivelyBrand.Spacing.lg)
        .padding(.vertical, LivelyBrand.Spacing.lg)
    }

    // MARK: - Display Settings

    private var displaySettingsSection: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(LivelyBrand.border.opacity(0.35))

            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Text("Scale:")
                        .font(LivelyBrand.Typography.footnote.weight(.medium))
                        .foregroundStyle(LivelyBrand.mutedForeground)

                    Picker("Scale", selection: Binding(
                        get: { currentWallpaper.videoGravity },
                        set: { newValue in
                            configStore.updateDisplaySettings(
                                for: space.spaceKey,
                                gravity: newValue,
                                isMuted: currentWallpaper.isMuted,
                                volume: currentWallpaper.volume
                            )
                        }
                    )) {
                        Text("Fill").tag(VideoGravity.fill)
                        Text("Fit").tag(VideoGravity.fit)
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)
                    .labelsHidden()
                }

                Spacer()

                Button {
                    let newValue = !currentWallpaper.isMuted
                    configStore.updateDisplaySettings(
                        for: space.spaceKey,
                        gravity: currentWallpaper.videoGravity,
                        isMuted: newValue,
                        volume: newValue ? 0 : currentWallpaper.volume
                    )
                } label: {
                    Group {
                        if !reduceMotion {
                            Image(systemName: currentWallpaper.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .contentTransition(.symbolEffect(.replace))
                        } else {
                            Image(systemName: currentWallpaper.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        }
                    }
                    .font(LivelyBrand.Typography.footnote)
                    .foregroundStyle(currentWallpaper.isMuted ? LivelyBrand.mutedForeground : LivelyBrand.primary)
                    .frame(minWidth: 32, minHeight: 32)
                    .contentShape(Circle())
                    .background(
                        Circle()
                            .fill(currentWallpaper.isMuted ? Color.clear : LivelyBrand.primary.opacity(0.15))
                    )
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel(currentWallpaper.isMuted ? "Unmute" : "Mute")

                if !currentWallpaper.isMuted {
                    Slider(
                        value: Binding(
                            get: { currentWallpaper.volume },
                            set: { newValue in
                                configStore.updateDisplaySettings(
                                    for: space.spaceKey,
                                    gravity: currentWallpaper.videoGravity,
                                    isMuted: currentWallpaper.isMuted,
                                    volume: newValue
                                )
                            }
                        ),
                        in: 0...1
                    )
                    .tint(LivelyBrand.primary)
                    .controlSize(.small)
                    .frame(width: 80)
                    .accessibilityLabel("Volume")
                    .accessibilityValue("\(Int(currentWallpaper.volume * 100)) percent")
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(x: -8)),
                        removal: .opacity.combined(with: .offset(x: -4))
                    ))
                }
            }
            .padding(.horizontal, LivelyBrand.Spacing.lg)
            .padding(.vertical, LivelyBrand.Spacing.md)
            .animation(reduceMotion ? nil : LivelyBrand.Motion.fast, value: currentWallpaper.isMuted)
        }
    }

    private var modeTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 6)),
            removal: .opacity
        )
    }

    // MARK: Drop Zone

    private func refreshResolvedURLs() {
        let wallpaper = currentWallpaper
        resolvedStaticURL = configStore.resolveBookmark(
            for: space.spaceKey,
            bookmarkKey: "static",
            fallbackURL: wallpaper.staticURL
        )
        resolvedLightURL = configStore.resolveBookmark(
            for: space.spaceKey,
            bookmarkKey: "light",
            fallbackURL: wallpaper.lightURL
        )
        resolvedDarkURL = configStore.resolveBookmark(
            for: space.spaceKey,
            bookmarkKey: "dark",
            fallbackURL: wallpaper.darkURL
        )
    }

    // C-1 fix: DropZoneView owns its own @State so each instance has
    // independent auroraRotation — no shared state glitch in .appearance mode.
    private func dropZone(
        title: String,
        icon: String,
        url: URL?,
        isTargeted: Binding<Bool>,
        isValidating: Binding<Bool>,
        onDrop: @escaping @MainActor (URL) -> Void,
        onClear: @escaping @MainActor () -> Void
    ) -> some View {
        DropZoneView(
            title: title,
            icon: icon,
            url: url,
            isTargeted: isTargeted,
            isValidating: isValidating,
            reduceMotion: reduceMotion,
            onFilePick: { openFilePicker(isValidating: isValidating, onPick: onDrop) },
            onURLDrop: { dropped in
                handleURLSelection(dropped, isValidating: isValidating, onAccept: onDrop)
            },
            onError: { message in
                showError(message)
            },
            onClear: onClear
        )
    }

    // MARK: - Interactions

    private func showSuccessMessage() {
        showSuccessToast = true
        AccessibilityNotification.Announcement("Playing on this Space. Switch Spaces to set another.").post()
        toastTask?.cancel()
        toastTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(3))
                showSuccessToast = false
            } catch {
                // Task was cancelled — do not update state
            }
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        AccessibilityNotification.Announcement(message).post()
        errorClearTask?.cancel()
        errorClearTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(5))
                errorMessage = nil
            } catch {
                // Task was cancelled — do not update state
            }
        }
    }

    private func handleURLSelection(
        _ url: URL,
        isValidating: Binding<Bool>,
        onAccept: @escaping @MainActor (URL) -> Void
    ) {
        Task { @MainActor in
            isValidating.wrappedValue = true
            defer { isValidating.wrappedValue = false }

            switch await VideoURLValidation.validate(url) {
            case .invalid(let message):
                showError(message)
            case .valid(let validURL):
                errorMessage = nil
                onAccept(validURL)
            }
        }
    }

    @MainActor
    private func openFilePicker(
        isValidating: Binding<Bool>,
        onPick: @escaping @MainActor (URL) -> Void
    ) {
        NSApp.activate()

        let panel = NSOpenPanel()
        panel.allowedContentTypes = supportedVideoTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a video wallpaper"
        panel.prompt = "Select"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                self.handleURLSelection(url, isValidating: isValidating, onAccept: onPick)
            }
        }
    }
}

// MARK: - Video URL Validation

private enum VideoURLValidation {
    enum Outcome {
        case valid(URL)
        case invalid(String)
    }

    static func validate(_ url: URL) async -> Outcome {
        guard isValidLivelyVideoFile(url) else {
            return .invalid("Unsupported format. Use .mp4, .mov, or .m4v")
        }

        let scopeGranted = url.startAccessingSecurityScopedResource()
        defer { if scopeGranted { url.stopAccessingSecurityScopedResource() } }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return .invalid("File not found or not accessible.")
        }

        let asset = AVURLAsset(url: url)
        guard let tracks = try? await asset.loadTracks(withMediaType: .video), !tracks.isEmpty else {
            return .invalid("No video track found in this file.")
        }

        var foundSupported = false
        for track in tracks {
            guard let descs = try? await track.load(.formatDescriptions) else { continue }
            for desc in descs {
                let codec = CMFormatDescriptionGetMediaSubType(desc)
                if supportedCodecs.contains(codec) {
                    foundSupported = true
                } else {
                    return .invalid("Only H.264 and HEVC are supported. Re-encode this file.")
                }
            }
        }

        guard foundSupported else {
            return .invalid("Only H.264 and HEVC are supported. Re-encode this file.")
        }

        return .valid(url)
    }
}

// MARK: - Drop Zone View (C-1: each instance owns its own auroraRotation)

/// Self-contained drop zone. By being a separate `View` struct, each instance
/// gets its own `@State private var auroraRotation`, preventing the shared-state
/// glitch that occurred in `.appearance` mode when one zone's `.onDisappear`
/// reset the other zone's animation.
private struct DropZoneView: View {
    let title: String
    let icon: String
    let url: URL?
    let isTargeted: Binding<Bool>
    let isValidating: Binding<Bool>
    let reduceMotion: Bool
    let onFilePick: @MainActor () -> Void
    let onURLDrop: @MainActor (URL) -> Void
    let onError: @MainActor (String) -> Void
    let onClear: @MainActor () -> Void

    @State private var auroraRotation: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            if isValidating.wrappedValue {
                progressView
            } else if let url = url {
                activeVideoView(url: url)
            } else {
                emptyPlaceholderView
            }
        }
        .padding(LivelyBrand.Spacing.md)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 60)
        .background(
            RoundedRectangle(cornerRadius: LivelyBrand.Radius.md)
                .fill(
                    isTargeted.wrappedValue
                        ? LivelyBrand.primary.opacity(0.12)
                        : LivelyBrand.accent.opacity(0.35)
                )
        )
        .scaleEffect(isTargeted.wrappedValue ? 1.03 : 1.0)
        .animation(reduceMotion ? nil : LivelyBrand.Motion.dropTarget, value: isTargeted.wrappedValue)
        .accessibilityLabel(
            url.map { "\(title.isEmpty ? "Wallpaper" : title), \($0.lastPathComponent)" }
                ?? "\(title.isEmpty ? "Wallpaper" : title), choose video"
        )
        .accessibilityHint(url == nil ? "Drag and drop a video, or click to browse" : "Click to change video, or click the clear button in the top-right corner to remove it")
        .onDrop(of: [.fileURL], isTargeted: isTargeted) { providers in
            guard let provider = providers.first else { return false }
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                if let error = error {
                    Task { @MainActor in
                        onError(error.localizedDescription)
                    }
                    return
                }
                guard
                    let data = item as? Data,
                    let url = URL(dataRepresentation: data, relativeTo: nil)
                else {
                    Task { @MainActor in
                        onError("Failed to parse dropped file.")
                    }
                    return
                }
                Task { @MainActor in onURLDrop(url) }
            }
            return true
        }
    }

    // MARK: - Sub-views (fixes compiler type-check timeout)

    @ViewBuilder
    private var progressView: some View {
        ProgressView()
            .controlSize(.small)
            .frame(maxWidth: .infinity, minHeight: 80)
    }

    @ViewBuilder
    private func activeVideoView(url: URL) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                VideoThumbnailView(url: url)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onFilePick()
                    }
                    .overlay(alignment: .bottomLeading) {
                        Text("Click to change")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.55))
                            .clipShape(.rect(cornerRadius: LivelyBrand.Radius.sm))
                            .padding(6)
                    }
                
                Button {
                    onClear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .red.opacity(0.85))
                        .font(.system(size: 20))
                        .padding(6)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Clear this video")
            }
            .frame(height: 90)
            .clipShape(.rect(cornerRadius: LivelyBrand.Radius.sm))
            
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(LivelyBrand.primary)
                    .font(LivelyBrand.Typography.caption)
                Text(url.lastPathComponent)
                    .font(LivelyBrand.Typography.body.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, LivelyBrand.Spacing.sm)
            .padding(.vertical, LivelyBrand.Spacing.xs)

            if !title.isEmpty {
                Text(title)
                    .font(LivelyBrand.Typography.caption)
                    .foregroundStyle(LivelyBrand.mutedForeground)
            }
        }
    }

    @ViewBuilder
    private var emptyPlaceholderView: some View {
        Button {
            onFilePick()
        } label: {
            VStack(spacing: 6) {
                Group {
                    if !reduceMotion {
                        Image(systemName: isTargeted.wrappedValue ? "arrow.down.circle.fill" : icon)
                            .symbolEffect(.pulse, value: isTargeted.wrappedValue)
                            .contentTransition(.symbolEffect(.replace))
                    } else {
                        Image(systemName: isTargeted.wrappedValue ? "arrow.down.circle.fill" : icon)
                    }
                }
                .font(.system(size: 28))
                .foregroundStyle(isTargeted.wrappedValue ? LivelyBrand.primary : LivelyBrand.mutedForeground)

                if isTargeted.wrappedValue {
                    Text("Drop here")
                        .font(LivelyBrand.Typography.caption)
                        .foregroundStyle(LivelyBrand.foreground)
                        .transition(.opacity)
                } else if title.isEmpty {
                    Text("Drop a video, or click to browse")
                        .font(LivelyBrand.Typography.caption)
                        .foregroundStyle(LivelyBrand.mutedForeground)
                } else {
                    Text(title)
                        .font(LivelyBrand.Typography.caption)
                        .foregroundStyle(LivelyBrand.mutedForeground)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 80)
            .overlay {
                if isTargeted.wrappedValue && !reduceMotion {
                    RoundedRectangle(cornerRadius: LivelyBrand.Radius.sm)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    LivelyBrand.primary,
                                    LivelyBrand.primarySoft,
                                    LivelyBrand.primary.opacity(0.4),
                                    LivelyBrand.primarySoft,
                                    LivelyBrand.primary
                                ],
                                center: .center,
                                angle: .degrees(auroraRotation)
                            ),
                            lineWidth: 2
                        )
                        .onAppear {
                            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                                auroraRotation = 360
                            }
                        }
                        .onDisappear { auroraRotation = 0 }
                } else {
                    RoundedRectangle(cornerRadius: LivelyBrand.Radius.sm)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .foregroundStyle(
                            isTargeted.wrappedValue
                                ? LivelyBrand.primary.opacity(0.68)
                                : LivelyBrand.border.opacity(0.52)
                        )
                }
            }
        }
        .buttonStyle(.plain)
    }
}
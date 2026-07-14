import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct LibraryView: View {
    @ObservedObject public var spaceMonitor: SpaceMonitor
    public let configStore: ConfigStore
    @ObservedObject public var libraryManager: WallpaperLibraryManager

    @ViewState private var addError: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        spaceMonitor: SpaceMonitor,
        configStore: ConfigStore,
        libraryManager: WallpaperLibraryManager
    ) {
        self.spaceMonitor = spaceMonitor
        self.configStore = configStore
        self.libraryManager = libraryManager
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: LivelyBrand.Spacing.xl) {
            headerSection

            if let addError {
                errorBanner(addError)
            }

            ZStack {
                if libraryManager.items.isEmpty {
                    emptyState
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 8)),
                            removal: .opacity
                        ))
                } else {
                    gridView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 6)),
                            removal: .opacity
                        ))
                }
            }
            .animation(reduceMotion ? nil : LivelyBrand.Motion.normal, value: libraryManager.items.isEmpty)
        }
        .padding(.horizontal, LivelyBrand.Spacing.xl)
        .padding(.vertical, LivelyBrand.Spacing.xl)
        .frame(minWidth: 600, minHeight: 400)
        .background(LivelyBrand.background)
        .foregroundStyle(LivelyBrand.foreground)
        .onAppear {
            if libraryManager.spaceKeyTarget == nil {
                libraryManager.spaceKeyTarget = spaceMonitor.screenSpaces.first?.spaceKey
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: LivelyBrand.Spacing.xs) {
                Text("Wallpaper Library")
                    .font(LivelyBrand.Typography.title)
                    .foregroundStyle(LivelyBrand.foreground)
                Text("Add videos once and reuse them on any display or Space.")
                    .font(LivelyBrand.Typography.body)
                    .foregroundStyle(LivelyBrand.mutedForeground)
            }

            Spacer()

            HStack(spacing: LivelyBrand.Spacing.sm) {
                if spaceMonitor.screenSpaces.count > 1 {
                    HStack(spacing: LivelyBrand.Spacing.sm) {
                        Text("Target Screen:")
                            .font(LivelyBrand.Typography.caption)
                            .foregroundStyle(LivelyBrand.mutedForeground)
                        Picker("Target Screen", selection: $libraryManager.spaceKeyTarget) {
                            ForEach(spaceMonitor.screenSpaces) { space in
                                Text(space.displayName)
                                    .tag(space.spaceKey as String?)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    .padding(.horizontal, LivelyBrand.Spacing.md)
                    .padding(.vertical, LivelyBrand.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: LivelyBrand.Radius.sm)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: LivelyBrand.Radius.sm)
                            .strokeBorder(LivelyBrand.border.opacity(0.45), lineWidth: 1)
                    )
                }

                Button {
                    addWallpaperFromPanel()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Add Wallpaper")
                            .font(LivelyBrand.Typography.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: LivelyBrand.Radius.sm)
                            .fill(LivelyBrand.primary)
                    )
                }
                .buttonStyle(PressScaleButtonStyle())
                .focusEffectDisabled()
                .accessibilityLabel("Add wallpaper")
                .accessibilityHint("Choose a video file to save in your library for reuse.")
            }
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: LivelyBrand.Spacing.md) {
            Spacer(minLength: 24)
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(LivelyBrand.mutedForeground)
            Text("No wallpapers yet")
                .font(LivelyBrand.Typography.body.weight(.semibold))
            Text("Add MP4, MOV, or M4V files to build a reusable library. Apply any of them to a display without re-importing.")
                .font(LivelyBrand.Typography.caption)
                .foregroundStyle(LivelyBrand.mutedForeground)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Button {
                addWallpaperFromPanel()
            } label: {
                Text("Add Your First Wallpaper")
                    .font(LivelyBrand.Typography.caption.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: LivelyBrand.Radius.sm)
                            .fill(LivelyBrand.primary)
                    )
            }
            .buttonStyle(PressScaleButtonStyle())
            .focusEffectDisabled()
            .padding(.top, LivelyBrand.Spacing.sm)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Grid

    private var gridView: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: LivelyBrand.Spacing.lg)],
                spacing: LivelyBrand.Spacing.lg
            ) {
                ForEach(libraryManager.items) { item in
                    LibraryCard(
                        item: item,
                        fileURL: libraryManager.resolvedURL(for: item),
                        onApply: { url in
                            applyWallpaper(localURL: url)
                        },
                        onRemove: {
                            libraryManager.remove(item)
                        }
                    )
                }
            }
            .padding(.top, LivelyBrand.Spacing.sm)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Actions

    private func addWallpaperFromPanel() {
        addError = nil
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            UTType(filenameExtension: "mp4") ?? .movie,
            UTType(filenameExtension: "mov") ?? .movie,
            UTType(filenameExtension: "m4v") ?? .movie
        ].compactMap { $0 }
        panel.message = "Choose video files to add to your reusable library"
        panel.prompt = "Add"

        panel.begin { response in
            guard response == .OK else { return }
            Task { @MainActor in
                var failures = 0
                for url in panel.urls {
                    do {
                        try libraryManager.add(from: url)
                    } catch {
                        failures += 1
                        addError = error.localizedDescription
                    }
                }
                if failures > 0 && panel.urls.count > 1 {
                    addError = "\(failures) of \(panel.urls.count) files could not be added."
                }
            }
        }
    }

    private func applyWallpaper(localURL: URL) {
        let targetKey = libraryManager.spaceKeyTarget ?? spaceMonitor.screenSpaces.first?.spaceKey
        guard let spaceKey = targetKey else {
            addError = "No display available to apply this wallpaper."
            return
        }
        var wallpaperConfig = configStore.configs[spaceKey]?.dynamicWallpaper ?? DynamicWallpaper()
        wallpaperConfig.mode = .staticVideo
        wallpaperConfig.staticURL = localURL
        configStore.assign(dynamicWallpaper: wallpaperConfig, toSpaceKey: spaceKey)
        addError = nil
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: LivelyBrand.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(LivelyBrand.destructive)
            Text(message)
                .font(LivelyBrand.Typography.caption)
                .foregroundStyle(LivelyBrand.foreground)
            Spacer()
            Button {
                addError = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(LivelyBrand.mutedForeground)
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
        }
        .padding(LivelyBrand.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: LivelyBrand.Radius.md)
                .fill(LivelyBrand.destructive.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: LivelyBrand.Radius.md)
                .strokeBorder(LivelyBrand.destructive.opacity(0.3))
        )
    }
}

// MARK: - Card

public struct LibraryCard: View {
    public let item: LibraryWallpaper
    public let fileURL: URL?
    public let onApply: @MainActor (URL) -> Void
    public let onRemove: @MainActor () -> Void

    @ViewState private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var body: some View {
        VStack(alignment: .leading, spacing: LivelyBrand.Spacing.sm) {
            ZStack {
                if let fileURL {
                    VideoThumbnailView(url: fileURL, height: 140, cornerRadius: 0, showLabels: false)
                } else {
                    ZStack {
                        Color(nsColor: .controlBackgroundColor)
                        Image(systemName: "film")
                            .font(.system(size: 28))
                            .foregroundStyle(LivelyBrand.mutedForeground)
                    }
                    .frame(height: 140)
                }

                Color.black.opacity(isHovered ? 0.35 : 0)
                    .animation(reduceMotion ? nil : LivelyBrand.Motion.fast, value: isHovered)

                HStack(spacing: LivelyBrand.Spacing.md) {
                    if let fileURL {
                        Button {
                            onApply(fileURL)
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .help("Apply to target screen")
                        .accessibilityLabel("Apply \(item.name)")
                    }

                    Button {
                        onRemove()
                    } label: {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color(nsColor: .systemRed))
                    }
                    .buttonStyle(.plain)
                    .help("Remove from library")
                    .accessibilityLabel("Remove \(item.name)")
                }
                .opacity(isHovered ? 1 : 0)
                .scaleEffect(isHovered || reduceMotion ? 1 : 0.92)
                .animation(reduceMotion ? nil : LivelyBrand.Motion.fast, value: isHovered)
                .allowsHitTesting(isHovered)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .clipped()

            VStack(alignment: .leading, spacing: LivelyBrand.Spacing.xs) {
                Text(item.name)
                    .font(LivelyBrand.Typography.body.weight(.semibold))
                    .foregroundStyle(LivelyBrand.foreground)
                    .lineLimit(1)

                if let fileURL {
                    Button {
                        onApply(fileURL)
                    } label: {
                        Text("Apply")
                            .font(LivelyBrand.Typography.footnote.weight(.semibold))
                            .foregroundStyle(LivelyBrand.primary)
                    }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                } else {
                    Text("File missing")
                        .font(LivelyBrand.Typography.footnote)
                        .foregroundStyle(LivelyBrand.destructive)
                }
            }
            .padding(.horizontal, LivelyBrand.Spacing.md)
            .padding(.bottom, LivelyBrand.Spacing.md)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: LivelyBrand.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: LivelyBrand.Radius.md)
                .strokeBorder(LivelyBrand.border.opacity(0.45), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: LivelyBrand.Radius.md))
        .scaleEffect(isHovered && !reduceMotion ? 1.015 : 1.0)
        .animation(reduceMotion ? nil : LivelyBrand.Motion.fast, value: isHovered)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name) wallpaper")
        .accessibilityHint("Apply to the selected display, or remove from the library.")
    }
}

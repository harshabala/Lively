import SwiftUI
import AppKit
import Combine

public struct LibraryView: View {
    @ObservedObject public var spaceMonitor: SpaceMonitor
    public let configStore: ConfigStore
    @ObservedObject public var libraryManager: WallpaperLibraryManager
    
    public init(spaceMonitor: SpaceMonitor, configStore: ConfigStore, libraryManager: WallpaperLibraryManager) {
        self.spaceMonitor = spaceMonitor
        self.configStore = configStore
        self.libraryManager = libraryManager
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: LivelyBrand.Spacing.xl) {
            headerSection
            
            gridView
        }
        .padding(.horizontal, LivelyBrand.Spacing.xl)
        .padding(.vertical, LivelyBrand.Spacing.xl)
        .frame(minWidth: 600, minHeight: 400)
        .background(
            ZStack {
                LivelyBrand.backgroundGradient
                    .ignoresSafeArea()
                    .opacity(0.88)
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
            }
        )
        .foregroundStyle(LivelyBrand.foreground)
        .onAppear {
            libraryManager.checkLocalFiles()
            if libraryManager.spaceKeyTarget == nil {
                libraryManager.spaceKeyTarget = spaceMonitor.screenSpaces.first?.spaceKey
            }
        }
    }
    
    private var headerSection: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: LivelyBrand.Spacing.xs) {
                Text("Explore Wallpapers")
                    .font(LivelyBrand.Typography.title)
                    .foregroundStyle(LivelyBrand.foreground)
                Text("Curated high-quality, looping video backdrops. Local-first & offline.")
                    .font(LivelyBrand.Typography.body)
                    .foregroundStyle(LivelyBrand.mutedForeground)
            }
            
            Spacer()
            
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
                        .fill(LivelyBrand.card.opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: LivelyBrand.Radius.sm)
                        .strokeBorder(LivelyBrand.border.opacity(0.35), lineWidth: 1)
                )
            }
        }
    }
    
    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240, maximum: 300), spacing: LivelyBrand.Spacing.lg)], spacing: LivelyBrand.Spacing.lg) {
                ForEach(CuratedWallpaper.curatedList) { wallpaper in
                    LibraryCard(
                        wallpaper: wallpaper,
                        libraryManager: libraryManager,
                        onDownload: {
                            Task {
                                await libraryManager.download(wallpaper)
                            }
                        },
                        onApply: { url in
                            applyWallpaper(for: wallpaper, localURL: url)
                        }
                    )
                }
            }
            .padding(.top, LivelyBrand.Spacing.sm)
        }
        .scrollIndicators(.hidden)
    }
    
    private func applyWallpaper(for wallpaper: CuratedWallpaper, localURL: URL) {
        let targetKey = libraryManager.spaceKeyTarget ?? spaceMonitor.screenSpaces.first?.spaceKey
        guard let spaceKey = targetKey else { return }
        var wallpaperConfig = configStore.configs[spaceKey]?.dynamicWallpaper ?? DynamicWallpaper()
        wallpaperConfig.mode = .staticVideo
        wallpaperConfig.staticURL = localURL
        configStore.assign(dynamicWallpaper: wallpaperConfig, toSpaceKey: spaceKey)
    }
}

public struct LibraryCard: View {
    public let wallpaper: CuratedWallpaper
    public let libraryManager: WallpaperLibraryManager
    public let onDownload: @MainActor () -> Void
    public let onApply: @MainActor (URL) -> Void
    
    @ViewState private var status: DownloadStatus = .notDownloaded
    @ViewState private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init(
        wallpaper: CuratedWallpaper,
        libraryManager: WallpaperLibraryManager,
        onDownload: @escaping @MainActor () -> Void,
        onApply: @escaping @MainActor (URL) -> Void
    ) {
        self.wallpaper = wallpaper
        self.libraryManager = libraryManager
        self.onDownload = onDownload
        self.onApply = onApply
    }
    
    private var statusDescription: String {
        switch status {
        case .notDownloaded:
            return "not downloaded"
        case .downloading(let progress):
            return "downloading \(Int(progress * 100)) percent"
        case .downloaded:
            return "downloaded, ready to apply"
        case .failed:
            return "download failed"
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: LivelyBrand.Spacing.sm) {
            ZStack {
                AsyncImage(url: wallpaper.thumbnailURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        ZStack {
                            LivelyBrand.card.opacity(0.5)
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundColor(LivelyBrand.mutedForeground)
                        }
                    case .empty:
                        ZStack {
                            LivelyBrand.card.opacity(0.5)
                            ProgressView()
                                .controlSize(.small)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                statusOverlay(for: status)
            }
            .aspectRatio(16/9, contentMode: .fit)
            .clipped()
            
            VStack(alignment: .leading, spacing: LivelyBrand.Spacing.xs) {
                Text(wallpaper.name)
                    .font(LivelyBrand.Typography.body.weight(.semibold))
                    .foregroundStyle(LivelyBrand.foreground)
                    .lineLimit(1)
                Text("by \(wallpaper.creator)")
                    .font(LivelyBrand.Typography.footnote)
                    .foregroundStyle(LivelyBrand.mutedForeground)
                    .lineLimit(1)
            }
            .padding(.horizontal, LivelyBrand.Spacing.md)
            .padding(.bottom, LivelyBrand.Spacing.md)
        }
        .background(LivelyBrand.card)
        .clipShape(RoundedRectangle(cornerRadius: LivelyBrand.Radius.md))
        .contentShape(RoundedRectangle(cornerRadius: LivelyBrand.Radius.md))
        .shadow(
            color: LivelyBrand.Shadow.color,
            radius: LivelyBrand.Shadow.radius,
            x: LivelyBrand.Shadow.x,
            y: LivelyBrand.Shadow.y
        )
        .scaleEffect(isHovered && !reduceMotion ? 1.02 : 1.0)
        .animation(reduceMotion ? nil : LivelyBrand.Motion.fast, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            status = libraryManager.downloadStatuses[wallpaper.id] ?? .notDownloaded
        }
        .onReceive(libraryManager.downloadStatusesPublisher) { statuses in
            let newStatus = statuses[wallpaper.id] ?? .notDownloaded
            if self.status != newStatus {
                self.status = newStatus
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(wallpaper.name) wallpaper by \(wallpaper.creator), status: \(statusDescription)")
        .accessibilityHint("Double tap to download or apply this wallpaper.")
    }
    
    @ViewBuilder
    private func statusOverlay(for status: DownloadStatus) -> some View {
        ZStack {
            Color.black.opacity(0.2)
            
            switch status {
            case .notDownloaded:
                Button(action: {
                    onDownload()
                }) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .shadow(
                            color: LivelyBrand.Shadow.color,
                            radius: LivelyBrand.Shadow.radius,
                            x: LivelyBrand.Shadow.x,
                            y: LivelyBrand.Shadow.y
                        )
                }
                .buttonStyle(.plain)
                .help("Download \(wallpaper.name)")
                .accessibilityLabel("Download \(wallpaper.name)")
                .accessibilityHint("Downloads this wallpaper to your library so you can apply it.")
                
            case .downloading(let progress):
                VStack(spacing: LivelyBrand.Spacing.sm) {
                    ProgressView(value: progress)
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .shadow(
                            color: LivelyBrand.Shadow.color,
                            radius: LivelyBrand.Shadow.radius,
                            x: LivelyBrand.Shadow.x,
                            y: LivelyBrand.Shadow.y
                        )
                        .accessibilityLabel("Downloading \(wallpaper.name)")
                        .accessibilityValue("\(Int(progress * 100)) percent complete")
                    
                    Text("\(Int(progress * 100))%")
                        .font(LivelyBrand.Typography.caption)
                        .foregroundColor(.white)
                        .bold()
                        .shadow(
                            color: LivelyBrand.Shadow.color,
                            radius: LivelyBrand.Shadow.radius,
                            x: LivelyBrand.Shadow.x,
                            y: LivelyBrand.Shadow.y
                        )
                }
                
            case .downloaded(let localURL):
                Button(action: {
                    onApply(localURL)
                }) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(LivelyBrand.primary)
                        .shadow(
                            color: LivelyBrand.Shadow.color,
                            radius: LivelyBrand.Shadow.radius,
                            x: LivelyBrand.Shadow.x,
                            y: LivelyBrand.Shadow.y
                        )
                }
                .buttonStyle(.plain)
                .help("Apply \(wallpaper.name) to screen")
                .accessibilityLabel("Apply \(wallpaper.name)")
                .accessibilityHint("Sets this video backdrop as your active wallpaper.")
                
            case .failed(let error):
                Button(action: {
                    onDownload()
                }) {
                    VStack(spacing: LivelyBrand.Spacing.xs) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(LivelyBrand.destructive)
                            .shadow(
                                color: LivelyBrand.Shadow.color,
                                radius: LivelyBrand.Shadow.radius,
                                x: LivelyBrand.Shadow.x,
                                y: LivelyBrand.Shadow.y
                            )
                        
                        Text("Retry")
                            .font(LivelyBrand.Typography.footnote)
                            .foregroundColor(.white)
                            .bold()
                            .shadow(
                                color: LivelyBrand.Shadow.color,
                                radius: LivelyBrand.Shadow.radius,
                                x: LivelyBrand.Shadow.x,
                                y: LivelyBrand.Shadow.y
                            )
                    }
                }
                .buttonStyle(.plain)
                .help("Download failed: \(error). Click to retry.")
                .accessibilityLabel("Retry downloading \(wallpaper.name)")
                .accessibilityHint("Attempts to download the wallpaper again.")
            }
        }
    }
}

import AppKit
import AVFoundation
import Combine

// MARK: - WallpaperSession

/// Encapsulates the WallpaperWindow + video player for one physical display.
/// Follows LiveDesk's proven pattern: plain NSView + AVPlayerLayer, no subclass.
@MainActor
private final class WallpaperSession {
    let window: WallpaperWindow
    private let contentView: NSView
    private let playerLayer: AVPlayerLayer
    private var player: AVPlayer?
    private var loopObserver: Any?
    private var errorObservation: NSKeyValueObservation?
    private(set) var currentURL: URL?

    init(screen: NSScreen) {
        window = WallpaperWindow(screen: screen)
        
        // Create a plain NSView as the content view (no subclass)
        let localFrame = NSRect(origin: .zero, size: screen.frame.size)
        contentView = NSView(frame: localFrame)
        contentView.wantsLayer = true
        
        // Create AVPlayerLayer and add directly to the content view's layer
        playerLayer = AVPlayerLayer()
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = contentView.bounds
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        contentView.layer!.addSublayer(playerLayer)
        
        window.contentView = contentView
    }

    /// Shows the window and plays (or crossfades to) the given video.
    func play(url: URL, wallpaper: DynamicWallpaper, screen: NSScreen, onError: @escaping @Sendable (Error) -> Void) {
        // Ensure the window matches the current screen frame
        let localFrame = NSRect(origin: .zero, size: screen.frame.size)
        window.setFrame(screen.frame, display: true)
        contentView.frame = localFrame
        playerLayer.frame = localFrame
        
        // Apply display settings
        let gravity: AVLayerVideoGravity = wallpaper.videoGravity == .fit ? .resizeAspect : .resizeAspectFill
        playerLayer.videoGravity = gravity
        
        if url == currentURL {
            playerLayer.videoGravity = gravity
            player?.isMuted = wallpaper.isMuted
            player?.volume = wallpaper.volume
            player?.play()   // ensure playing (handles resume via synchronize)
            window.show()
            return
        }
        
        currentURL = url
        window.show()
        loadVideo(url: url, muted: wallpaper.isMuted, volume: wallpaper.volume, onError: onError)
    }

    private func loadVideo(url: URL, muted: Bool, volume: Float, onError: @escaping @Sendable (Error) -> Void) {
        tearDownPlayer()
        
        let newPlayer = AVPlayer(url: url)
        newPlayer.isMuted = muted
        newPlayer.volume = volume
        newPlayer.preventsDisplaySleepDuringVideoPlayback = false
        newPlayer.automaticallyWaitsToMinimizeStalling = false

        // Loop via notification
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayer.currentItem,
            queue: .main
        ) { [weak newPlayer] _ in
            newPlayer?.seek(to: .zero)
            newPlayer?.play()
        }
        
        // Observe errors to bubble up
        errorObservation = newPlayer.currentItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            if item.status == .failed, let error = item.error {
                LivelyLogger.wallpaper.error("AVPlayerItem failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    // Clear currentURL so the next synchronize() call can retry
                    self?.currentURL = nil
                    onError(error)
                }
            }
        }

        // Connect player to layer and start
        playerLayer.player = newPlayer
        self.player = newPlayer
        newPlayer.play()
    }

    /// Hides the window and stops playback.
    func hide() {
        currentURL = nil
        tearDownPlayer()
        window.orderOut(nil)
    }

    func pause() {
        player?.pause()
    }

    func resume() {
        player?.play()
    }
    
    private func tearDownPlayer() {
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
        errorObservation?.invalidate()
        errorObservation = nil
        player?.pause()
        playerLayer.player = nil
        player = nil
    }
}

// MARK: - BookmarkManager

@MainActor
private final class BookmarkManager {
    private let configStore: ConfigStore
    private var activeScopes: [String: URL] = [:]

    init(configStore: ConfigStore) {
        self.configStore = configStore
    }

    func urlForSpace(_ space: ScreenSpace, appearance: NSAppearance?) -> URL? {
        guard let url = configStore.resolvedURL(for: space.spaceKey, appearance: appearance) else {
            stopScope(for: space.spaceKey)
            return nil
        }
        startScope(for: space.spaceKey, url: url)
        return url
    }

    func stopScope(for spaceKey: String) {
        if let oldURL = activeScopes.removeValue(forKey: spaceKey) {
            oldURL.stopAccessingSecurityScopedResource()
            LivelyLogger.wallpaper.info("Security scope stopped for \(oldURL.lastPathComponent)")
        }
    }

    func stopScopes(withPrefix prefix: String) {
        for key in activeScopes.keys where key.hasPrefix(prefix) {
            stopScope(for: key)
        }
    }

    private func startScope(for spaceKey: String, url: URL) {
        stopScope(for: spaceKey)
        let didStart = url.startAccessingSecurityScopedResource()
        if didStart {
            activeScopes[spaceKey] = url
            LivelyLogger.wallpaper.info("Security scope started for \(url.lastPathComponent)")
        }
    }
}

// MARK: - WallpaperSessionManager

@MainActor
private final class WallpaperSessionManager {
    private var sessions: [String: WallpaperSession] = [:]

    var allSessions: [String: WallpaperSession] {
        sessions
    }

    func synchronize(
        to spaces: [ScreenSpace],
        appearance: NSAppearance,
        configStore: ConfigStore,
        bookmarkManager: BookmarkManager,
        isPaused: Bool,
        onPlaybackError: @escaping @Sendable (String, String) -> Void
    ) {
        let liveDisplayIDs = Set(spaces.map(\.id))

        // Always clean up sessions for displays that are no longer connected,
        // even when paused — a disconnected monitor should never keep a hidden window alive.
        for id in sessions.keys where !liveDisplayIDs.contains(id) {
            sessions[id]?.hide()
            sessions.removeValue(forKey: id)
            bookmarkManager.stopScopes(withPrefix: id)
        }

        // While paused, skip playback updates; togglePause() will re-sync on resume.
        guard !isPaused else { return }

        for space in spaces {
            var session = sessions[space.id]
            if session == nil {
                session = WallpaperSession(screen: space.screen)
                sessions[space.id] = session
            }

            let wallpaperConfig = configStore.configs[space.spaceKey]?.dynamicWallpaper ?? DynamicWallpaper()

            if let videoURL = bookmarkManager.urlForSpace(space, appearance: appearance) {
                session?.play(
                    url: videoURL,
                    wallpaper: wallpaperConfig,
                    screen: space.screen,
                    onError: { error in
                        onPlaybackError(space.spaceKey, error.localizedDescription)
                    }
                )
            } else {
                bookmarkManager.stopScope(for: space.spaceKey)
                session?.hide()
            }
        }
    }
}

// MARK: - WallpaperController

@MainActor
public final class WallpaperController: ObservableObject {

    // MARK: - Public State

    @Published public private(set) var isPaused = false
    
    /// Bubbles up playback errors (spaceKey, Error message) to the UI
    public let playbackErrors = PassthroughSubject<(String, String), Never>()

    // MARK: - Private

    private let spaceMonitor: SpaceMonitor
    private let configStore: ConfigStore
    private let bookmarkManager: BookmarkManager
    private let sessionManager: WallpaperSessionManager
    private var cancellables = Set<AnyCancellable>()
    
    private var appearanceObserver: NSKeyValueObservation?

    // MARK: - Init

    public init(spaceMonitor: SpaceMonitor, configStore: ConfigStore) {
        self.spaceMonitor = spaceMonitor
        self.configStore = configStore
        self.bookmarkManager = BookmarkManager(configStore: configStore)
        self.sessionManager = WallpaperSessionManager()
        bind()
        setupAppearanceObserver()
    }

    // MARK: - Public Controls

    public func togglePause() {
        isPaused.toggle()
        if isPaused {
            sessionManager.allSessions.values.forEach { $0.pause() }
        } else {
            // Re-sync rather than just resuming, so any config or space changes
            // that arrived while paused are picked up immediately.
            synchronize(to: spaceMonitor.screenSpaces)
        }
    }

    // MARK: - Reactive Bindings

    private func bind() {
        spaceMonitor.$screenSpaces
            .sink { [weak self] spaces in
                self?.synchronize(to: spaces)
            }
            .store(in: &cancellables)

        configStore.$configs
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.spaceMonitor.refresh()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupAppearanceObserver() {
        // NSApp is nil in unit test contexts — skip observation
        guard let app = NSApp else { return }
        appearanceObserver = app.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor in
                self?.spaceMonitor.refresh()
            }
        }
    }
    
    // MARK: - Security-Scoped Access (Balanced)
    // MARK: - Synchronization

    private func synchronize(to spaces: [ScreenSpace]) {
        // NSApp is nil in unit test contexts — can't create windows without a running application
        guard let app = NSApp else { return }
        let appearance = app.effectiveAppearance
        sessionManager.synchronize(
            to: spaces,
            appearance: appearance,
            configStore: configStore,
            bookmarkManager: bookmarkManager,
            isPaused: isPaused,
            onPlaybackError: { [weak self] spaceKey, message in
                Task { @MainActor in
                    self?.playbackErrors.send((spaceKey, message))
                }
            }
        )
    }
}

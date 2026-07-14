import AppKit
import AVFoundation
import Combine
import IOKit.ps

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
    private var errorObservation: AnyCancellable?
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

        let prefs = AppPreferences.shared
        let newPlayer = AVPlayer(url: url)
        newPlayer.isMuted = muted
        newPlayer.volume = volume
        newPlayer.preventsDisplaySleepDuringVideoPlayback = false
        newPlayer.automaticallyWaitsToMinimizeStalling = false

        applyPreferences(to: newPlayer, prefs: prefs)

        // Loop or freeze at end based on preference (captured for the observer).
        let loopMode = prefs.loopBehavior
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayer.currentItem,
            queue: .main
        ) { [weak newPlayer] _ in
            switch loopMode {
            case .loop:
                newPlayer?.seek(to: .zero)
                newPlayer?.play()
            case .playOnceFreeze:
                newPlayer?.pause()
            }
        }

        // Observe errors to bubble up
        // KVO callbacks can fire on arbitrary queues. By using Combine, we ensure
        // the closure executes on the main thread and avoids @MainActor isolation crashes.
        errorObservation = newPlayer.currentItem?.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak newPlayer] status in
                guard status == .failed, let error = newPlayer?.currentItem?.error else { return }
                LivelyLogger.wallpaper.error("AVPlayerItem failed: \(error.localizedDescription)")
                // Clear currentURL so the next synchronize() call can retry
                self?.currentURL = nil
                onError(error)
            }

        // Connect player to layer and start
        playerLayer.player = newPlayer
        self.player = newPlayer
        newPlayer.play()
    }

    private func applyPreferences(to player: AVPlayer, prefs: AppPreferences) {
        let peak = prefs.playbackQuality.preferredPeakBitRate
        if peak > 0 {
            player.currentItem?.preferredPeakBitRate = peak
        } else {
            player.currentItem?.preferredPeakBitRate = 0
        }

        // When hardware decoding is off, cap resolution as a software-friendly budget.
        if !prefs.hardwareDecoding {
            player.currentItem?.preferredMaximumResolution = CGSize(width: 1920, height: 1080)
        } else {
            let maxH = prefs.maxResolution.preferredMaxHeight
            if maxH > 0 {
                player.currentItem?.preferredMaximumResolution = CGSize(width: maxH * 16 / 9, height: maxH)
            } else {
                player.currentItem?.preferredMaximumResolution = .zero
            }
        }
    }

    func applyPlaybackPreferences(_ prefs: AppPreferences = .shared) {
        guard let player else { return }
        applyPreferences(to: player, prefs: prefs)
    }

    /// Forces the next `play` call to rebuild the player (e.g. loop mode change).
    func invalidatePlayback() {
        currentURL = nil
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
        errorObservation?.cancel()
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
        // Release scopes for other Spaces on the same display before starting a new one.
        let displayPrefix = "\(space.id):"
        for key in Array(activeScopes.keys) where key.hasPrefix(displayPrefix) && key != space.spaceKey {
            stopScope(for: key)
        }

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

    func stopScopes(withDisplayID displayID: String) {
        let prefix = "\(displayID):"
        for key in Array(activeScopes.keys) where key.hasPrefix(prefix) {
            stopScope(for: key)
        }
    }

    func stopAllScopes() {
        for key in Array(activeScopes.keys) {
            stopScope(for: key)
        }
    }

    private func startScope(for spaceKey: String, url: URL) {
        if let existing = activeScopes[spaceKey], existing == url {
            // Already scoped for this exact URL
            return
        }
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

    func tearDownAll(bookmarkManager: BookmarkManager) {
        for (_, session) in sessions {
            session.hide()
        }
        sessions.removeAll()
        bookmarkManager.stopAllScopes()
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
            bookmarkManager.stopScopes(withDisplayID: id)
        }

        // While paused, skip playback updates; togglePause() will re-sync on resume.
        guard !isPaused else { return }

        for space in spaces {
            var session = sessions[space.id]
            if session == nil {
                session = WallpaperSession(screen: space.screen)
                sessions[space.id] = session
            }

            let spaceKey = space.spaceKey  // capture before Sendable closure
            let wallpaperConfig = configStore.configs[spaceKey]?.dynamicWallpaper ?? DynamicWallpaper()

            if let videoURL = bookmarkManager.urlForSpace(space, appearance: appearance) {
                session?.play(
                    url: videoURL,
                    wallpaper: wallpaperConfig,
                    screen: space.screen,
                    onError: { error in
                        onPlaybackError(spaceKey, error.localizedDescription)
                    }
                )
            } else {
                bookmarkManager.stopScope(for: spaceKey)
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
    @Published public private(set) var isThrottled = false
    /// True when wallpapers are paused due to battery policy (threshold or hard 25% floor).
    @Published public private(set) var isBatteryPaused = false
    /// Current battery charge 0–100 when available; nil on desktops without a battery.
    @Published public private(set) var batteryLevelPercent: Double?
    /// True when the Mac is drawing from battery.
    @Published public private(set) var isOnBattery = false
    /// True when pause was forced by the hard 25% floor (vs user threshold).
    @Published public private(set) var isForcedBatteryPause = false
    
    /// Bubbles up playback errors (spaceKey, Error message) to the UI
    public let playbackErrors = PassthroughSubject<(String, String), Never>()

    // MARK: - Private

    private let spaceMonitor: SpaceMonitor
    private let configStore: ConfigStore
    private let preferences: AppPreferences
    private let bookmarkManager: BookmarkManager
    private let sessionManager: WallpaperSessionManager
    private var cancellables = Set<AnyCancellable>()
    
    private var appearanceObserver: AnyCancellable?
    private var thermalStateObserver: AnyCancellable?
    private var powerSourceTimer: Timer?

    // MARK: - Init

    public init(
        spaceMonitor: SpaceMonitor,
        configStore: ConfigStore,
        preferences: AppPreferences = .shared
    ) {
        self.spaceMonitor = spaceMonitor
        self.configStore = configStore
        self.preferences = preferences
        self.bookmarkManager = BookmarkManager(configStore: configStore)
        self.sessionManager = WallpaperSessionManager()
        
        let state = ProcessInfo.processInfo.thermalState
        self.isThrottled = state == .serious || state == .critical
        let snap = PowerSourceMonitor.snapshot()
        self.isOnBattery = snap.isOnBattery
        self.batteryLevelPercent = snap.levelPercent
        let decision = Self.batteryPauseDecision(
            isOnBattery: snap.isOnBattery,
            level: snap.levelPercent,
            pauseEnabled: preferences.pauseOnBattery,
            threshold: preferences.batteryPauseThreshold
        )
        self.isBatteryPaused = decision.shouldPause
        self.isForcedBatteryPause = decision.isForcedFloor
        
        bind()
        setupAppearanceObserver()
        setupThermalStateObserver()
        setupBatteryMonitor()
        observePreferences()
    }

    // MARK: - Public Controls

    /// Tears down all sessions and releases security-scoped resources.
    /// Call from `applicationWillTerminate` before flushing config.
    public func tearDown() {
        sessionManager.tearDownAll(bookmarkManager: bookmarkManager)
        appearanceObserver?.cancel()
        appearanceObserver = nil
        thermalStateObserver?.cancel()
        thermalStateObserver = nil
        powerSourceTimer?.invalidate()
        powerSourceTimer = nil
        cancellables.removeAll()
    }

    public func togglePause() {
        isPaused.toggle()
        applyPlaybackState()
    }

    private var shouldHaltPlayback: Bool {
        isPaused || isThrottled || isBatteryPaused
    }

    private func applyPlaybackState() {
        if shouldHaltPlayback {
            sessionManager.allSessions.values.forEach { $0.pause() }
        } else {
            // Re-sync rather than just resuming, so any config or space changes
            // that arrived while paused are picked up immediately.
            synchronize(to: spaceMonitor.screenSpaces)
        }
    }

    private func observePreferences() {
        preferences.$pauseOnBattery
            .combineLatest(preferences.$batteryPauseThreshold)
            .dropFirst()
            .sink { [weak self] _, _ in
                self?.refreshBatteryState()
            }
            .store(in: &cancellables)

        // Loop mode is captured when the player is created — full reload required.
        preferences.$loopBehavior
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self else { return }
                self.sessionManager.allSessions.values.forEach { $0.invalidatePlayback() }
                if !self.shouldHaltPlayback {
                    self.synchronize(to: self.spaceMonitor.screenSpaces)
                }
            }
            .store(in: &cancellables)

        // Quality / decode budget can soft-apply without tearing down AVPlayers.
        preferences.$playbackQuality
            .combineLatest(preferences.$hardwareDecoding, preferences.$maxResolution)
            .dropFirst()
            .sink { [weak self] _, _, _ in
                guard let self else { return }
                self.sessionManager.allSessions.values.forEach {
                    $0.applyPlaybackPreferences(self.preferences)
                }
            }
            .store(in: &cancellables)
    }

    private func setupBatteryMonitor() {
        // Lightweight poll — power-source CF notifications are awkward to bridge;
        // 30s is enough for "pause on battery" without battery impact.
        // Poll power source periodically (IOKit has no simple Combine publisher).
        // 20s is responsive enough for "pause on battery" without busy-waiting.
        powerSourceTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshBatteryState()
            }
        }
        // Also refresh when Low Power Mode changes (related power policy signal).
        NotificationCenter.default.publisher(for: Notification.Name("NSProcessInfoPowerStateDidChange"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (_: Notification) in
                self?.refreshBatteryState()
            }
            .store(in: &cancellables)
    }

    private func refreshBatteryState() {
        let snap = PowerSourceMonitor.snapshot()
        let decision = Self.batteryPauseDecision(
            isOnBattery: snap.isOnBattery,
            level: snap.levelPercent,
            pauseEnabled: preferences.pauseOnBattery,
            threshold: preferences.batteryPauseThreshold
        )

        let levelChanged = batteryLevelPercent != snap.levelPercent
        let onBatteryChanged = isOnBattery != snap.isOnBattery
        let pauseChanged = isBatteryPaused != decision.shouldPause
            || isForcedBatteryPause != decision.isForcedFloor

        isOnBattery = snap.isOnBattery
        batteryLevelPercent = snap.levelPercent
        isForcedBatteryPause = decision.isForcedFloor

        guard pauseChanged || levelChanged || onBatteryChanged else { return }

        if pauseChanged {
            isBatteryPaused = decision.shouldPause
            applyPlaybackState()
            if decision.shouldPause {
                let pct = snap.levelPercent.map { String(format: "%.0f%%" , $0) } ?? "unknown"
                if decision.isForcedFloor {
                    LivelyLogger.wallpaper.info("Paused wallpapers — battery at \(pct) (hard floor 25%)")
                } else {
                    LivelyLogger.wallpaper.info("Paused wallpapers — battery at \(pct) (threshold \(Int(preferences.batteryPauseThreshold))%)")
                }
            } else {
                LivelyLogger.wallpaper.info("Resumed wallpapers — AC power or battery above threshold")
            }
        }
    }

    /// Battery pause policy:
    /// - On AC: never pause for battery.
    /// - On battery at/below 25%: always pause (forced floor).
    /// - On battery with "Pause on Battery" on: pause when level ≤ user threshold.
    nonisolated static func batteryPauseDecision(
        isOnBattery: Bool,
        level: Double?,
        pauseEnabled: Bool,
        threshold: Double
    ) -> (shouldPause: Bool, isForcedFloor: Bool) {
        guard isOnBattery else { return (false, false) }
        let floor = AppPreferences.forcedBatteryPausePercent
        let clampedThreshold = AppPreferences.clampThreshold(threshold)

        if let level {
            if level <= floor {
                return (true, true)
            }
            if pauseEnabled && level <= clampedThreshold {
                return (true, false)
            }
            return (false, false)
        }

        // Unknown level: if user enabled pause-on-battery, treat as pause while on battery.
        if pauseEnabled {
            return (true, false)
        }
        return (false, false)
    }

    // MARK: - Reactive Bindings

    private func bind() {
        spaceMonitor.$screenSpaces
            .sink { [weak self] spaces in
                guard let self else { return }
                let activeKeys = Set(spaces.map(\.spaceKey))
                configStore.pruneOrphanedConfigs(activeSpaceKeys: activeKeys)
                synchronize(to: spaces)
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
        appearanceObserver = app.publisher(for: \.effectiveAppearance)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.spaceMonitor.refresh()
            }
    }

    private func setupThermalStateObserver() {
        thermalStateObserver = NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let state = ProcessInfo.processInfo.thermalState
                let shouldThrottle = state == .serious || state == .critical
                if self.isThrottled != shouldThrottle {
                    self.isThrottled = shouldThrottle
                    self.applyPlaybackState()
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
            isPaused: shouldHaltPlayback,
            onPlaybackError: { [weak self] spaceKey, message in
                Task { @MainActor in
                    self?.playbackErrors.send((spaceKey, message))
                }
            }
        )
    }
}

// MARK: - Power Source

enum PowerSourceMonitor {
    struct Snapshot {
        var isOnBattery: Bool
        /// 0–100 when known.
        var levelPercent: Double?
    }

    static func snapshot() -> Snapshot {
        guard
            let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return Snapshot(
                isOnBattery: ProcessInfo.processInfo.isLowPowerModeEnabled,
                levelPercent: nil
            )
        }

        var onBattery = false
        var level: Double?

        for source in list {
            guard
                let desc = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any]
            else { continue }

            if let state = desc[kIOPSPowerSourceStateKey] as? String,
               state == kIOPSBatteryPowerValue {
                onBattery = true
            }
            // Current capacity is typically 0–100 for internal batteries.
            if let capacity = desc[kIOPSCurrentCapacityKey] as? Int {
                level = Double(capacity)
            } else if let capacity = desc[kIOPSCurrentCapacityKey] as? Double {
                level = capacity
            }
        }

        if !onBattery && list.isEmpty {
            onBattery = ProcessInfo.processInfo.isLowPowerModeEnabled
        }

        return Snapshot(isOnBattery: onBattery, levelPercent: level)
    }

    static var isOnBattery: Bool { snapshot().isOnBattery }
}

import AppKit
import AVFoundation

// MARK: - VideoPlayerView

@MainActor
class VideoPlayerView: NSView {

    // MARK: - Private State

    private var playerLayer: AVPlayerLayer?
    private var player: AVPlayer?
    private var loopObserver: Any?
    private var errorObservation: NSKeyValueObservation?
    private var pendingURL: URL?

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        // Use layer-backed view (let AppKit manage the layer)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }
    
    // MARK: - Layer Lifecycle
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        if window != nil && playerLayer == nil {
            // The view is now in a window — layer is guaranteed to exist.
            // Create the AVPlayerLayer now if we haven't yet.
            let pl = AVPlayerLayer()
            pl.videoGravity = .resizeAspectFill
            pl.frame = bounds
            pl.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            layer?.addSublayer(pl)
            playerLayer = pl
            LivelyLogger.videoPreview.info("AVPlayerLayer added to layer tree (window: \(self.window?.title ?? "untitled"))")
            
            // If a URL was requested before we had a layer, load it now
            if let url = pendingURL {
                pendingURL = nil
                load(url: url)
            }
        } else if window == nil {
            // View removed from window — stop playback to free resources
            tearDownPlayer()
        }
    }

    override func layout() {
        super.layout()
        playerLayer?.frame = bounds
    }

    // MARK: - Public API

    /// Loads and immediately plays a video, replacing any currently playing video.
    func load(url: URL) {
        // If layer isn't ready yet, defer until viewDidMoveToWindow
        guard let playerLayer = playerLayer else {
            LivelyLogger.videoPreview.debug("Deferring load — layer not ready yet")
            pendingURL = url
            return
        }
        
        tearDownPlayer()

        LivelyLogger.videoPreview.info("Loading \(url.lastPathComponent)")
        
        let player = AVPlayer(url: url)
        player.isMuted = true
        player.volume = 0
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.automaticallyWaitsToMinimizeStalling = false

        // Loop via notification (more reliable than AVPlayerLooper)
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }
        
        // Observe errors for debugging
        errorObservation = player.currentItem?.observe(\.status, options: [.new]) { item, _ in
            if item.status == .failed {
                LivelyLogger.videoPreview.error("AVPlayerItem failed: \(item.error?.localizedDescription ?? "unknown")")
            } else if item.status == .readyToPlay {
                LivelyLogger.videoPreview.info("Item ready to play")
            }
        }

        playerLayer.player = player
        self.player = player
        player.play()
        
        LivelyLogger.videoPreview.info("Player started for \(url.lastPathComponent)")
    }

    func stop() {
        tearDownPlayer()
    }

    /// Crossfades to a new video.
    func crossFade(to url: URL, duration: TimeInterval = 0.4) {
        if player == nil {
            load(url: url)
            return
        }

        guard let playerLayer = playerLayer else {
            pendingURL = url
            return
        }

        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        playerLayer.opacity = 0
        CATransaction.setCompletionBlock { [weak self] in
            Task { @MainActor in
                self?.load(url: url)
                CATransaction.begin()
                CATransaction.setAnimationDuration(duration)
                self?.playerLayer?.opacity = 1
                CATransaction.commit()
            }
        }
        CATransaction.commit()
    }
    
    // MARK: - Display Settings
    
    func setVideoGravity(_ gravity: AVLayerVideoGravity) {
        playerLayer?.videoGravity = gravity
    }
    
    func setVolume(_ volume: Float) {
        player?.volume = volume
    }
    
    func setMuted(_ muted: Bool) {
        player?.isMuted = muted
    }

    // MARK: - Private

    private func tearDownPlayer() {
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
        errorObservation?.invalidate()
        errorObservation = nil
        player?.pause()
        playerLayer?.player = nil
        player = nil
    }
}

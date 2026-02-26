import AppKit

// MARK: - WallpaperWindow

/// A borderless, non-interactive NSWindow that sits at the macOS desktop level.
///
/// One WallpaperWindow is created per physical display. It never steals keyboard
/// focus because we use orderBack(nil) rather than makeKeyAndOrderFront(_:).
///
/// ## Window Level
/// `CGWindowLevelForKey(.desktopWindow) + 1` places the window above the system
/// wallpaper but below the Finder desktop icon layer (which is at +20).
///
/// ## Collection Behavior
/// - .canJoinAllSpaces  — window is visible on every Space
/// - .stationary        — window doesn't move when Exposé / Mission Control activates
/// - .ignoresCycle      — excluded from Command-Tab window cycling
class WallpaperWindow: NSWindow {

    init(screen: NSScreen) {
        let desktopLevel = NSWindow.Level(
            rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1
        )

        // Use the designated initializer
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.level = desktopLevel
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle
        ]
        // IMPORTANT: opaque + black background ensures the window is visible
        // even before the video loads. Without this, a transparent window is
        // invisible and macOS may skip compositing it entirely.
        self.isOpaque = true
        self.backgroundColor = .black
        self.ignoresMouseEvents = true
        self.hasShadow = false
        self.isReleasedWhenClosed = false
        self.canHide = false
        self.sharingType = .none
        self.animationBehavior = .none

        // Cover the full screen frame
        setFrame(screen.frame, display: false)
    }

    // MARK: - Ordering

    /// Places the window on screen behind all other windows at the same level.
    ///
    /// `orderBack` is correct for desktop wallpaper windows — it keeps the window
    /// below normal windows while remaining above the system wallpaper.
    /// Using `orderFront` would fight with Finder.
    func show() {
        let desktopLevel = NSWindow.Level(
            rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1
        )
        self.level = desktopLevel
        orderBack(nil)
    }

    // MARK: - Overrides

    /// Override to guarantee we never accidentally steal key-window status.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

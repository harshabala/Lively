import AppKit
import SwiftUI

@MainActor
public final class LibraryWindowController: NSObject, NSWindowDelegate {
    public static let shared = LibraryWindowController()
    private var libraryWindow: NSWindow?

    private override init() { super.init() }

    public func openLibraryWindow(spaceMonitor: SpaceMonitor, configStore: ConfigStore) {
        if let window = libraryWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let libraryView = LibraryView(spaceMonitor: spaceMonitor, configStore: configStore, libraryManager: WallpaperLibraryManager.shared)
        let hostingView = NSHostingView(rootView: libraryView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Wallpaper Library"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.libraryWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func windowWillClose(_ notification: Notification) {
        libraryWindow = nil
    }
}



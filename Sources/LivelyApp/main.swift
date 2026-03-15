import AppKit
import SwiftUI
import LivelyCore

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?

    // Core services — lazy so init order is explicit
    private let spaceMonitor = SpaceMonitor()
    private let configStore = ConfigStore()
    private lazy var wallpaperController = WallpaperController(
        spaceMonitor: spaceMonitor,
        configStore: configStore
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Background-only process — no Dock icon
        NSApp.setActivationPolicy(.accessory)

        // Warm up the controller (triggers initial wallpaper load for all screens)
        _ = wallpaperController

        setupMenuBar()
    }

    func applicationWillTerminate(_ notification: Notification) {
        configStore.flushPendingPersist()
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "play.tv.fill",
                accessibilityDescription: "Lively"
            )
        }

        let menu = NSMenu()
        menu.delegate = self

        menu.addItem(
            withTitle: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        menu.addItem(.separator())

        // Status indicator (non-interactive)
        let statusItem = NSMenuItem(
            title: "▶ Playing",
            action: nil,
            keyEquivalent: ""
        )
        statusItem.tag = 200
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        
        let pauseItem = NSMenuItem(
            title: "Pause Wallpapers",
            action: #selector(togglePause),
            keyEquivalent: "p"
        )
        pauseItem.tag = 100
        menu.addItem(pauseItem)
        menu.addItem(.separator())

        menu.addItem(
            withTitle: "Quit Lively",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        self.statusItem.menu = menu
    }

    @objc private func togglePause() {
        wallpaperController.togglePause()
        updateMenuState()
    }
    
    private func updateMenuState() {
        guard let menu = statusItem.menu else { return }
        
        if let pauseItem = menu.item(withTag: 100) {
            pauseItem.title = wallpaperController.isPaused ? "Resume Wallpapers" : "Pause Wallpapers"
        }
        if let statusLabel = menu.item(withTag: 200) {
            statusLabel.title = wallpaperController.isPaused ? "⏸ Paused" : "▶ Playing"
        }
        
        // Update menu bar icon
        if let button = statusItem.button {
            let iconName = wallpaperController.isPaused ? "pause.circle.fill" : "play.tv.fill"
            button.image = NSImage(
                systemSymbolName: iconName,
                accessibilityDescription: "Lively"
            )
        }
    }

    // MARK: - Settings Window

    @objc func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(spaceMonitor: spaceMonitor, configStore: configStore)
                .environmentObject(wallpaperController)
            let hosting = NSHostingController(rootView: view)

            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
                styleMask: [
                    .titled,
                    .closable,
                    .fullSizeContentView,
                    .nonactivatingPanel
                ],
                backing: .buffered,
                defer: false
            )
            panel.titlebarAppearsTransparent = true
            panel.titleVisibility = .hidden
            panel.isMovableByWindowBackground = true
            panel.center()
            panel.contentViewController = hosting
            panel.isReleasedWhenClosed = false
            panel.identifier = NSUserInterfaceItemIdentifier("lively.settings")
            self.settingsWindow = panel
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        updateMenuState()
    }
}

// Entry point
AppDelegate.main()

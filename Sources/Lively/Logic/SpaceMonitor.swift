import AppKit
import Combine

// MARK: - ScreenSpace

/// A snapshot of one physical display's active Space / wallpaper state.
///
/// This type is `@MainActor`-only — it holds an `NSScreen` reference which is
/// not `Sendable`. Never pass instances across isolation boundaries.
@MainActor
public struct ScreenSpace: Equatable, Identifiable {

    /// Stable display identifier derived from CGDirectDisplayID.
    public let id: String

    public let screen: NSScreen
    public let desktopImageURL: URL?
    public let displayName: String

    /// Composite config-store key: "displayID:desktopImageURL".
    /// Stable across app restarts; encodes both which screen AND which Space.
    public var spaceKey: String {
        guard let url = desktopImageURL else { return id }
        return "\(id):\(url.absoluteString)"
    }

    nonisolated public static func == (lhs: ScreenSpace, rhs: ScreenSpace) -> Bool {
        lhs.id == rhs.id && lhs.desktopImageURL == rhs.desktopImageURL
    }
}

// MARK: - SpaceMonitor

@MainActor
public class SpaceMonitor: ObservableObject {

    @Published public private(set) var screenSpaces: [ScreenSpace] = []

    private var cancellables = Set<AnyCancellable>()

    public init() {
        refresh()

        // User switches Spaces (swipe with 4 fingers / Control+Arrow)
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .sink { [weak self] _ in self?.handleSpaceChange() }
            .store(in: &cancellables)

        // Monitor connected or disconnected
        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
    }

    // MARK: - Public

    /// Force a refresh — used by WallpaperController when configs change.
    public func refresh() {
        screenSpaces = NSScreen.screens.map { screen in
            ScreenSpace(
                id: Self.displayID(for: screen),
                screen: screen,
                desktopImageURL: NSWorkspace.shared.desktopImageURL(for: screen),
                displayName: screen.localizedName
            )
        }
    }

    // MARK: - Private

    private func handleSpaceChange() {
        // macOS takes a variable amount of time to propagate the new desktopImageURL
        // after a Space switch. Poll every 50ms up to 500ms, stopping early once
        // the URL actually changes (or if no previous state exists).
        let previousURLs = Dictionary(
            uniqueKeysWithValues: screenSpaces.map { ($0.id, $0.desktopImageURL) }
        )
        Task {
            for _ in 0..<10 {  // 10 × 50ms = 500ms max
                try? await Task.sleep(for: .milliseconds(50))
                let current = NSScreen.screens.compactMap { screen -> (String, URL?)? in
                    let id = Self.displayID(for: screen)
                    return (id, NSWorkspace.shared.desktopImageURL(for: screen))
                }
                let changed = current.contains { id, url in
                    previousURLs[id] != url
                }
                if changed || previousURLs.isEmpty { break }
            }
            refresh()
        }
    }

    // MARK: - Helpers

    /// Returns the CGDirectDisplayID as a String — stable across reboots for the
    /// same physical display connection.
    public static func displayID(for screen: NSScreen) -> String {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        if let displayID = screen.deviceDescription[key] as? CGDirectDisplayID {
            return String(displayID)
        }
        // Fallback: localizedName is less stable but better than nothing
        return screen.localizedName
    }
}

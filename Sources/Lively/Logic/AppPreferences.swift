import Foundation
import Combine
import CoreGraphics
import SwiftUI
import AppKit

/// Global app preferences persisted in UserDefaults.
///
/// Keeps Settings UI state out of `ConfigStore` (which owns per-Space wallpaper
/// assignments) so preference toggles stay lightweight and independent.
@MainActor
public final class AppPreferences: ObservableObject {
    public static let shared = AppPreferences()

    /// Hard floor: wallpapers always pause on battery at or below this level.
    nonisolated public static let forcedBatteryPausePercent: Double = 25
    /// User threshold range when "Pause on Battery" is enabled.
    nonisolated public static let batteryThresholdRange: ClosedRange<Double> = 25...100

    // MARK: - Appearance

    public enum AppAppearance: String, CaseIterable, Identifiable, Sendable {
        case system
        case light
        case dark

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }

        public var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    // MARK: - Playback quality

    public enum PlaybackQuality: String, CaseIterable, Identifiable, Sendable {
        case high
        case balanced
        case powerSaver

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .high: return "High Quality"
            case .balanced: return "Balanced"
            case .powerSaver: return "Power Saver"
            }
        }

        public var detail: String {
            switch self {
            case .high: return "Best image quality. Uses more CPU and battery."
            case .balanced: return "Good quality with moderate resource use."
            case .powerSaver: return "Lower bitrate for cooler, quieter playback."
            }
        }

        public var preferredPeakBitRate: Double {
            switch self {
            case .high: return 0
            case .balanced: return 8_000_000
            case .powerSaver: return 2_500_000
            }
        }
    }

    // MARK: - Loop behavior

    public enum LoopBehavior: String, CaseIterable, Identifiable, Sendable {
        case loop
        case playOnceFreeze

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .loop: return "Loop"
            case .playOnceFreeze: return "Play Once & Freeze"
            }
        }
    }

    // MARK: - Max decode resolution

    public enum MaxResolution: String, CaseIterable, Identifiable, Sendable {
        case matchSource
        case p1080
        case p4k

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .matchSource: return "Match Source"
            case .p1080: return "1080p"
            case .p4k: return "4K"
            }
        }

        public var preferredMaxHeight: CGFloat {
            switch self {
            case .matchSource: return 0
            case .p4k: return 2160
            case .p1080: return 1080
            }
        }
    }

    public typealias FrameRateCap = MaxResolution

    private enum Keys {
        static let startMinimized = "prefs.startMinimized"
        static let pauseOnBattery = "prefs.pauseOnBattery"
        static let batteryPauseThreshold = "prefs.batteryPauseThreshold"
        static let checkForUpdates = "prefs.checkForUpdates"
        static let playbackQuality = "prefs.playbackQuality"
        static let loopBehavior = "prefs.loopBehavior"
        static let hardwareDecoding = "prefs.hardwareDecoding"
        static let maxResolution = "prefs.maxResolution"
        static let frameRateCapLegacy = "prefs.frameRateCap"
        static let appearance = "prefs.appearance"
        // First-run product coaching (product-review roadmap)
        static let hasCompletedWelcome = "prefs.hasCompletedWelcome"
        static let hasDismissedDisplaysTip = "prefs.hasDismissedDisplaysTip"
        static let hasSeenSpacesCoach = "prefs.hasSeenSpacesCoach"
    }

    private let defaults: UserDefaults

    @Published public var startMinimized: Bool {
        didSet { defaults.set(startMinimized, forKey: Keys.startMinimized) }
    }

    /// When true, pause wallpapers on battery once charge is at or below `batteryPauseThreshold`.
    /// Regardless of this toggle, wallpapers always pause at or below 25% on battery.
    @Published public var pauseOnBattery: Bool {
        didSet { defaults.set(pauseOnBattery, forKey: Keys.pauseOnBattery) }
    }

    /// User-chosen threshold (25–100). Clamped to `batteryThresholdRange`.
    @Published public var batteryPauseThreshold: Double {
        didSet {
            let clamped = Self.clampThreshold(batteryPauseThreshold)
            if clamped != batteryPauseThreshold {
                batteryPauseThreshold = clamped
                return
            }
            defaults.set(clamped, forKey: Keys.batteryPauseThreshold)
        }
    }

    @Published public var checkForUpdates: Bool {
        didSet { defaults.set(checkForUpdates, forKey: Keys.checkForUpdates) }
    }

    @Published public var playbackQuality: PlaybackQuality {
        didSet { defaults.set(playbackQuality.rawValue, forKey: Keys.playbackQuality) }
    }

    @Published public var loopBehavior: LoopBehavior {
        didSet { defaults.set(loopBehavior.rawValue, forKey: Keys.loopBehavior) }
    }

    @Published public var hardwareDecoding: Bool {
        didSet { defaults.set(hardwareDecoding, forKey: Keys.hardwareDecoding) }
    }

    @Published public var maxResolution: MaxResolution {
        didSet { defaults.set(maxResolution.rawValue, forKey: Keys.maxResolution) }
    }

    @Published public var appearance: AppAppearance {
        didSet {
            defaults.set(appearance.rawValue, forKey: Keys.appearance)
            Self.applyAppAppearance(appearance)
        }
    }

    /// First-launch welcome sheet completed (dismiss or choose video).
    @Published public var hasCompletedWelcome: Bool {
        didSet { defaults.set(hasCompletedWelcome, forKey: Keys.hasCompletedWelcome) }
    }

    /// Inline Displays tip strip dismissed forever.
    @Published public var hasDismissedDisplaysTip: Bool {
        didSet { defaults.set(hasDismissedDisplaysTip, forKey: Keys.hasDismissedDisplaysTip) }
    }

    /// One-time “Switch Spaces…” coach after first wallpaper.
    @Published public var hasSeenSpacesCoach: Bool {
        didSet { defaults.set(hasSeenSpacesCoach, forKey: Keys.hasSeenSpacesCoach) }
    }

    public var frameRateCap: MaxResolution {
        get { maxResolution }
        set { maxResolution = newValue }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if defaults.object(forKey: Keys.startMinimized) == nil {
            defaults.set(true, forKey: Keys.startMinimized)
        }
        if defaults.object(forKey: Keys.pauseOnBattery) == nil {
            defaults.set(true, forKey: Keys.pauseOnBattery)
        }
        if defaults.object(forKey: Keys.checkForUpdates) == nil {
            defaults.set(true, forKey: Keys.checkForUpdates)
        }
        if defaults.object(forKey: Keys.hardwareDecoding) == nil {
            defaults.set(true, forKey: Keys.hardwareDecoding)
        }
        if defaults.object(forKey: Keys.batteryPauseThreshold) == nil {
            defaults.set(35.0, forKey: Keys.batteryPauseThreshold)
        }

        self.startMinimized = defaults.bool(forKey: Keys.startMinimized)
        self.pauseOnBattery = defaults.bool(forKey: Keys.pauseOnBattery)
        self.checkForUpdates = defaults.bool(forKey: Keys.checkForUpdates)
        self.hardwareDecoding = defaults.bool(forKey: Keys.hardwareDecoding)
        self.batteryPauseThreshold = Self.clampThreshold(defaults.double(forKey: Keys.batteryPauseThreshold))
        self.hasCompletedWelcome = defaults.bool(forKey: Keys.hasCompletedWelcome)
        self.hasDismissedDisplaysTip = defaults.bool(forKey: Keys.hasDismissedDisplaysTip)
        self.hasSeenSpacesCoach = defaults.bool(forKey: Keys.hasSeenSpacesCoach)

        let qualityRaw = defaults.string(forKey: Keys.playbackQuality) ?? PlaybackQuality.high.rawValue
        self.playbackQuality = PlaybackQuality(rawValue: qualityRaw) ?? .high

        let loopRaw = defaults.string(forKey: Keys.loopBehavior) ?? LoopBehavior.loop.rawValue
        self.loopBehavior = LoopBehavior(rawValue: loopRaw) ?? .loop

        let resRaw = defaults.string(forKey: Keys.maxResolution)
            ?? defaults.string(forKey: Keys.frameRateCapLegacy)
            ?? MaxResolution.matchSource.rawValue
        let normalized: String = {
            switch resRaw {
            case "fps30": return MaxResolution.p1080.rawValue
            case "fps60": return MaxResolution.p4k.rawValue
            default: return resRaw
            }
        }()
        self.maxResolution = MaxResolution(rawValue: normalized) ?? .matchSource

        let appearanceRaw = defaults.string(forKey: Keys.appearance) ?? AppAppearance.system.rawValue
        self.appearance = AppAppearance(rawValue: appearanceRaw) ?? .system
        Self.applyAppAppearance(self.appearance)
    }

    nonisolated public static func clampThreshold(_ value: Double) -> Double {
        min(max(value, batteryThresholdRange.lowerBound), batteryThresholdRange.upperBound)
    }

    /// Applies NSApp appearance for popover + menu-bar hosting consistency.
    public static func applyAppAppearance(_ appearance: AppAppearance) {
        guard NSApp != nil else { return }
        switch appearance {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

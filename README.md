# Lively

Lively is a macOS menu bar app that plays looping video wallpapers on each Space of your displays. It is built with Swift, AppKit, SwiftUI, AVFoundation, and Combine.

## Requirements

- **Platform**: macOS 14.0 or later  
- **Build system**: Swift Package Manager (`swift` 6.2 or newer)

## Building and running

- **Build**:

```bash
swift build
```

- **Run tests**:

```bash
swift test
```

- **Run the app (debug)**:

```bash
swift run LivelyApp
```

## Packaging

To produce a signed `.app` bundle in the `Output/` directory:

```bash
./package.sh
```

The script:

- Builds a **release** binary via Swift Package Manager.  
- Creates `Lively.app` under `Output/`.  
- Generates an `Info.plist` whose bundle identifier matches the main project (`com.lively.app`).  
- Performs **ad-hoc code signing** with `entitlements.plist` so `SMAppService` (Launch at Login) works locally.

You can then launch the packaged app with:

```bash
open Output/Lively.app
```

## Entitlements and sandboxing

Lively currently runs **unsandboxed** (`com.apple.security.app-sandbox` is `false`) because it needs to draw behind other apps and manage Spaces.

The entitlements file (`entitlements.plist`) grants:

- `com.apple.security.files.user-selected.read-only`: read-only access to user-selected files.  
- `com.apple.security.files.bookmarks.app-scope`: app-scoped security-scoped bookmarks so video files remain accessible across launches.

There is **no network entitlement** configured; the app does not perform network requests. If you later add network features, you can explicitly enable the appropriate entitlements.

If you plan to ship via the Mac App Store, you will need to:

- Enable the app sandbox.  
- Re‑verify that the bookmark-based file access pattern works correctly under sandboxing.

## Logging and privacy

Logging is handled through a small wrapper around `os.Logger` (`LivelyLogger` in `LivelyCore`). Key points:

- Logs are categorised by subsystem (`com.lively.app`) and component (ConfigStore, WallpaperController, SpaceMonitor, VideoPlayerView).  
- Verbose or debug-only information is suitable for development builds.  
- File‑related logs use `lastPathComponent` where possible to avoid exposing full filesystem paths in normal logs.

You can further tune log levels or redact additional details when preparing production builds.

## Project layout (high level)

- `Sources/Lively` (LivelyCore library)
  - Core logic (`ConfigStore`, `DynamicWallpaper`, `SpaceMonitor`, `WallpaperController`, `WallpaperWindow`)
  - UI (`SettingsView`, glass effects)
  - Media (`VideoPlayerView`)
- `Sources/LivelyApp`
  - `main.swift` with `AppDelegate`, menu bar integration, settings window, and service wiring.
- `Tests/LivelyTests`
  - Unit tests for `DynamicWallpaper`, `ConfigStore`, `SpaceMonitor`, video validation, and core controller behaviour.


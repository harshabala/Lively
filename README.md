# Lively

**Video wallpapers for every Space on your Mac.**

Lively lives in the menu bar and plays looping video on every display and Space — independently. Switch to a different Space and a different video can be playing there. No Dock icon, no app window cluttering your desktop. Just your wallpaper, doing its thing.

---

## What makes it different

Most "video wallpaper" apps on macOS are wrappers around a web renderer or an Electron shell. Lively is not. It is a native Swift app built entirely on Apple frameworks with **zero third-party dependencies**. Everything — video decoding, window management, animations, preferences — runs through the frameworks Apple ships with macOS.

**Per-Space wallpapers.** Each macOS Space gets its own independently playing video. Assign a different clip to your focus Space, your chat Space, your music Space. They play simultaneously and independently without any coupling.

**Hardware-accelerated 4K.** Lively uses AVFoundation's hardware decode pipeline. HEVC (H.265) and H.264 run on the dedicated hardware video engine — Apple Silicon handles a full 4K HEVC loop at nearly zero CPU cost.

**Codec validation before assignment.** Before a video becomes a wallpaper, Lively inspects its actual codec track using `CMFormatDescription`. VP9 and AV1 are rejected with a clear error message rather than silently producing a black screen. Only H.264 and HEVC are accepted — codecs that macOS can hardware-decode efficiently.

**Security-scoped bookmark persistence.** Wallpaper assignments survive reboots. Lively stores security-scoped bookmarks (not raw paths) so it re-opens your video files across launches without ever asking for broad file-system access.

**Launch at Login via SMAppService.** No LaunchAgents plist, no daemon registration. Uses the modern `SMAppService` API introduced in macOS 13.

**Completely offline.** No analytics, no telemetry, no network entitlement whatsoever. There is nothing to phone home to.

**Motion-designed UI.** The interface uses `matchedGeometryEffect` sliding pill navigation, asymmetric spring transitions between tabs, staggered card entrances on display detection, and `contentTransition(.symbolEffect(.replace))` icon cross-fades throughout. Every animation is gated on `@Environment(\.accessibilityReduceMotion)`.

---

## Requirements

- macOS 14.0 (Sonoma) or later
- Swift 6.2 or newer (Xcode Command Line Tools or full Xcode)
- Apple Silicon or Intel Mac

---

## Building

```bash
# Debug build
swift build

# Release build
swift build -c release

# Run tests
./test.sh
```

> **Note:** Command Line Tools ships `Testing.framework` in a non-standard path. `test.sh` adds the required search and rpath flags. If you have a full Xcode installation, `swift test` also works.

```bash
# Run in debug mode directly
swift run LivelyApp
```

## Packaging a signed `.app` bundle

```bash
./package.sh
```

This script:
- Builds a release binary with Swift Package Manager
- Assembles `Lively.app` at `/private/tmp/LivelyOutput/Lively.app` (override with `LIVELY_OUTPUT_DIR=`)
- Copies `AppIcon.icns` into `Contents/Resources/`
- Generates `Info.plist` with the correct bundle identifier (`com.lively.app`)
- Performs ad-hoc code signing with `entitlements.plist` so `SMAppService` works locally

```bash
open /private/tmp/LivelyOutput/Lively.app
```

---

## Supported formats

| Codec | Containers | Notes |
|-------|-----------|-------|
| H.264 (AVC) | MP4, MOV, M4V | Hardware-decoded on all supported Macs |
| HEVC (H.265) | MP4, MOV, M4V | Hardware-decoded on Apple Silicon and most Intel Macs with T1/T2 chip |

VP9 and AV1 are explicitly rejected at assignment time. If you have a VP9 video (common from YouTube downloads), re-encode to HEVC first:

```bash
# Find the file to avoid shell quoting issues with special characters
F=$(find ~/path/to/video -name "*.mp4" | head -1)
ffmpeg -i "$F" -c:v libx265 -crf 24 -preset fast -an output_hevc.mp4
```

No file size limit. AVFoundation streams video from disk rather than loading it into RAM, so multi-gigabyte 4K files play fine. The bottleneck is your SSD's read speed, not memory.

---

## Project layout

```
Sources/
  Lively/               — LivelyCore library (testable)
    Core/
      ConfigStore           — Preferences + security-scoped bookmark management
      DynamicWallpaper      — Per-Space wallpaper assignment model
      SpaceMonitor          — Display and active Space detection via CGS APIs
      WallpaperController   — AVPlayer lifecycle, pause/resume, Space tracking
      WallpaperWindow       — NSWindow subclass that draws behind the desktop layer
    UI/
      SettingsContainerView — Main panel with primary tab navigation
      DisplaysView          — Per-display Space card list with staggered entrance
      ScreenCardView        — Drop zone, mode picker, video thumbnail, volume slider
      AboutView             — Version info, codec support, update check
      LoggerView            — In-app log viewer for debugging
      VideoThumbnailView    — Async thumbnail generation with NSCache
      LivelyBrand           — Design tokens (colors, spacing, spring animations, type)
      GlassEffect           — NSVisualEffectView bridged to SwiftUI
  LivelyApp/            — Executable entry point
    main.swift          — AppDelegate, menu bar status item, SMAppService wiring
Tests/
  LivelyTests/          — Unit tests for core logic and codec validation
```

---

## Entitlements and sandboxing

Lively runs **unsandboxed**. Drawing video behind all other windows and managing Spaces requires capabilities the macOS App Sandbox does not currently permit.

| Entitlement | Purpose |
|-------------|---------|
| `com.apple.security.files.user-selected.read-only` | Read user-chosen video files |
| `com.apple.security.files.bookmarks.app-scope` | Re-open video files after relaunch without re-prompting |

No network, camera, microphone, or location entitlement is present.

If you plan to distribute via the Mac App Store, you will need to enable sandboxing and re-verify the bookmark-based file access pattern works under it.

---

## Logging and privacy

Logging uses `os.Logger` via a thin `LivelyLogger` wrapper, organised by subsystem (`com.lively.app`) and component. Logs are visible in Console.app filtered by subsystem. File paths in logs use `lastPathComponent` to avoid exposing full filesystem paths.

The app performs no network requests and collects no user data.

---

## Attributions

Lively uses **no third-party libraries**. Every line of code is built on Apple-provided frameworks:

| Framework | Used for |
|-----------|---------|
| AVFoundation | Video playback, codec inspection (`CMFormatDescription`) |
| CoreGraphics / CGS | Space and display enumeration |
| SwiftUI | All UI |
| AppKit | `NSWindow`, `NSVisualEffectView`, `NSStatusItem` |
| ServiceManagement | `SMAppService` for Launch at Login |
| os.Logger | Structured logging |

---

## Local verification

```bash
./scripts/smoke_verify.sh
open /private/tmp/LivelyOutput/Lively.app
```

Manual checks:
- Menu bar icon appears
- Settings opens from the menu bar
- Dropping or selecting `.mp4`, `.mov`, or `.m4v` assigns a wallpaper
- Pause/Resume updates playback state and menu label
- Quit and relaunch — persisted wallpaper assignments reload correctly

---

## Developer

Built by **[@harshabala](https://github.com/harshabala)**.

Designed, architected, and shipped using [Claude Code](https://claude.ai/code) — motion design audits, multi-agent implementation sprints, code reviews, and regression testing were all coordinated through AI coding agent sessions. The codec validation pipeline, security-scoped bookmark fix, and the full animation layer were each driven by dedicated subagent workflows. This is what AI-native development looks like in 2026.

Questions, ideas, or just want to say hi → **[github.com/harshabala](https://github.com/harshabala)**

---

*© 2026 Harsha Balakrishnan. All rights reserved.*

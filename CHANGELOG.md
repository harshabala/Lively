# Changelog

All notable changes to Lively are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-07-06

First public release. Lively is open source under the MIT License.

### Added

- **Per-Space, per-display video wallpapers** — assign different looping videos to each macOS Space on each monitor
- **Menu-bar utility** — runs as a background (`LSUIElement`) process with no Dock icon
- **Hardware-accelerated playback** — H.264 and HEVC via AVFoundation `AVPlayerLayer` behind the desktop
- **Codec validation** — rejects VP9, AV1, and unsupported codecs at assignment time with clear errors
- **Light / Dark appearance mode** — separate videos for macOS light and dark appearance on the same Space
- **Security-scoped bookmarks** — wallpaper assignments persist across reboots without broad filesystem access
- **Launch at Login** — `SMAppService` registration (macOS 13+)
- **Global pause / resume** — pause all wallpapers from the settings header
- **Per-display controls** — fill/fit scale, mute, volume, remove wallpaper
- **Drag-and-drop and file picker** — assign `.mp4`, `.mov`, `.m4v` files from Finder
- **In-app log viewer** — view and copy troubleshooting logs
- **Fully offline** — no network entitlement, analytics, or telemetry
- **Accessible UI** — Reduce Motion support, VoiceOver labels, 32pt hit targets, error announcements
- **Mist Reef design system** — native SwiftUI tokens via `LivelyBrand`

### Technical

- Native Swift 6.2 package with zero third-party dependencies
- `LivelyCore` library + `LivelyApp` executable
- Unit tests for `ConfigStore` and codec validation
- `package.sh` for local `.app` bundle assembly and ad-hoc signing

### Known limitations

- H.264 and HEVC only — re-encode other codecs before use
- Unsandboxed — required for desktop-layer video; not Mac App Store ready as-is
- No in-app auto-update — check GitHub Releases manually
- No playlists, schedules, or cross-Mac sync
- Distribution builds require Developer ID signing and notarization for Gatekeeper outside your machine

[1.0.0]: https://github.com/harshabala/Lively/releases/tag/v1.0.0
<p align="center">
  <img src="icon.png" alt="Lively icon" width="128" height="128">
</p>

# Lively

[![License: MIT](https://img.shields.io/badge/License-MIT-teal.svg)](LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue.svg)](https://www.apple.com/macos/)
[![Release](https://github.com/harshabala/Lively/releases)](https://github.com/harshabala/Lively/releases)

**Video wallpapers for your Mac.**

Lively is a small menu bar app. It plays looping video behind your desktop icons. Each display and each Space can have its own clip. No Dock icon. No account. No cloud.

## Install

1. Download the latest **DMG** or **zip** from [Releases](https://github.com/harshabala/Lively/releases/latest).
2. Drag **Lively.app** into **Applications**.
3. Open Lively. Look for it in the **menu bar** (top right).

### If macOS blocks the app

Lively is signed for local use, not notarized by Apple. After install, run once:

```bash
xattr -dr com.apple.quarantine /Applications/Lively.app
```

Or right-click **Lively.app** → **Open** → confirm.

### Homebrew

```bash
brew tap harshabala/lively https://github.com/harshabala/Lively
brew install --cask lively
```

## How to use

1. Click the menu bar icon.
2. On **Displays**, pick a display card.
3. Drop an **MP4**, **MOV**, or **M4V** on the zone (or click to browse).
4. Only **H.264** and **HEVC** work. Other codecs are rejected with a clear error.

### Modes

- **Wallpaper** — one video for that Space
- **Light & Dark** — different videos for light and dark appearance

### Library

Save videos once. Apply them to one display or all displays.

### Settings

- Launch at login
- Pause on battery
- Playback quality and loop
- Appearance (light / dark / system)
- Reset data
- Logs and About (includes first-launch help)

Pause and resume all wallpapers from the top of the window.

## What it is

| | |
|---|---|
| Platform | macOS 14+ |
| Stack | Native Swift. No third-party libraries. |
| Privacy | Offline by default. Optional GitHub update check only if you turn it on. |
| License | [MIT](LICENSE) |

## Limits

- **Codecs:** H.264 and HEVC only
- **Files:** `.mp4`, `.mov`, `.m4v`
- **Not App Store:** needs desktop-layer access the sandbox does not allow
- **Not notarized:** clear quarantine once after download (see Install)
- **No playlists or schedules** yet
- **Updates:** banner can open Releases; no auto-install

## Build from source

```bash
./package.sh
open /private/tmp/LivelyOutput/Lively.app
```

DMG with drag-to-Applications:

```bash
./scripts/make-dmg.sh
```

Needs Xcode or Command Line Tools.

## Privacy

Assignments stay on your Mac. Security-scoped bookmarks remember the files you chose. No analytics. No network entitlement for core use. Optional update check only talks to GitHub Releases when enabled.

## License

MIT. See [LICENSE](LICENSE).

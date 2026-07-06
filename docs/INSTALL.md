# Installing Lively

## Quick install (most users)

### Download from GitHub

1. Go to [Releases](https://github.com/harshabala/Lively/releases/latest)
2. Download `Lively-<version>-macOS.zip`
3. Unzip → drag `Lively.app` to **Applications**
4. Run in Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/Lively.app
open /Applications/Lively.app
```

### Homebrew

```bash
brew tap harshabala/lively https://github.com/harshabala/Lively
brew install --cask lively
```

Upgrade later:

```bash
brew upgrade --cask lively
```

Uninstall:

```bash
brew uninstall --cask lively
```

## Why `xattr` is needed

Lively is distributed **without Apple notarization** (no paid Developer ID). When you download the zip, macOS attaches `com.apple.quarantine` to the app. Gatekeeper then blocks or warns on first launch.

```bash
xattr -dr com.apple.quarantine /Applications/Lively.app
```

- `-d` — delete the attribute  
- `-r` — apply recursively inside the app bundle  
- `com.apple.quarantine` — the download marker only; your other files are untouched  

This is a standard workaround for open-source Mac apps distributed outside the App Store.

## Publishing a new release (maintainers)

Releases are built automatically by GitHub Actions when a `v*` tag is pushed, or manually:

```bash
gh workflow run release.yml -f tag=v1.0.0
```

Local fallback (Mac with Xcode):

```bash
./scripts/release.sh v1.0.0
```

## Submitting to Homebrew core (optional, later)

This repo ships a **tap cask** (`Casks/lively.rb`) so users can `brew tap harshabala/lively` without waiting for homebrew-core review.

To propose inclusion in [homebrew-cask](https://github.com/Homebrew/homebrew-cask):

1. Ensure a stable GitHub Release with a checksum-verified zip exists
2. Fork `homebrew-cask` and add `Casks/l/lively.rb` following [Acceptable Casks](https://docs.brew.sh/Acceptable-Casks)
3. Open a PR — notarized signing is preferred but not strictly required for all casks
4. Once merged, users install with `brew install --cask lively` (no tap needed)

Until then, the tap in this repository is the supported Homebrew path.
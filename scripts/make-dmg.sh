#!/bin/bash
# Build a simple drag-to-Applications DMG for Lively (no notarization).
# Usage: ./scripts/make-dmg.sh [path-to-Lively.app]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_SRC="${1:-/private/tmp/LivelyOutput/Lively.app}"
if [[ ! -d "$APP_SRC" ]]; then
  echo "App not found at $APP_SRC — running package.sh first..."
  ./package.sh
  APP_SRC="/private/tmp/LivelyOutput/Lively.app"
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_SRC/Contents/Info.plist" 2>/dev/null || echo "1.2.0")"
STAGE="$(mktemp -d /tmp/lively-dmg-XXXXXX)"
VOL_NAME="Lively"
DMG_RW="$STAGE/rw.dmg"
OUT_DIR="${LIVELY_OUTPUT_DIR:-/private/tmp/LivelyOutput}"
OUT_DMG="${OUT_DIR}/Lively-${VERSION}-macOS.dmg"

mkdir -p "$OUT_DIR"
mkdir -p "$STAGE/content"
cp -R "$APP_SRC" "$STAGE/content/Lively.app"
ln -s /Applications "$STAGE/content/Applications"

# Optional readme for first-run Gatekeeper tips
cat > "$STAGE/content/Install Notes.txt" <<EOF
Install Lively
==============

1. Drag Lively.app onto the Applications folder alias in this window.
2. Eject this disk image.
3. Open Lively from Applications (look for the icon in the menu bar — no Dock icon).

If macOS says the app can't be opened:
  • Right-click Lively.app → Open → Open
  • Or run once:
    xattr -dr com.apple.quarantine /Applications/Lively.app

Supported videos: MP4 / MOV / M4V with H.264 or HEVC.
EOF

# Create RW DMG, convert to compressed UDZO
hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGE/content" -ov -format UDRW "$DMG_RW" >/dev/null
hdiutil convert "$DMG_RW" -format UDZO -imagekey zlib-level=9 -o "$OUT_DMG" -ov >/dev/null

rm -rf "$STAGE"
echo "✅ DMG ready: $OUT_DMG"
echo "   Open it and drag Lively → Applications."
ls -lh "$OUT_DMG"

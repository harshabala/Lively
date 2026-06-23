#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== Swift build =="
swift build

echo "== Tests =="
./test.sh

echo "== Package =="
bash package.sh

APP="/private/tmp/LivelyOutput/Lively.app"

echo "== Bundle checks =="
test -x "$APP/Contents/MacOS/Lively"
plutil -lint "$APP/Contents/Info.plist"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "Smoke verification passed: $APP"

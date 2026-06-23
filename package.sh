#!/bin/bash

set -euo pipefail

# Configuration
APP_NAME="Lively"
OUTPUT_DIR="${LIVELY_OUTPUT_DIR:-/private/tmp/LivelyOutput}"
APP_BUNDLE="${OUTPUT_DIR}/${APP_NAME}.app"
EXECUTABLE_NAME="LivelyApp"
WORKSPACE_CACHE=".build/package-cache"
BUILD_PATH="${WORKSPACE_CACHE}/swift-build"
BUILD_DIR="${BUILD_PATH}/release"

mkdir -p "${WORKSPACE_CACHE}/swiftpm" "${WORKSPACE_CACHE}/swiftpm-security" "${WORKSPACE_CACHE}/clang" "${BUILD_PATH}"

export SWIFTPM_CACHE_PATH="${PWD}/${WORKSPACE_CACHE}/swiftpm"
export SWIFTPM_CONFIG_PATH="${PWD}/${WORKSPACE_CACHE}/swiftpm-security"
export CLANG_MODULE_CACHE_PATH="${PWD}/${WORKSPACE_CACHE}/clang"
export SWIFT_BUILD_PATH="${PWD}/${BUILD_PATH}"

# Clean previous build
echo "🧹 Cleaning previous build..."
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

# Build with Swift Package Manager
echo "🔨 Building Release configuration..."
swift build -c release --build-path "${BUILD_PATH}"

EXECUTABLE_PATH="$(find "${BUILD_PATH}" -path "*/release/${EXECUTABLE_NAME}" -type f -perm +111 | head -n 1)"
if [ -z "${EXECUTABLE_PATH}" ]; then
    echo "❌ Could not find built executable ${EXECUTABLE_NAME} under ${BUILD_PATH}"
    exit 1
fi

# Create App Bundle Structure
echo "📦 Creating App Bundle structure..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy Executable
echo "📋 Copying executable..."
cp "${EXECUTABLE_PATH}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Create Info.plist
echo "📝 Creating Info.plist..."
cat > "${APP_BUNDLE}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.lively.app</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/> <!-- This hides the app from the Dock -->
</dict>
</plist>
EOF

# Code Signing (Ad-hoc)
# Required for SMAppService to work locally
echo "🔏 Signing application..."
xattr -cr "${APP_BUNDLE}" 2>/dev/null || true
codesign --force --deep --options runtime --sign - --entitlements entitlements.plist "${APP_BUNDLE}"
xattr -d com.apple.FinderInfo "${APP_BUNDLE}" 2>/dev/null || true

echo "✅ Packaging complete!"
echo "🚀 App located at: ${APP_BUNDLE}"
echo "   You can run it with: open ${APP_BUNDLE}"

#!/bin/bash

# Configuration
APP_NAME="Lively"
BUILD_DIR=".build/release"
OUTPUT_DIR="Output"
APP_BUNDLE="${OUTPUT_DIR}/${APP_NAME}.app"
EXECUTABLE_NAME="LivelyApp"

# Clean previous build
echo "🧹 Cleaning previous build..."
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

# Build with Swift Package Manager
echo "🔨 Building Release configuration..."
swift build -c release

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

# Create App Bundle Structure
echo "📦 Creating App Bundle structure..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy Executable
echo "📋 Copying executable..."
cp "${BUILD_DIR}/${EXECUTABLE_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

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
codesign --force --deep --options runtime --sign - --entitlements entitlements.plist "${APP_BUNDLE}"

echo "✅ Packaging complete!"
echo "🚀 App located at: ${APP_BUNDLE}"
echo "   You can run it with: open ${APP_BUNDLE}"

#!/bin/bash
# Run the Swift Testing suite.
#
# Command Line Tools ships Testing.framework in a non-standard path that
# `swift test` cannot discover on its own.  This script adds the required
# framework-search and rpath flags so tests work without a full Xcode install.

set -euo pipefail

CLT_FRAMEWORKS="/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
CLT_DEVLIB="/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
WORKSPACE_CACHE=".build/test-cache"

mkdir -p "$WORKSPACE_CACHE"/swiftpm "$WORKSPACE_CACHE"/swiftpm-security "$WORKSPACE_CACHE"/clang "$WORKSPACE_CACHE"/swift-build

export SWIFTPM_CACHE_PATH="$PWD/$WORKSPACE_CACHE/swiftpm"
export SWIFTPM_CONFIG_PATH="$PWD/$WORKSPACE_CACHE/swiftpm-security"
export CLANG_MODULE_CACHE_PATH="$PWD/$WORKSPACE_CACHE/clang"
export SWIFT_BUILD_PATH="$PWD/$WORKSPACE_CACHE/swift-build"

exec swift test \
  --build-path "$PWD/$WORKSPACE_CACHE/swift-build" \
  -Xswiftc -F -Xswiftc "$CLT_FRAMEWORKS" \
  -Xlinker -F -Xlinker "$CLT_FRAMEWORKS" \
  -Xlinker -framework -Xlinker Testing \
  -Xlinker -rpath -Xlinker "$CLT_FRAMEWORKS" \
  -Xlinker -rpath -Xlinker "$CLT_DEVLIB" \
  "$@"

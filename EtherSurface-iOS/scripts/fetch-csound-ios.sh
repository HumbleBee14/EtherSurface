#!/usr/bin/env bash
# fetch-csound-ios.sh — download or build the Csound iOS framework
#
# The Csound for iOS xcframework is not distributed via SPM. You must
# either:
#   1. Build it from source (recommended — ensures arm64 + simulator),
#   2. Copy it from an existing Csound iOS Examples project.
#
# This script automates option 1.
#
# Prerequisites:
#   - Xcode 15+ with command-line tools
#   - CMake 3.20+ (brew install cmake)
#   - git
#
# Usage:
#   cd EtherSurface-iOS
#   bash scripts/fetch-csound-ios.sh
#
# Output:
#   Frameworks/CsoundLib.xcframework/  — the universal xcframework
#   Headers/                            — CsoundObj.h + related headers

set -euo pipefail

CSOUND_TAG="7.0.0-beta.16"       # latest as of May 2026
CSOUND_REPO="https://github.com/csound/csound.git"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/csound-ios"
FRAMEWORK_DIR="$PROJECT_DIR/Frameworks"
HEADER_DIR="$PROJECT_DIR/Headers"

echo "=== Fetching Csound $CSOUND_TAG for iOS ==="

# Clone if needed
if [ ! -d "$BUILD_DIR/csound" ]; then
    echo "Cloning csound..."
    mkdir -p "$BUILD_DIR"
    git clone --depth 1 --branch "$CSOUND_TAG" "$CSOUND_REPO" "$BUILD_DIR/csound" 2>/dev/null || \
    git clone --depth 1 "$CSOUND_REPO" "$BUILD_DIR/csound"
fi

cd "$BUILD_DIR/csound"

# Check if the iOS build script exists
if [ -f "iOS/build.sh" ]; then
    echo "Running official iOS build script..."
    cd iOS
    bash build.sh

    # Copy xcframework
    mkdir -p "$FRAMEWORK_DIR"
    if [ -d "build/CsoundLib.xcframework" ]; then
        cp -R build/CsoundLib.xcframework "$FRAMEWORK_DIR/"
        echo "Copied CsoundLib.xcframework to $FRAMEWORK_DIR"
    elif [ -d "build/Release-iphoneos" ]; then
        echo "xcframework not found; individual .framework may need manual assembly"
        echo "Check $BUILD_DIR/csound/iOS/build/ for output"
    fi

    # Copy headers (CsoundObj + friends)
    mkdir -p "$HEADER_DIR"
    CSOUND_IOS_SRC="$BUILD_DIR/csound/iOS/Csound-for-iOS/src"
    if [ -d "$CSOUND_IOS_SRC" ]; then
        cp -R "$CSOUND_IOS_SRC"/*.h "$HEADER_DIR/" 2>/dev/null || true
        cp -R "$CSOUND_IOS_SRC"/*.hpp "$HEADER_DIR/" 2>/dev/null || true
    fi

    # Also copy CsoundObj from the examples if present
    for f in $(find "$BUILD_DIR/csound/iOS" -name "CsoundObj.h" -o -name "CsoundObj.m" 2>/dev/null); do
        cp "$f" "$HEADER_DIR/"
    done

    echo ""
    echo "=== Done ==="
    echo "Framework: $FRAMEWORK_DIR/CsoundLib.xcframework"
    echo "Headers:   $HEADER_DIR/"
    echo ""
    echo "In Xcode:"
    echo "  1. Drag CsoundLib.xcframework into your project"
    echo "  2. Add \$PROJECT_DIR/Headers to Header Search Paths"
    echo "  3. The bridging header already imports CsoundObj.h"
else
    echo "ERROR: iOS/build.sh not found in the Csound repo."
    echo "You may need to build manually. See:"
    echo "  https://github.com/csound/csound/tree/develop/iOS"
    exit 1
fi

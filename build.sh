#!/bin/bash
# ──────────────────────────────────────────────
# build.sh — Builds FnKeyboard.app and optional DMG
# Usage:  ./build.sh          (build only)
#         ./build.sh --dmg    (build + create DMG)
# ──────────────────────────────────────────────
set -euo pipefail

APP_NAME="FnKeyboard"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

echo "🔨  Building $APP_NAME …"

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Generate icon if missing
if [ ! -f AppIcon.icns ]; then
    echo "🎨  Generating app icon …"
    swift generate_icon.swift AppIcon.icns
fi

# Resolve macOS SDK
SDK_PATH=$(xcrun --show-sdk-path)
ARCH=$(uname -m)                        # arm64 or x86_64

# Compile Swift sources
swiftc -parse-as-library \
    -sdk "$SDK_PATH" \
    -target "${ARCH}-apple-macos13.0" \
    -O \
    Sources/*.swift \
    -o "$MACOS_DIR/$APP_NAME"

# Copy resources into the bundle
cp Info.plist "$CONTENTS/"
cp AppIcon.icns "$RESOURCES_DIR/"

# Touch bundle to flush macOS icon cache
touch "$APP_BUNDLE"

echo "✅  Built successfully → $APP_BUNDLE"

# ── Optional DMG creation ──
if [[ "${1:-}" == "--dmg" ]]; then
    DMG_NAME="${APP_NAME}.dmg"
    DMG_PATH="$BUILD_DIR/$DMG_NAME"
    DMG_TEMP="$BUILD_DIR/dmg_staging"

    echo "📦  Creating DMG …"
    rm -rf "$DMG_TEMP" "$DMG_PATH"
    mkdir -p "$DMG_TEMP"

    # Copy app into staging
    cp -R "$APP_BUNDLE" "$DMG_TEMP/"

    # Create symlink to /Applications for drag-and-drop install
    ln -s /Applications "$DMG_TEMP/Applications"

    # Create the DMG
    hdiutil create \
        -volname "$APP_NAME" \
        -srcfolder "$DMG_TEMP" \
        -ov -format UDZO \
        "$DMG_PATH" \
        > /dev/null

    rm -rf "$DMG_TEMP"
    echo "✅  DMG created → $DMG_PATH"
    echo "   Share this file to install on another Mac."
fi

echo "▶   Run with:  open $APP_BUNDLE"

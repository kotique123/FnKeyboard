#!/bin/bash
# ──────────────────────────────────────────────
# build.sh — Builds FnKeyboard.app and optional DMG
# Usage:  ./build.sh                (build for current arch)
#         ./build.sh --dmg          (build + create DMG for current arch)
#         ./build.sh --release      (build + DMG for both arm64 and x86_64)
# ──────────────────────────────────────────────
set -euo pipefail

APP_NAME="FnKeyboard"
BUILD_DIR="build"
ENTITLEMENTS="FnKeyboard.entitlements"

# ── Helper Functions ──

generate_icon_if_needed() {
    if [ ! -f AppIcon.icns ]; then
        echo "🎨  Generating app icon …"
        # Verify generate_icon.swift integrity before execution (supply-chain protection).
        # Uses SHA-256 hash of the committed version to prevent TOCTOU attacks.
        if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null; then
            COMMITTED_HASH=$(git show HEAD:generate_icon.swift 2>/dev/null | shasum -a 256 | awk '{print $1}')
            CURRENT_HASH=$(shasum -a 256 generate_icon.swift | awk '{print $1}')
            if [ "$COMMITTED_HASH" != "$CURRENT_HASH" ]; then
                echo "⚠️  generate_icon.swift hash mismatch — file differs from committed version."
                echo "   Committed: $COMMITTED_HASH"
                echo "   Current:   $CURRENT_HASH"
                exit 1
            fi
        fi
        swift generate_icon.swift AppIcon.icns
    fi
}

# Build a single .app bundle for the given architecture.
# Usage: build_app <arch>   (arch = arm64 | x86_64)
# Outputs to: build/<arch>/FnKeyboard.app
build_app() {
    local arch="$1"
    local app_bundle="$BUILD_DIR/$arch/$APP_NAME.app"
    local contents="$app_bundle/Contents"
    local macos_dir="$contents/MacOS"
    local resources_dir="$contents/Resources"

    echo "🔨  Building $APP_NAME ($arch) …"
    rm -rf "$BUILD_DIR/$arch"
    mkdir -p "$macos_dir" "$resources_dir"

    local sdk_path
    sdk_path=$(xcrun --show-sdk-path)

    swiftc -parse-as-library \
        -sdk "$sdk_path" \
        -target "${arch}-apple-macos13.0" \
        -O \
        Sources/*.swift \
        -o "$macos_dir/$APP_NAME"

    cp Info.plist "$contents/"
    cp AppIcon.icns "$resources_dir/"

    # Code sign with hardened runtime
    echo "🔏  Signing ($arch) with hardened runtime …"
    if [ -n "${CODESIGN_IDENTITY:-}" ]; then
        codesign --force --options runtime \
            --timestamp \
            --entitlements "$ENTITLEMENTS" \
            --sign "$CODESIGN_IDENTITY" \
            "$app_bundle"
        echo "   Signed with identity: $CODESIGN_IDENTITY"
    else
        echo "⚠️  No CODESIGN_IDENTITY set — using ad-hoc signature (NOT suitable for distribution)."
        codesign --force --options runtime \
            --entitlements "$ENTITLEMENTS" \
            --sign - \
            "$app_bundle"
    fi

    touch "$app_bundle"
    echo "✅  Built successfully → $app_bundle"
}

# Create a DMG from an .app bundle.
# Usage: create_dmg <app_bundle_path> <dmg_output_path>
create_dmg() {
    local app_bundle="$1"
    local dmg_path="$2"
    local dmg_temp="$BUILD_DIR/dmg_staging_$$"

    echo "📦  Creating DMG → $dmg_path …"
    rm -rf "$dmg_temp" "$dmg_path"
    mkdir -p "$dmg_temp"

    cp -R "$app_bundle" "$dmg_temp/"
    ln -s /Applications "$dmg_temp/Applications"

    hdiutil create \
        -volname "$APP_NAME" \
        -srcfolder "$dmg_temp" \
        -ov -format UDZO \
        "$dmg_path" \
        > /dev/null

    rm -rf "$dmg_temp"
    echo "✅  DMG created → $dmg_path"
}

# ── Main ──

generate_icon_if_needed

if [[ "${1:-}" == "--release" ]]; then
    # ── Release mode: build both architectures + DMG for each ──
    RELEASE_DIR="release"
    rm -rf "$RELEASE_DIR"
    mkdir -p "$RELEASE_DIR"

    for arch in arm64 x86_64; do
        build_app "$arch"
        dmg_name="${APP_NAME}-macos-${arch}.dmg"
        create_dmg "$BUILD_DIR/$arch/$APP_NAME.app" "$RELEASE_DIR/$dmg_name"
    done

    echo ""
    echo "🎉  Release DMGs:"
    echo "   $RELEASE_DIR/${APP_NAME}-macos-arm64.dmg   (Apple Silicon)"
    echo "   $RELEASE_DIR/${APP_NAME}-macos-x86_64.dmg  (Intel)"

elif [[ "${1:-}" == "--dmg" ]]; then
    # ── Single-arch build + DMG ──
    ARCH=$(uname -m)
    build_app "$ARCH"
    create_dmg "$BUILD_DIR/$ARCH/$APP_NAME.app" "$BUILD_DIR/${APP_NAME}.dmg"
    echo "▶   Run with:  open $BUILD_DIR/$ARCH/$APP_NAME.app"

else
    # ── Default: single-arch build only ──
    ARCH=$(uname -m)
    build_app "$ARCH"
    echo "▶   Run with:  open $BUILD_DIR/$ARCH/$APP_NAME.app"
fi

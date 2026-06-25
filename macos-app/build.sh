#!/bin/bash
# Build ClaudeUsage.app as a universal (Intel + Apple Silicon) macOS app,
# bundling the Python data script inside Contents/Resources.
#
# Usage:
#   ./build.sh           # build ClaudeUsage.app
#   ./build.sh --dmg     # build the app and a distributable DMG
set -euo pipefail

cd "$(dirname "$0")"
APP="ClaudeUsage.app"
BUILD="build"
SCRIPT="../claude-usage.5m.py"

echo "==> Cleaning"
rm -rf "$BUILD" "$APP" ClaudeUsage-*.dmg
mkdir -p "$BUILD"

echo "==> Compiling arm64 slice"
swiftc -parse-as-library -O -target arm64-apple-macosx11.0 \
    -o "$BUILD/ClaudeUsage-arm64" ClaudeUsage.swift \
    -framework Cocoa -framework QuartzCore

echo "==> Compiling x86_64 slice"
if swiftc -parse-as-library -O -target x86_64-apple-macosx11.0 \
    -o "$BUILD/ClaudeUsage-x86_64" ClaudeUsage.swift \
    -framework Cocoa -framework QuartzCore 2>/dev/null; then
    echo "==> Creating universal binary"
    lipo -create -output "$BUILD/ClaudeUsage" \
        "$BUILD/ClaudeUsage-arm64" "$BUILD/ClaudeUsage-x86_64"
else
    echo "    x86_64 SDK slice unavailable — shipping arm64 only"
    cp "$BUILD/ClaudeUsage-arm64" "$BUILD/ClaudeUsage"
fi

echo "==> Assembling $APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
cp "$BUILD/ClaudeUsage" "$APP/Contents/MacOS/ClaudeUsage"
chmod +x "$APP/Contents/MacOS/ClaudeUsage"
cp "$SCRIPT" "$APP/Contents/Resources/claude-usage.5m.py"

echo "==> Ad-hoc signing"
codesign --force --deep --sign - "$APP" 2>/dev/null || echo "    (codesign skipped)"

echo "==> Architectures: $(lipo -archs "$APP/Contents/MacOS/ClaudeUsage" 2>/dev/null || echo unknown)"
echo "==> Built $APP"

if [[ "${1:-}" == "--dmg" ]]; then
    VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
    DMG="ClaudeUsage-${VERSION}.dmg"
    echo "==> Building $DMG"
    STAGING=$(mktemp -d)
    cp -R "$APP" "$STAGING/"
    ln -s /Applications "$STAGING/Applications"
    hdiutil create -volname "Claude Usage" -srcfolder "$STAGING" \
        -ov -format UDZO "$DMG" >/dev/null
    rm -rf "$STAGING"
    echo "==> Built $DMG"
fi

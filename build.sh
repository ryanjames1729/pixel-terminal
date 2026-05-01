#!/bin/bash
set -e

APP_NAME="Pixel Terminal"
BINARY_NAME="PixelTerminal"
BUNDLE_ID="com.pixelandpines.pixel-terminal"
CONFIG="${1:-release}"

echo "▶ Building $APP_NAME ($CONFIG)..."
swift build -c "$CONFIG" 2>&1

BINARY=".build/$CONFIG/$BINARY_NAME"

if [ ! -f "$BINARY" ]; then
    echo "✗ Build failed — binary not found at $BINARY"
    exit 1
fi

APP_DIR="dist/${APP_NAME}.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

echo "▶ Packaging $APP_DIR..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES_DIR"

cp "$BINARY" "$MACOS/$BINARY_NAME"
cp "Resources/Info.plist" "$CONTENTS/Info.plist"
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Mark as executable
chmod +x "$MACOS/$BINARY_NAME"

echo ""
echo "✓ Built:  $APP_DIR"
echo ""
echo "To run:   open 'dist/Pixel Terminal.app'"
echo "To install: cp -r 'dist/Pixel Terminal.app' /Applications/"
echo ""
echo "To build a DMG for distribution:"
echo "  hdiutil create -volname 'Pixel Terminal' -srcfolder dist/ -ov -format UDZO dist/PixelTerminal.dmg"

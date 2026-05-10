#!/bin/bash
# Usage: ./release.sh <version> [npm-version]
# Example: ./release.sh 0.4.0
#   npm-version defaults to <version> and only needs to differ
#   if that npm version is already published (e.g. 0.4.1)
set -e

VERSION="${1:?Usage: ./release.sh <version> [npm-version]}"
NPM_VERSION="${2:-$VERSION}"

APP_FILES=(
  "Resources/Info.plist"
  "Sources/PixelTerminal/Views/TerminalAreaView.swift"
  "Sources/PixelTerminal/Services/CredentialStore.swift"
  "npm-installer/bin/pixel-terminal.js"
  "npm-installer/package.json"
)

# ── Validate ──────────────────────────────────────────────────────────────────

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "✗ Version must be semver (e.g. 1.2.3)"; exit 1
fi

if git tag | grep -q "^v${VERSION}$"; then
  echo "✗ Tag v${VERSION} already exists"; exit 1
fi

echo ""
echo "  ▸ pixel-terminal  releasing v${VERSION}  (npm ${NPM_VERSION})"
echo "  ──────────────────────────────────────────────────"
echo ""

# ── Bump all version strings ──────────────────────────────────────────────────

OLD_APP=$(grep -m1 'CFBundleShortVersionString' Resources/Info.plist -A1 | grep '<string>' | sed 's/.*<string>\(.*\)<\/string>/\1/')

echo "  → Updating version strings: ${OLD_APP} → ${VERSION}"

# Info.plist (two occurrences: CFBundleVersion + CFBundleShortVersionString)
sed -i '' "s/<string>${OLD_APP}<\/string>/<string>${VERSION}<\/string>/g" Resources/Info.plist

# Swift source — TERM_PROGRAM_VERSION env var
sed -i '' "s/TERM_PROGRAM_VERSION\"] = \"[^\"]*\"/TERM_PROGRAM_VERSION\"] = \"${VERSION}\"/" \
  Sources/PixelTerminal/Views/TerminalAreaView.swift

# Swift source — terminal banner greeting
sed -i '' "s/pixel-terminal\\\\033\[0m \\\\033\[38;2;74;85;104mv[0-9.]*\\\\033/pixel-terminal\\\\033[0m \\\\033[38;2;74;85;104mv${VERSION}\\\\033/" \
  Sources/PixelTerminal/Views/TerminalAreaView.swift

# Swift source — User-Agent header
sed -i '' "s/PixelTerminal\/[0-9.]*/PixelTerminal\/${VERSION}/" \
  Sources/PixelTerminal/Services/CredentialStore.swift

# npm installer VERSION constant
sed -i '' "s/const VERSION  = '[^']*'/const VERSION  = '${VERSION}'/" \
  npm-installer/bin/pixel-terminal.js

# npm package.json version
sed -i '' "s/\"version\": \"[^\"]*\"/\"version\": \"${NPM_VERSION}\"/" \
  npm-installer/package.json

echo "  ✓ Version strings updated"

# ── Build ─────────────────────────────────────────────────────────────────────

echo "  → Building app..."
bash build.sh release

# ── DMG ───────────────────────────────────────────────────────────────────────

echo "  → Creating DMG..."
hdiutil create -volname 'Pixel Terminal' -srcfolder dist/ -ov -format UDZO dist/PixelTerminal.dmg -quiet
echo "  ✓ dist/PixelTerminal.dmg ready"

# ── Install locally ───────────────────────────────────────────────────────────

DEST="/Applications/Pixel Terminal.app"
echo "  → Installing to ${DEST}..."
rm -rf "$DEST"
cp -r "dist/Pixel Terminal.app" /Applications/
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
echo "  ✓ Installed"

# ── Commit + tag + push ───────────────────────────────────────────────────────

echo "  → Committing and tagging v${VERSION}..."
git add "${APP_FILES[@]}"
git commit -m "Release v${VERSION}"
git tag "v${VERSION}"
git push origin main
git push origin "v${VERSION}"
echo "  ✓ Pushed"

# ── GitHub release ────────────────────────────────────────────────────────────

echo "  → Creating GitHub release v${VERSION}..."
gh release create "v${VERSION}" dist/PixelTerminal.dmg \
  --title "v${VERSION}" \
  --generate-notes \
  --latest
echo "  ✓ GitHub release created"

# ── npm publish ───────────────────────────────────────────────────────────────

echo ""
echo "  ──────────────────────────────────────────────────"
echo "  ✓ Done! One step left — publish npm ${NPM_VERSION}:"
echo ""
echo "    cd npm-installer && npm publish"
echo ""

#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# build-app.sh
#
# Builds the Swift executable, assembles a NepaliCalendar.app bundle, embeds
# Info.plist and an icon, code-signs ad-hoc, then zips the result for release.
#
# Required on build machine: Xcode command line tools (swift, codesign, iconutil).
#
# Output:
#   build/NepaliCalendar.app         — runnable bundle
#   build/NepaliCalendar.zip         — zipped bundle, upload this to a GitHub Release
#   build/NepaliCalendar.zip.sha256  — sha256 to paste into the Homebrew cask
# -----------------------------------------------------------------------------
set -euo pipefail

APP_NAME="NepaliCalendar"
APP_BUNDLE_ID="com.saurav.nepalicalendar"
APP_VERSION="${APP_VERSION:-0.1.0}"
APP_DISPLAY_NAME="Nepali Calendar"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG_DIR="$ROOT/NepaliCalendar"
BUILD_DIR="$ROOT/build"
APP_DIR="$BUILD_DIR/${APP_NAME}.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RES_DIR="$CONTENTS/Resources"

echo "==> Cleaning build directory"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Building Swift executable (release, arm64 + x86_64 universal)"
cd "$PKG_DIR"

# Single invocation: SwiftPM resolves/builds once and reports the bin path.
swift build -c release --arch arm64 --arch x86_64
BIN_PATH=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)

echo "==> Assembling .app bundle at $APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"

cp "$BIN_PATH/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# SwiftPM emits resources as a .bundle next to the binary. The exact name
# varies with Swift version ("PackageName_TargetName.bundle"), so glob it.
shopt -s nullglob
for b in "$BIN_PATH"/*.bundle; do
  cp -R "$b" "$RES_DIR/"
done
shopt -u nullglob

echo "==> Writing Info.plist"
cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>${APP_BUNDLE_ID}</string>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_DISPLAY_NAME}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${APP_VERSION}</string>
  <key>CFBundleVersion</key><string>${APP_VERSION}</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
  <key>CFBundleIconFile</key><string>AppIcon</string>
</dict>
</plist>
PLIST

# Optional icon — if the user drops an AppIcon.icns into Resources/ before
# building, we include it. Otherwise the bundle ships iconless (fine for a
# menu-bar-only app).
if [ -f "$ROOT/assets/AppIcon.icns" ]; then
  cp "$ROOT/assets/AppIcon.icns" "$RES_DIR/AppIcon.icns"
fi

echo "==> Code signing (ad-hoc)"
xattr -cr "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR"

echo "==> Zipping bundle for distribution"
cd "$BUILD_DIR"
ditto -c -k --sequesterRsrc --keepParent "${APP_NAME}.app" "${APP_NAME}.zip"

SHA256=$(shasum -a 256 "${APP_NAME}.zip" | awk '{print $1}')
echo "$SHA256" > "${APP_NAME}.zip.sha256"

echo ""
echo "Build complete."
echo "  App bundle : $APP_DIR"
echo "  Zip        : $BUILD_DIR/${APP_NAME}.zip"
echo "  SHA256     : $SHA256"
echo ""
echo "Paste this SHA256 into homebrew-tap/Casks/nepali-calendar.rb alongside"
echo "the GitHub Release URL to publish a new version."

#!/usr/bin/env bash
# Assembles build/ComBeGone.app (and a shareable zip) from the Swift code and vendor/bin tools.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION="${VERSION:-1.0.1}"
APP="build/ComBeGone.app"

for t in ffmpeg ffprobe comskip; do
  [[ -x "vendor/bin/$t" ]] || { echo "vendor/bin/$t missing — run scripts/build-deps.sh first" >&2; exit 1; }
done

swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)/combegone"

rm -rf "$APP" build/combegone.app
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/bin" "$APP/Contents/Resources/Licenses"
cp "$BIN" "$APP/Contents/MacOS/combegone"
cp vendor/bin/ffmpeg vendor/bin/ffprobe vendor/bin/comskip "$APP/Contents/Resources/bin/"
cp Resources/comskip.ini "$APP/Contents/Resources/"
cp Resources/Licenses/*.txt "$APP/Contents/Resources/Licenses/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>ComBeGone</string>
  <key>CFBundleDisplayName</key><string>ComBeGone</string>
  <key>CFBundleIdentifier</key><string>io.github.combegone</string>
  <key>CFBundleExecutable</key><string>combegone</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSArchitecturePriority</key><array><string>arm64</string></array>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key><string>Video Recording</string>
      <key>CFBundleTypeRole</key><string>Viewer</string>
      <key>LSHandlerRank</key><string>Alternate</string>
      <key>LSItemContentTypes</key>
      <array><string>public.movie</string><string>public.mpeg-2-transport-stream</string></array>
    </dict>
  </array>
  <key>NSHumanReadableCopyright</key><string>Free software under the GNU GPL v2 or later.</string>
</dict>
</plist>
PLIST

# Ad-hoc signature (no paid Apple developer account). Sign the tools, then the app.
codesign --force --options runtime -s - "$APP"/Contents/Resources/bin/*
codesign --force --options runtime -s - "$APP"
codesign --verify --deep --strict "$APP"

rm -f build/combegone.zip build/ComBeGone.zip
ditto -c -k --keepParent "$APP" build/ComBeGone.zip
echo "==> $APP"
echo "==> build/ComBeGone.zip (share this)"

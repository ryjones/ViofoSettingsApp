#!/bin/bash
# Builds ViofoConfig.app so the tool launches like a normal Mac app
# (a bare SwiftPM binary has no bundle and behaves like a background process).
set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-release}"
swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/ViofoConfig"

APP="ViofoConfig.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ViofoConfig"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>                  <string>VIOFO Settings</string>
    <key>CFBundleDisplayName</key>           <string>VIOFO Settings</string>
    <key>CFBundleIdentifier</key>            <string>org.walledcity.viofoconfig</string>
    <key>CFBundleExecutable</key>            <string>ViofoConfig</string>
    <key>CFBundlePackageType</key>           <string>APPL</string>
    <key>CFBundleShortVersionString</key>    <string>1.0</string>
    <key>CFBundleVersion</key>               <string>1</string>
    <key>LSMinimumSystemVersion</key>        <string>14.0</string>
    <key>NSHighResolutionCapable</key>       <true/>
    <key>NSHumanReadableCopyright</key>      <string>Explanations quoted from the VIOFO A329S manual V26.01.09.</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>      <string>VIOFO configuration</string>
            <key>CFBundleTypeRole</key>      <string>Editor</string>
            <key>LSItemContentTypes</key>
            <array><string>public.plain-text</string></array>
        </dict>
    </array>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" 2>/dev/null || true
echo "Built $(pwd)/$APP"

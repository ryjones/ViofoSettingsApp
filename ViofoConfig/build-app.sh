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

# SwiftPM puts anything declared in `resources:` into its own bundle beside the
# binary, and `Bundle.module` looks for it next to the executable or in
# Contents/Resources. Copying only the binary leaves `Bundle.module` with
# nothing to find, and it does not return nil -- it traps. The app then dies the
# moment it touches camera-commands.json, which is on the path that opens the
# Camera window.
BUNDLE_DIR="$(dirname "$BIN")"
shopt -s nullglob
bundles=("$BUNDLE_DIR"/*.bundle)
shopt -u nullglob
for b in "${bundles[@]}"; do
    case "$(basename "$b")" in
        *Tests.bundle) continue ;;          # test fixtures do not ship
    esac
    cp -R "$b" "$APP/Contents/Resources/"
done
if [ ! -d "$APP/Contents/Resources/ViofoConfig_ViofoConfig.bundle" ]; then
    echo "error: resource bundle missing from $BUNDLE_DIR; the app would crash on launch" >&2
    exit 1
fi

# The icon is drawn by tools/make-icon.swift rather than checked in, so the
# repository carries the source of the artwork and not a megabyte of binary.
if [ ! -f AppIcon.icns ]; then
    ../tools/make-icon.sh
fi
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>                  <string>VIOFO Settings</string>
    <key>CFBundleDisplayName</key>           <string>VIOFO Settings</string>
    <key>CFBundleIdentifier</key>            <string>org.walledcity.viofoconfig</string>
    <key>CFBundleExecutable</key>            <string>ViofoConfig</string>
    <key>CFBundleIconFile</key>              <string>AppIcon</string>
    <key>CFBundlePackageType</key>           <string>APPL</string>
    <key>CFBundleShortVersionString</key>    <string>1.0</string>
    <key>CFBundleVersion</key>               <string>1</string>
    <key>LSMinimumSystemVersion</key>        <string>14.0</string>
    <key>NSHighResolutionCapable</key>       <true/>
    <key>NSHumanReadableCopyright</key>      <string>Explanations quoted from the VIOFO A329S manual V26.01.09.</string>

    <!-- Reading settings off the camera means talking to its Wi-Fi access point
         at http://192.168.1.254, which is plain HTTP on the local network.
         macOS needs both of these before that will work; see
         docs/camera-http-api.md. -->
    <key>NSLocalNetworkUsageDescription</key>
    <string>VIOFO Settings connects to your dash cam's Wi-Fi to read its current configuration.</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSExceptionDomains</key>
        <dict>
            <key>192.168.1.254</key>
            <dict>
                <key>NSExceptionAllowsInsecureHTTPLoads</key> <true/>
                <key>NSIncludesSubdomains</key>               <false/>
            </dict>
        </dict>
    </dict>
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

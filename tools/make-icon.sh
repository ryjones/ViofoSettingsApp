#!/bin/bash
# Renders AppIcon.icns from tools/make-icon.swift.
#
# Each size is drawn at its own resolution rather than downscaled from one
# master: the V's stroke and the sparkles are proportional, so drawing small
# keeps them crisp instead of muddy.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=tools/make-icon.swift
OUT=ViofoConfig/AppIcon.icns
SET=$(mktemp -d)/AppIcon.iconset
mkdir -p "$SET"

render() { swift "$SRC" --png "$SET/$2" "$1"; }

render 16   icon_16x16.png
render 32   icon_16x16@2x.png
render 32   icon_32x32.png
render 64   icon_32x32@2x.png
render 128  icon_128x128.png
render 256  icon_128x128@2x.png
render 256  icon_256x256.png
render 512  icon_256x256@2x.png
render 512  icon_512x512.png
render 1024 icon_512x512@2x.png

iconutil -c icns "$SET" -o "$OUT"

# The vector layers are the real source. Icon Composer (Xcode 26+) turns these
# into a .icon bundle; this machine has only the command line tools, whose
# iconutil still speaks icns/iconset only, so the bundle ships .icns for now.
swift "$SRC" --svg tools/icon
rm -rf "$(dirname "$SET")"
echo "wrote $OUT"

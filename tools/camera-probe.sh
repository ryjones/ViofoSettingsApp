#!/bin/bash
# Read the camera's live configuration over its Wi-Fi access point.
#
#   tools/camera-probe.sh [outdir]
#
# Read-only by default. Pass --export to also ask the camera to write
# viofo_config.ini to its own memory card (cmd 9352), which is the other half
# of the mapping described in docs/camera-http-api.md.
#
# Nothing here changes a setting. Commands known to be destructive are refused
# outright, see DENY below.
set -uo pipefail

CAM="${CAM:-http://192.168.1.254}"
OUT="${1:-camera-dump-$(date +%Y%m%d-%H%M%S)}"
EXPORT=0
for a in "$@"; do [ "$a" = "--export" ] && EXPORT=1; done

# Never send these, whatever else changes in this script.
DENY="3010 3011 9317"

send() {   # send <cmd> [extra query]
    local cmd="$1" extra="${2:-}"
    for d in $DENY; do
        [ "$cmd" = "$d" ] && { echo "refusing destructive cmd $cmd" >&2; return 1; }
    done
    curl -s -m 10 "$CAM/?custom=1&cmd=$cmd$extra"
}

mkdir -p "$OUT"

echo ">> checking $CAM"
if ! curl -s -m 3 -o /dev/null "$CAM/?custom=1&cmd=3012"; then
    cat >&2 <<'MSG'
No answer from the camera.

  1. Turn the camera's Wi-Fi on (System Settings -> Wi-Fi).
  2. Join its access point from this Mac. You will lose internet while joined:
     the camera's AP has no uplink.
  3. Re-run this script.
MSG
    exit 1
fi

echo ">> firmware version (cmd 3012)"
send 3012 | tee "$OUT/3012-version.xml"

echo ">> entering settings mode (cmd 9222)"
send 9222 > "$OUT/9222-enter.xml"

echo ">> reading every setting (cmd 3014)"
send 3014 > "$OUT/3014-settings.xml"
wc -c < "$OUT/3014-settings.xml" | xargs echo "   bytes:"

if [ "$EXPORT" -eq 1 ]; then
    echo ">> asking the camera to export viofo_config.ini (cmd 9352)"
    send 9352 > "$OUT/9352-export.xml"
    echo "   now copy Config/viofo_config.ini off the card, or try the file API"
fi

echo ">> leaving settings mode (cmd 9223)"
send 9223 > "$OUT/9223-exit.xml"

echo
echo "wrote $OUT/"
echo "next: tools/build-mapping.py $OUT/3014-settings.xml <viofo_config.ini>"

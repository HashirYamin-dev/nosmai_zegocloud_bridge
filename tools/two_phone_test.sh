#!/usr/bin/env bash
# Two-phone live test over adb: host on one phone, viewer on the other.
#
#   tools/two_phone_test.sh HOST_SERIAL VIEWER_SERIAL [APK]
#
# Installs APK (if given), starts a live on HOST, watches it on VIEWER, takes screenshots,
# stops the live and checks that the viewer reports the end. Buttons are found by their text,
# so it works on any screen size. Don't touch the phones while it runs.
set -euo pipefail

HOST=${1:?host serial (adb devices)}
VIEWER=${2:?viewer serial}
APK=${3:-}
PKG=com.nosmai.effect
ADB=${ADB:-$(command -v adb || echo "$HOME/Library/Android/sdk/platform-tools/adb")}
OUT=${OUT:-build/two_phone_test}
mkdir -p "$OUT"

adb_() { "$ADB" -s "$1" "${@:2}"; }

# Prints "x y" of the centre of the first node whose text or content-desc equals $2.
find_node() {
  adb_ "$1" shell uiautomator dump /sdcard/nzl_ui.xml >/dev/null 2>&1 || return 1
  adb_ "$1" shell cat /sdcard/nzl_ui.xml | sed 's/></>\n</g' |
    grep -F -e "text=\"$2\"" -e "content-desc=\"$2\"" | head -1 |
    sed -E 's/.*bounds="\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]".*/\1 \2 \3 \4/' |
    awk 'NF==4 { print int(($1+$3)/2), int(($2+$4)/2) }'
}

# Waits up to $3 seconds for the node, then taps it unless $4 is "nowait-tap".
wait_for() {
  local serial=$1 label=$2 timeout=${3:-20} tap=${4:-tap} xy
  for _ in $(seq "$timeout"); do
    xy=$(find_node "$serial" "$label" || true)
    if [ -n "$xy" ]; then
      [ "$tap" = tap ] && adb_ "$serial" shell input tap $xy
      echo "  ✓ $serial: $label"
      return 0
    fi
    sleep 1
  done
  echo "  ✗ $serial: '$label' not seen in ${timeout}s"
  adb_ "$serial" exec-out screencap -p > "$OUT/fail_${serial}.png"
  return 1
}

logs() { adb_ "$1" logcat -d -s 'NosmaiZegoLive:*' 'NosmaiZegoSource:*' 'AndroidRuntime:E' | grep -v beginning || true; }

for s in "$HOST" "$VIEWER"; do
  if [ -n "$APK" ]; then echo "Installing on $s"; adb_ "$s" install -r -d "$APK" | tail -1; fi
  adb_ "$s" shell am force-stop $PKG
  adb_ "$s" logcat -c
done
sleep 3 # Let the camera service release the camera of the stopped process.
for s in "$HOST" "$VIEWER"; do
  adb_ "$s" shell input keyevent KEYCODE_WAKEUP
  adb_ "$s" shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
done

echo "1. Host goes live"
wait_for "$HOST" 'Host (Nosmai filters → ZEGOCLOUD)'
if ! wait_for "$HOST" 'Preview ready' 20 nowait-tap; then
  wait_for "$HOST" 'Retry' 2   # Camera still busy: Nosmai's retry button.
  wait_for "$HOST" 'Preview ready' 20 nowait-tap
fi
wait_for "$HOST" 'Start Live' 5
wait_for "$HOST" 'LIVE' 30 nowait-tap

echo "2. Viewer watches"
wait_for "$VIEWER" 'Viewer'
wait_for "$VIEWER" 'live' 30 nowait-tap
sleep 8
adb_ "$HOST" exec-out screencap -p > "$OUT/host_live.png"
adb_ "$VIEWER" exec-out screencap -p > "$OUT/viewer_live.png"

echo "3. Host stops; viewer must see the end"
wait_for "$HOST" 'Stop Live' 5
wait_for "$VIEWER" 'The broadcaster ended the live' 15 nowait-tap
adb_ "$VIEWER" exec-out screencap -p > "$OUT/viewer_ended.png"

echo "4. Host goes live again (Stop/Start repeat)"
wait_for "$HOST" 'Start Live' 15
wait_for "$HOST" 'LIVE' 30 nowait-tap
wait_for "$HOST" 'Stop Live' 5
wait_for "$HOST" 'Start Live' 15 nowait-tap

echo; echo "== host log";   logs "$HOST"
echo; echo "== viewer log"; logs "$VIEWER"
echo; echo "PASS. Screenshots in $OUT/"

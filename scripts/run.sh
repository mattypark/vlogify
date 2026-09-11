#!/usr/bin/env bash
# Builds vlogify, runs it on a dedicated simulator, screenshots it, and shuts the
# simulator back down.
#
# That last part is not optional. A booted simulator runtime leaves mediaanalysisd
# running, and it has been seen pegging a core at 742%.
#
#   scripts/run.sh                          # whatever is persisted (first launch = welcome)
#   scripts/run.sh --demo full              # signed in, a 3-person log with clips, a solo vlog, history
#   scripts/run.sh --demo empty             # first launch
#   scripts/run.sh --demo full --screen camera --hour 17
#   scripts/run.sh --demo full --locale ko
#   scripts/run.sh --device "iPhone 16e"    # a different device class (default iPhone 17 Pro)
#   scripts/run.sh --keep                   # leave the simulator up to poke at it by hand
#   scripts/run.sh --no-build               # reuse the last build
set -euo pipefail

cd "$(dirname "$0")/.."

DEVICE_TYPE="iPhone 17 Pro"
BUNDLE_ID="com.matthewpark.vlogify"
SHOTS="build/screenshots"
ARGS=(-vlogifyPermissions granted)
KEEP=0
BUILD=1
NAME_SUFFIX=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --demo) ARGS+=(-vlogifyDemo "$2"); NAME_SUFFIX="$NAME_SUFFIX-$2"; shift 2 ;;
    --screen) ARGS+=(-vlogifyScreen "$2"); NAME_SUFFIX="$NAME_SUFFIX-$2"; shift 2 ;;
    --hour) ARGS+=(-vlogifyHour "$2"); shift 2 ;;
    --locale) ARGS+=(-AppleLanguages "($2)" -AppleLocale "$2"); NAME_SUFFIX="$NAME_SUFFIX-$2"; shift 2 ;;
    --device) DEVICE_TYPE="$2"; shift 2 ;;
    --keep) KEEP=1; shift ;;
    --no-build) BUILD=0; shift ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

DEVICE_NAME="Vlogify Sim ($DEVICE_TYPE)"
TYPE_ID="com.apple.CoreSimulator.SimDeviceType.$(echo "$DEVICE_TYPE" | tr ' ' '-')"

# A device of our own. Other simulators on this machine belong to other projects, and
# shutting one of those down would kill someone else's work.
DEVICE=$(xcrun simctl list devices | grep "$DEVICE_NAME (" | grep -oE "[0-9A-F-]{36}" | head -1 || true)
if [[ -z "$DEVICE" ]]; then
  RUNTIME=$(xcrun simctl list runtimes | grep -oE "com.apple.CoreSimulator.SimRuntime.iOS-[0-9-]+" | tail -1)
  DEVICE=$(xcrun simctl create "$DEVICE_NAME" "$TYPE_ID" "$RUNTIME")
  echo "created $DEVICE_NAME"
fi

cleanup() {
  if [[ "$KEEP" -eq 0 ]]; then
    xcrun simctl shutdown "$DEVICE" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

xcrun simctl boot "$DEVICE" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null 2>&1 || true
xcrun simctl status_bar "$DEVICE" override --time "9:41" --batteryState charged --batteryLevel 100 >/dev/null 2>&1 || true

if [[ "$BUILD" -eq 1 ]]; then
  xcodebuild -project ios/Vlogify.xcodeproj -scheme Vlogify \
    -destination "id=$DEVICE" -derivedDataPath ios/build -quiet build
fi

APP=$(find ios/build/Build/Products -name "Vlogify.app" -maxdepth 3 | head -1)
xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch "$DEVICE" "$BUNDLE_ID" "${ARGS[@]}" >/dev/null
sleep 4

mkdir -p "$SHOTS"
SLUG=$(echo "$DEVICE_TYPE" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
OUT="$SHOTS/$SLUG$NAME_SUFFIX.png"
xcrun simctl io "$DEVICE" screenshot "$OUT" >/dev/null 2>&1
echo "$OUT"

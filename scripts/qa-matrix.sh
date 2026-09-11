#!/usr/bin/env bash
# Runs the overnight walker on every device in qa/matrix.json and writes a report.
#
#   scripts/qa-matrix.sh                  # one pass on all three devices
#   scripts/qa-matrix.sh --device "iPhone 16e"
#   scripts/qa-matrix.sh --only ScreenWalkerTests/testHomeFullAndRoomTimeline
#   scripts/qa-matrix.sh --report qa/reports/2026-09-11   # where to write (default: today)
#
# Builds once with build-for-testing, then test-without-building per device so the
# three runs measure the app, not the compiler. Every device gets its own
# .xcresult; screenshots are exported to screens/<device>/, results to results.json,
# and summary.md is regenerated with the three headline numbers first.
#
# Simulators this script boots, it shuts down. Devices named "Vlogify QA (...)" are
# its own; nothing else on the machine is touched.
set -uo pipefail
cd "$(dirname "$0")/.."

REPORT="qa/reports/$(date +%Y-%m-%d)"
ONLY=""
DEVICE_FILTER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --report) REPORT="$2"; shift 2 ;;
    --only) ONLY="-only-testing:VlogifyUITests/$2"; shift 2 ;;
    --device) DEVICE_FILTER="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done
mkdir -p "$REPORT/screens" "$REPORT/bundles"
RUN_ID=$(date +%H%M%S)
echo "report: $REPORT (run $RUN_ID)"

(cd ios && xcodegen generate >/dev/null)
RUNTIME=$(xcrun simctl list runtimes | grep -oE "com.apple.CoreSimulator.SimRuntime.iOS-[0-9-]+" | tail -1)

BOOTED=()
cleanup() {
  for id in "${BOOTED[@]:-}"; do
    [[ -n "$id" ]] && xcrun simctl shutdown "$id" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

device_id() {
  local name="Vlogify QA ($1)"
  local id
  id=$(xcrun simctl list devices | grep "$name (" | grep -oE "[0-9A-F-]{36}" | head -1 || true)
  if [[ -z "$id" ]]; then
    id=$(xcrun simctl create "$name" "com.apple.CoreSimulator.SimDeviceType.$2" "$RUNTIME")
  fi
  echo "$id"
}

FIRST=$(python3 -c 'import json;d=json.load(open("qa/matrix.json"))["devices"][0];print(d["name"]+"|"+d["type"])')
FIRST_ID=$(device_id "${FIRST%%|*}" "${FIRST##*|}")
xcrun simctl boot "$FIRST_ID" >/dev/null 2>&1 || true
BOOTED+=("$FIRST_ID")

echo "building for testing…"
if ! xcodebuild build-for-testing -project ios/Vlogify.xcodeproj -scheme Vlogify \
    -destination "id=$FIRST_ID" -derivedDataPath ios/build -quiet 2>"$REPORT/build-$RUN_ID.log"; then
  echo "BUILD FAILED — see $REPORT/build-$RUN_ID.log"
  exit 2
fi

FAILED_DEVICES=0
while IFS='|' read -r NAME TYPE; do
  [[ -n "$DEVICE_FILTER" && "$NAME" != "$DEVICE_FILTER" ]] && continue
  SLUG=$(echo "$NAME" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
  ID=$(device_id "$NAME" "$TYPE")
  xcrun simctl boot "$ID" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$ID" -b >/dev/null 2>&1 || true
  xcrun simctl status_bar "$ID" override --time "9:41" --batteryState charged --batteryLevel 100 >/dev/null 2>&1 || true
  BOOTED+=("$ID")
  BUNDLE="$REPORT/bundles/$SLUG-$RUN_ID.xcresult"
  echo "── $NAME"
  xcodebuild test-without-building -project ios/Vlogify.xcodeproj -scheme Vlogify \
    -destination "id=$ID" -derivedDataPath ios/build -resultBundlePath "$BUNDLE" \
    $ONLY 2>&1 | grep -E "Test Case .*(passed|failed)|error:|\*\* TEST" | sed "s/^/   /" || true
  mkdir -p "$REPORT/screens/$SLUG"
  xcrun xcresulttool export attachments --path "$BUNDLE" --output-path "$REPORT/screens/$SLUG" >/dev/null 2>&1 || true
  xcrun xcresulttool get test-results tests --path "$BUNDLE" > "$REPORT/results-$SLUG-$RUN_ID.json" 2>/dev/null || true
  if grep -q '"result" *: *"Failed"' "$REPORT/results-$SLUG-$RUN_ID.json" 2>/dev/null; then FAILED_DEVICES=$((FAILED_DEVICES + 1)); fi
  xcrun simctl shutdown "$ID" >/dev/null 2>&1 || true
done < <(python3 -c 'import json;[print(d["name"]+"|"+d["type"]) for d in json.load(open("qa/matrix.json"))["devices"]]')

python3 qa/summarize.py "$REPORT" > "$REPORT/summary.md" || echo "summary failed" >&2
echo
head -30 "$REPORT/summary.md"
exit $(( FAILED_DEVICES > 0 ? 1 : 0 ))

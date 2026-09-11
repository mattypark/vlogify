#!/usr/bin/env bash
# Archive, export, and optionally upload to TestFlight.
#
#   scripts/testflight.sh                # archive + export only, verifies the whole chain
#   scripts/testflight.sh --upload       # and send it to App Store Connect
#   scripts/testflight.sh --upload-only  # re-upload the ipa already in build/
#
# Credentials are never stored here. See docs/TESTFLIGHT.md for the two ways to
# authenticate with App Store Connect. Nothing here ever reads, prints, or stores one.
set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME=Vlogify
PROJECT=ios/Vlogify.xcodeproj
ARCHIVE=build/Vlogify.xcarchive
EXPORT=build/export
UPLOAD=0
UPLOAD_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --upload) UPLOAD=1; shift ;;
    --upload-only) UPLOAD=1; UPLOAD_ONLY=1; shift ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

if [[ "$UPLOAD_ONLY" -eq 0 ]]; then
  scripts/pre-submit.sh

  (cd ios && xcodegen generate >/dev/null)

  # Build number has to rise on every upload or App Store Connect rejects the build.
  # Marketing version stays put until Matthew says otherwise.
  CURRENT=$(grep -m1 "CURRENT_PROJECT_VERSION" ios/project.yml | grep -oE '[0-9]+')
  NEXT=$((CURRENT + 1))
  sed -i '' "s/CURRENT_PROJECT_VERSION: \"$CURRENT\"/CURRENT_PROJECT_VERSION: \"$NEXT\"/" ios/project.yml
  (cd ios && xcodegen generate >/dev/null)
  echo "build $CURRENT -> $NEXT"

  rm -rf "$ARCHIVE" "$EXPORT"
  xcodebuild archive \
    -project "$PROJECT" -scheme "$SCHEME" \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE" | tail -1

  cat > build/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>R43H5332KH</string>
  <key>uploadSymbols</key><true/>
  <key>destination</key><string>export</string>
</dict>
</plist>
PLIST

  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportOptionsPlist build/ExportOptions.plist \
    -exportPath "$EXPORT" | tail -1

  echo "exported: $(find "$EXPORT" -name '*.ipa' | head -1)"
fi

if [[ "$UPLOAD" -eq 1 ]]; then
  IPA=$(find "$EXPORT" -name '*.ipa' | head -1)
  [[ -n "$IPA" ]] || { echo "no ipa in $EXPORT -- run without --upload-only first" >&2; exit 1; }

  if [[ -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" ]]; then
    xcrun altool --upload-app -f "$IPA" -t ios \
      --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
  elif [[ -n "${ASC_USERNAME:-}" && -n "${ASC_APP_PASSWORD:-}" ]]; then
    xcrun altool --upload-app -f "$IPA" -t ios \
      -u "$ASC_USERNAME" -p "$ASC_APP_PASSWORD"
  else
    echo "No App Store Connect credentials in the environment." >&2
    echo "See docs/TESTFLIGHT.md." >&2
    exit 1
  fi
fi

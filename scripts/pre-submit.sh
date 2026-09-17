#!/usr/bin/env bash
# The mechanical half of the App Store checklist. Everything a script can actually
# check; the rest is the ios-app-store-readiness skill's job.
set -uo pipefail

cd "$(dirname "$0")/.."

# --testflight downgrades the live-URL checks to warnings. TestFlight does not fetch
# them; App Store submission does, and a support URL that 404s is the single most common
# first-submission rejection, so the default stays hard.
TESTFLIGHT=0
[[ "${1:-}" == "--testflight" ]] && TESTFLIGHT=1

FAILED=0
pass() { printf "  ok    %s\n" "$1"; }
fail() { printf "  FAIL  %s\n" "$1"; FAILED=1; }
warn() { printf "  warn  %s\n" "$1"; }

echo "vlogify pre-submit${TESTFLIGHT:+ (testflight mode)}"

[[ -f ios/Vlogify/PrivacyInfo.xcprivacy ]] \
  && pass "privacy manifest present" \
  || fail "ios/Vlogify/PrivacyInfo.xcprivacy is missing"

grep -q "ITSAppUsesNonExemptEncryption" ios/project.yml \
  && pass "export compliance declared" \
  || fail "ITSAppUsesNonExemptEncryption not declared (every upload will ask)"

grep -q "com.apple.developer.applesignin" ios/project.yml \
  && pass "sign in with apple entitlement (required: google sign-in exists)" \
  || fail "Sign in with Apple entitlement missing"

# App Review rejects a 1024 icon that is transparent or has rounded corners baked in.
ICON=ios/Vlogify/Resources/Assets.xcassets/AppIcon.appiconset
if compgen -G "$ICON/*.png" >/dev/null; then
  SIZE=$(sips -g pixelWidth "$ICON"/*.png 2>/dev/null | grep -m1 pixelWidth | awk '{print $2}')
  [[ "$SIZE" == "1024" ]] && pass "1024 app icon present" || fail "app icon is ${SIZE}px, needs 1024"
  if sips -g hasAlpha "$ICON"/*.png 2>/dev/null | grep -q "hasAlpha: yes"; then
    fail "app icon has an alpha channel -- App Review rejects this"
  else
    pass "app icon is opaque"
  fi
else
  fail "no app icon in $ICON"
fi

# Every usage string has to say what the app does with the thing, not just name it.
for key in NSCameraUsageDescription NSMicrophoneUsageDescription NSPhotoLibraryAddUsageDescription; do
  line=$(grep -m1 "$key" ios/project.yml | sed 's/.*: "//; s/"$//')
  if [[ -z "$line" ]]; then fail "$key missing"; elif [[ ${#line} -lt 40 ]]; then fail "$key too short to survive review"; else pass "$key is specific (${#line} chars)"; fi
done

grep -q "MARKETING_VERSION" ios/project.yml \
  && pass "marketing version set" \
  || fail "MARKETING_VERSION missing"

# 5.1.1(v): account deletion inside the app. 5.1.1: privacy policy linked in-app.
grep -rq "deleteAccount" ios/Vlogify/Sources && pass "delete account reachable in-app" || fail "no delete account path"
grep -rq "privacy" ios/Vlogify/Sources/Features/Profile/ProfileView.swift && pass "privacy policy linked in-app" || fail "no in-app privacy link"

# 1.2: UGC needs report + block.
grep -rq "report(" ios/Vlogify/Sources && grep -rq "block(userID" ios/Vlogify/Sources \
  && pass "report and block present (UGC 1.2)" || fail "report/block missing"

# 2.1: no placeholders shipped.
# Only string literals count: a comment explaining why there is no "coming soon"
# button is not a "coming soon" button.
if grep -rnE '"[^"]*(coming soon|lorem ipsum|TODO|FIXME)[^"]*"' ios/Vlogify/Sources --include='*.swift' | grep -v -E '^[^:]+:[0-9]+:[[:space:]]*//' | grep -q .; then
  fail "placeholder copy in a shipping string"
else
  pass "no placeholder copy"
fi

# IPv6: App Review's network is IPv6-only; an IPv4 literal is a cited rejection.
if grep -rnE "\b[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\b" ios/Vlogify/Sources ios/VlogifyDesign/Sources | grep -v "127.0.0.1" | grep -q .; then
  fail "hardcoded IPv4 literal"
else
  pass "no IPv4 literals"
fi

# Six localisations declared and present.
if [[ -f ios/Vlogify/Resources/Localizable.xcstrings ]]; then
  for lang in ko ja zh-Hant vi ru; do
    grep -q "\"$lang\"" ios/Vlogify/Resources/Localizable.xcstrings && pass "localised: $lang" || fail "no $lang strings"
  done
else
  fail "Localizable.xcstrings missing"
fi

# Legal URLs must answer 200 before submission. Skipped offline.
for url in https://vlogify.app/privacy https://vlogify.app/terms https://vlogify.app/support; do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 "$url" 2>/dev/null); code=${code:-000}
  if [[ "$code" == "200" ]]; then
    pass "$url"
  elif [[ "$TESTFLIGHT" -eq 1 ]]; then
    warn "$url returned $code -- fine for TestFlight, blocks App Store submission"
  else
    fail "$url returned $code (deploy web/ before submitting)"
  fi
done

# Captured first, not piped into head: under `pipefail`, head closing the pipe early
# sends xcodebuild SIGPIPE and the check fails or passes on timing alone.
XCODE_VERSION=$(xcodebuild -version 2>/dev/null | sed -n '1p')
case "$XCODE_VERSION" in
  "Xcode 26"*|"Xcode 27"*) pass "Xcode 26+ SDK ($XCODE_VERSION)" ;;
  *) fail "Xcode 26 SDK required since Apr 2026 (found: ${XCODE_VERSION:-nothing})" ;;
esac

echo
if [[ "$FAILED" -eq 0 ]]; then
  echo "Mechanical checks pass. Now run the ios-app-store-readiness skill for the rest:"
  echo "  screenshots, description, keywords, age rating (13+, UGC), privacy nutrition label,"
  echo "  demo account in the Sign-In Required fields (review@vlogify.app / 000000), an archive."
else
  echo "Fix the failures above before archiving."
fi
exit "$FAILED"

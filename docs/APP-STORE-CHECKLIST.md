# App Store checklist — status for vlogify

Native iOS. Walked against the `ios-app-store-readiness` skill on 2026-09-11.
Counted honestly: **ready except six**, all listed under *Not yet*.

## Done in this session
- Complete, no dead buttons, no "coming soon" (2.1) — stack/zip hidden by flags
- Xcode 26.6 / iOS 26 SDK builds
- `PrivacyInfo.xcprivacy` declares Name, Email, User ID, Photos/Videos; required-reason APIs UserDefaults, FileTimestamp, DiskSpace
- Specific purpose strings for camera, microphone, Photos-add (localised)
- Sign in with Apple present (Google exists → required) using Apple's own button
- Account deletion in-app with confirmation; contract requires SIWA token revocation
- Privacy policy, terms and support linked **in the app** (Profile → about)
- UGC: report (reason list) + block + owner remove; blocking hides both ways
- Export compliance declared (`ITSAppUsesNonExemptEncryption = false`)
- No IPv4 literals; ATS on; tokens in Keychain; `os.Logger`, no `print`
- Opaque 1024 icon, unique bundle id, no "beta" in the name
- iPhone-only target; iPad runs the iPhone layout
- Six localisations; per-app language via Settings
- `scripts/pre-submit.sh` automates the mechanical half

## Not yet (owner: App Store session — `nextsessions/appstore-session.md`)
1. **Support / privacy / terms URLs return 200** — `web/` is written, not deployed
2. **App Store Connect record + age-rating questionnaire** (13+, UGC)
3. **Screenshots 6.9" 1320×2868** showing the app in use (walker screenshots are a start)
4. **Review notes** with the demo account in *Sign-In Required* (review@vlogify.app / 000000)
5. **Backend on** — the reviewer must reach a live server (backend session)
6. **EU DSA trader status** decision (name/address become public) or turn off EU

## Review notes template

CONCEPT: a private room of friends gets the same hourly ping; each posts a 2 s clip;
the app stitches the day. Free, no purchases, no ads.
DEMO ACCOUNT: review@vlogify.app / code 000000 (Continue with email). Lands on a
seeded room with clips so "play the day" and export can be tested.
WHERE: delete account = Profile → account → delete account. Report = long-press a
friend's tile. Block = long-press a member disc.
PERMISSIONS: camera + mic (record), Photos add-only (export), notifications (hourly ping).
THIRD-PARTY DATA: none. No analytics. No AI.

# Paste-ready: get ANY of my iOS apps ready to submit to the App Store

Fill the four blanks, paste everything below the line into a fresh Claude Code session
opened in the app's folder.

---

You're getting my SwiftUI app **<APP NAME>** at **<PROJECT PATH>** ready for App Store
review. App Store Connect app id **<APP ID>**, bundle **<BUNDLE ID>**. I press Submit
myself; your job ends with "everything is set, press Submit" or a numbered list of what
still blocks it.

## Hard rules

- App Store Connect is a REAL account (HMU, INC.) with 12+ live apps. Act only on app id
  <APP ID>. Never submit for review, never touch pricing, availability, IAP or anything
  with money, never delete builds, groups, testers or feedback.
- Never read, print or edit `.env*`, `.dev.vars`, `Secrets.xcconfig`, `.p8` keys or
  tokens. If a secret is needed, give me the exact command and I paste the value.
- Never push. Commit every viable step as Matthew Park <matthew.parkk0@gmail.com>.
- Upload a build only after I say "upload build N". Local builds, simulator runs and
  screenshots are fine. Shut down any simulator you boot.
- Writes to production data (seeding a demo/review account, DB changes): ask first.

## Do this, in order

1. **Read the state.** `docs/NEXT-SESSION.md` (or README), `git log -15`,
   `git status`, backend `/health` if there is one. Tell me in five lines where it stands.

2. **Mechanical checks.** Run `scripts/pre-submit.sh` if it exists; otherwise check by
   script, not by eye:
   - every `NS*UsageDescription` present and specific (what + why);
   - the 1024 icon has no alpha channel;
   - `PrivacyInfo.xcprivacy` present;
   - `ITSAppUsesNonExemptEncryption` set;
   - no hardcoded IPv4 literals;
   - no placeholder copy (`lorem`, `TODO:`, `coming soon`);
   - privacy / terms / support URLs return 200 in a cold `curl`;
   - Xcode 26+ SDK.
   Also run the unit tests and the backend tests, and quote any failures word for word.

3. **Walk the `ios-app-store-readiness` skill top to bottom.** Report as "N failing:"
   plus the list, never "looks good". The ones that actually get apps rejected:
   - every screen and button works; reviewers tap everything (2.1);
   - account deletion is inside the app, and it revokes Sign in with Apple;
   - Sign in with Apple is offered if any other login is;
   - user-generated content has report + block + filter, and someone acts on reports
     within 24 hours (1.2);
   - AI disclosure and consent if any user data reaches an AI provider (5.1.2(i));
   - age rating answered;
   - EU trader status decided, or EU turned off;
   - the demo account goes in the Sign-In Required fields, with any OTP in the notes,
     and it looks lived-in;
   - the backend is awake.

4. **Hunt for dead states in the core flow.** Read the code for the one thing the app
   exists to do (record, post, scan, whatever it is) as a brand-new reviewer account
   would hit it. Look for state picked once on appear, buttons that silently no-op, and
   empty lists with no way forward. Fix them, and show me before/after screenshots.

5. **Strings.** If the app is localised, re-export (`xcodebuild -exportLocalizations`),
   rebuild the catalog, and make sure nothing new ships English-only.

6. **Screenshots.** Take them on the simulator at 6.9" (iPhone 17 Pro Max, 1320x2868),
   and at 6.5" (1284x2778) if that slot is used. Use demo data and a 9:41 status bar.
   They must show the app in use: no login or splash screen, no prices, no UI that isn't
   in the app. Captions and a device frame are fine. Send me a contact sheet first.

7. **When I say "upload build N":**
   - Bump the build number and archive + export (the project's `scripts/testflight.sh`
     if it has one).
   - Unzip the IPA and verify: CFBundleVersion = N, the production backend URL,
     `get-task-allow` false, an App Store (not development) profile.
   - Upload with asc-mcp `build_uploads_upload`. If it answers "candidate observed but
     not attributed", inspect it with `build_uploads_get`. If it's our fresh upload
     (same version, created seconds ago, no file), continue with
     `build_uploads_upload_file`, passing the `file_id` and `expected_md5` it gives you.
     Never create a second upload.
   - Poll `builds_find_by_number` until VALID, then add it to the internal TestFlight
     group so I can test on my phone.

8. **Browser-only steps** (asc-mcp has no versions or screenshots tools on purpose): use
   Claude in Chrome in my Chrome, where I'm signed in. On the version page:
   - attach build N;
   - replace the screenshots;
   - check App Review Information (sign-in fields, notes, contact);
   - check the privacy label matches what the app collects.
   Screenshot each step. Stop before "Add for Review". If the extension isn't connected,
   give me the exact clicks instead.

9. **Finish with one message:**
   - what's done;
   - what I must do myself, in order (e.g. test the core flow on my phone from
     TestFlight, paste a secret, press Submit);
   - anything that's a rejection risk, ranked.
   Also update `docs/NEXT-SESSION.md` and commit.

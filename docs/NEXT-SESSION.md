# vlogify — next session brief

The folk redesign is **done and committed**. What is left is submission, and most of it
is not code. Read this, then `docs/DESIGN.md` and `docs/CONTRACT.md`.

---

## Where things actually stand

**App**: complete and runnable, 76 Swift files, on `main`, nothing pushed. Runs entirely
on an on-device mock backend (`MockBackend`) — every screen works with no server.
`swift test --package-path ios/VlogifyDesign` = **53 tests green**. Screenshot of the
redesign at `build/screenshots/iphone-17-pro-full.png`.

**Look**: folk.com's cool blue-white, taken from their shipped CSS. `#F5F6F8` ground,
`#1F2A2F` slate ink, `#0088FF` action. Every pressable thing is extruded on a two-tier
plinth mixed from its own fill. Bagel Fat One survives as the wordmark only; everything
else is SF Pro. Gloria is gone. `docs/DESIGN.md` is current; `docs/DECISIONS.md` carries
the three new entries and marks the one it supersedes.

### Can it be submitted? Not yet. Three blockers, down from six

1. **No build exists.** Nothing has ever been uploaded; TestFlight is empty. The
   archive -> export chain itself is **verified working** as of 2026-09-17 and produces a
   TestFlight-eligible ipa; only the upload credential is missing.
   **`docs/SHIP-TESTFLIGHT.md` is the paste-ready brief for the session that ships it.**
2. **No backend.** The app talks to `MockBackend`, so rooms do not sync between two
   phones, while the App Store description says they do — 2.3.1 (accurate metadata) and
   arguably 2.1. `docs/BACKEND-README.md` is the paste-ready brief. **This blocker is
   independent of everything else here**: it is either a backend session or a rewrite of
   the listing copy, and nothing in the app can close it.
3. **`vlogify.app` is not registered** (`dig` returns nothing, no NS). The privacy, terms,
   support and marketing URLs in ASC all point at it. A support URL that doesn't return
   200 is the most common first-submission rejection. `web/` is written, recoloured to the
   folk palette, and has `vercel.json` ready — it needs a host. Matthew deferred this;
   the zero-cost unblock is a free `*.vercel.app` subdomain rather than a purchase, and
   **Matthew deploys it himself** (the Vercel MCP on this Mac is Andrew's account).
   `scripts/pre-submit.sh` curls exactly these URLs and fails on them until then.

### Closed since the last brief

- **Beta review details** — were *entirely* blank, not just the phone. Now filled: Matthew
  Park, `matthew.parkk0@gmail.com`, `+15029998282`, demo `review@vlogify.app` / `000000`
  (real: `MockBackend.testEmail`/`testCode` are pinned in the build, no mail is sent), and
  full review notes.
- **TestFlight feedback email** — was `hello@vlogify.app` against a domain with no MX, so
  tester feedback and Apple's beta-review mail would both have bounced. Now Matthew's
  address; swap both back once the domain exists.
- **Export compliance** — correctly absent. Apple refuses to create a declaration for an
  app with no non-exempt crypto; `ITSAppUsesNonExemptEncryption = false` answers it at
  every upload instead.

### Still open, needs a browser

**The browser-only ASC fields** (no MCP tool exists for any of them). The Claude Chrome
extension was **not connected** when this was attempted — connect it and these can be
driven, stopping before each Save:

- Privacy policy URL — *waits on blocker 3.*
- Category: Social Networking, secondary Photo & Video.
- Content rights: does not use third-party content. (`contentRightsDeclaration` is
  currently `null` on the record — verified live.)
- Age rating: 13+, user-generated content **Yes**, unrestricted web access no, no chat.
- App Privacy labels: Contact Info (Name, Email) · User Content (Photos or Videos) ·
  Identifiers (User ID), purpose App Functionality, **none used for tracking**. Must match
  `PrivacyInfo.xcprivacy` exactly or it is an automatic rejection.
- EU DSA trader status: decide (address becomes public) or turn off EU availability.

**Screenshots** 1320×2868 for 6.9". Worth taking now that the app looks like itself —
`scripts/run.sh --demo full` on an iPhone 17 Pro Max, showing it in use, never a login
screen.

---

## House rules that bite

- **Never push.** Matthew pushes. Commit after every stage.
- **Never touch `.env*` or `Secrets.xcconfig`.**
- **Test suites and simulator walks only overnight or when Matthew says "test it."**
  After a small or medium change: build, maybe one screenshot, commit, move on.
- Shut down any simulator *you* booted (`xcrun simctl shutdown`) — `mediaanalysisd` pegs
  a core. Leave ones you did not boot alone.
- The 20-item `docs/LAUNCH-CHECKLIST.md` gets walked before "done". Last walk:
  2026-09-17, 19 done or n/a, 1 blocked on the domain.
- ASC MCP is a **real** Apple account with 12 other live apps. Only ever act on app id
  `6811419336`. Never submit for release, never touch pricing or IAP, never delete.

## Map of the repo

```
ios/project.yml              XcodeGen spec (.xcodeproj is generated + gitignored)
ios/Vlogify/Sources/
  Root/                      App, RootGate, AppState, LaunchArguments, FeatureFlags
  Features/                  Onboarding, Home (day page), Rooms, Camera, Player, History, Profile, Safety
  Components/                Chunky (buttons), TapBurstLayer, NoteBlockView, ClipTile, HourStamp, ColorRingPicker
  Services/                  Camera, DayCompositor, NotesStore, HourlyScheduler, Clock, CapturePreferences
ios/VlogifyDesign/Sources/
  VlogifyDesign/             Palette, Extruded, Motion, Elevation, Blobs, Typography, Spacing, Doodles
  VlogifyEngine/             DayClock, SlotPing, RoomRules, InviteCode, StitchPlan   ← frozen
  VlogifyContract/           wire types, 8 protocols, MockBackend                    ← frozen
ios/VlogifyUITests/          screen walker + launch/flow metrics
web/                         privacy, terms, support, 404, OG, sitemap — undeployed
qa/, scripts/, docs/         overnight harness, dev/run/pre-submit/testflight, all docs
```

Run: `scripts/dev.sh` (regenerate) · `scripts/run.sh --demo full` (build + screenshot +
shut down) · `swift test --package-path ios/VlogifyDesign`.

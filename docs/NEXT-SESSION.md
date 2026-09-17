# vlogify — next session brief

Two jobs, in this order: **(1) redesign the UI toward folk.com's blue/white**, **(2) get it
submittable on the App Store**. This file is the whole handoff — read it, then
`docs/DECISIONS.md` and `docs/CONTRACT.md` before touching code.

---

## Where things actually stand

**App**: complete and runnable, 76 Swift files, 20 commits on `main`, nothing pushed.
Runs entirely on an on-device mock backend (`MockBackend`) — every screen works with no
server. `swift test --package-path ios/VlogifyDesign` = 52 tests green. The XCUITest
walker (15 screens + 4 metrics) passed on iPhone 17 Pro last run.

**What it does**: private room of 2–20 friends, same ping every hour, each posts one
2-second one-take clip, app stitches the day into one split-screen video → Photos →
Reels/TikTok/Shorts. Solo vlogs unlimited. Day resets 4 AM. Landscape by default.
Local-only Notion-style notes on the day page and per room. Six languages, chosen
in-app after sign-in.

**App Store Connect**: record **exists** — app id `6811419336`, bundle
`com.matthewpark.vlogify`, SKU `vlogify-v1`, version 1.0 in `PREPARE_FOR_SUBMISSION`.
Filled via API: en-US description, keywords, promo text, support + marketing URLs,
TestFlight tester description + feedback email + privacy URL, TestFlight group
"friends" (external, no builds).

### Can it be submitted? No. Six blockers

1. **No build exists.** Nothing has ever been archived or uploaded. TestFlight is empty.
2. **No backend.** The app talks to `MockBackend`; rooms don't sync between two phones.
   Shipping this as-is means the App Store description promises something the binary
   cannot do — 2.3.1 (accurate metadata) and arguably 2.1.
3. **`vlogify.app` is not registered** (`dig` returns nothing). The privacy, terms and
   support URLs already in ASC point at a domain that does not resolve. A support URL
   that doesn't return 200 is the single most common first-submission rejection.
   `web/` is written and ready to deploy — it needs a domain and a host.
4. **Beta review contact phone** — Apple rejected the save with
   `ENTITY_ERROR.ATTRIBUTE.REQUIRED: contactPhone`. Everything else in that block is
   drafted (demo `review@vlogify.app` / `000000`, full review notes). Ask Matthew for a
   number, then `beta_app_update_review_details` succeeds.
5. **Browser-only fields, all still blank** (no API tool for these): privacy policy URL,
   category, content rights, age rating questionnaire, App Privacy nutrition labels.
6. **No screenshots.** Needs 6.9" 1320×2868, app in use, not a login screen.

Export compliance is *correctly* absent — Apple refuses to create a declaration for an
app with no non-exempt crypto. `ITSAppUsesNonExemptEncryption = false` in Info.plist
answers it at every upload instead.

---

## Job 1 — the folk redesign

**Why**: Matthew wants the blue/white aesthetic of folk.com, and wants more visual
distance from Setlog so 4.1 (copycat) is never a conversation. The current look is warm
paper + soot + chingo sticker buttons. Moving to cool blue-white + slate ink + folk's
extruded buttons does both at once.

### folk's real tokens (pulled from their shipped CSS, 2026-09-17)

| role | hex | notes |
|---|---|---|
| ink | `#1F2A2F` | deep blue-slate. 157 uses — the dominant colour on the site |
| ground | `#F5F6F8` / `#F6F8FB` | cool blue-white, never pure white |
| card | `#FFFFFF` | |
| line | `#DDE5EE` / `#E5E5DE` | blue-grey hairline |
| blue | `#0088FF` | the action colour |
| blue light | `#4DB6FF` | gradient top |
| blue mid | `#0070D4` | first shadow tier |
| blue deep | `#005DB1` | second shadow tier |
| periwinkle | `#7AA7FF` | secondary/soft |
| orange | `#E7642B` | the one warm counterpoint |
| sand | `#F2A35E` / `#ECEAE3` | warm neutrals |

Structure: `--border: 3px solid var(--ink)` and `--border-2: 2px solid var(--ink)`.
Radii: `999px` pills dominate, then `18 / 20 / 15 / 24`. Type: Inter + a custom gothic
display + SF.

### The button — copy this exactly, it's the whole feel

folk's primary CTA is a **four-tier extruded shadow in progressively darker shades of
the fill**, not a black offset, plus a top gloss line. It compresses to one tier on
press and lifts 1px on hover:

```css
/* rest */
background: linear-gradient(#4DB6FF 0%, #08F 100%);
box-shadow: inset 0 1px #FFFFFF8C,          /* gloss */
            0 1px #0070D4, 0 2px #0070D4,   /* mid */
            0 3px #005DB1, 0 4px #005DB1,   /* deep */
            0 7px 10px -2px #0060BE52;      /* ambient */
text-shadow: 0 1px #00285A59;
transition: transform .12s cubic-bezier(.22,1,.36,1), box-shadow .12s;
/* active */
box-shadow: inset 0 1px #FFFFFF8C, 0 1px #005DB1, 0 2px 4px #0060BE52;
```

In SwiftUI that is a `ButtonStyle` drawing four stacked `RoundedRectangle`s offset
1/2/3/4pt in the two darker tones, a gradient fill, a 1pt white top-inset line, and a
soft ambient shadow; on `isPressed` collapse to one tier and translate the label +3pt.
`Sticker.swift` already has the offset/press plumbing — change *what* it draws, keep
*how* it presses. **Delete the hard black `Sticker.drop` shadow**: that came from chingo
and is the loudest thing tying vlogify's look to another app.

### What to change, concretely

1. **`VlogifyDesign/Palette.swift`** — swap the roles. `ground` → `#F5F6F8`, `card` →
   `#FFFFFF`, `text` → `#1F2A2F`, `hairline` → `#DDE5EE`. Keep OKLCH declarations (the
   derived-ink machinery and `PaletteTests` depend on it) — convert the hexes above,
   don't abandon the type. Replace the seven "playful" fills with a folk set: blue,
   periwinkle, orange, sand, mint, lilac, slate — same `Fill` struct, same contrast
   tests, which will fail until every new fill's ink clears AA. That failure is the
   point.
2. **`Sticker.swift` → `Extruded.swift`** — new tiered-shadow style per above.
   `StickerButtonStyle` / `StickerCircleStyle` keep their names and call sites so this
   is one file's worth of diff, not fifty.
3. **Typography** — Bagel Fat One is very chingo. folk uses a tight gothic. Either keep
   Bagel only for the wordmark and move shouts to SF Pro Display Heavy, or bundle a
   different OFL display face. Gloria (the handwriting on notes) should go — it fights
   the cool palette. Notes in Inter or SF Pro Text.
4. **Tap bursts** — keep the mechanic, draw from the new fills. They read as folk-ish
   confetti once the palette is cool.
5. **Paint blobs** — keep; recolour. They are the most original thing in the app.
6. **The camera** stays dark (video chrome); only its pills and the shutter restyle.
7. Re-run `scripts/build-strings.py` if any copy changes; re-screenshot; commit.

### Guardrails

- Don't touch `VlogifyEngine` or `VlogifyContract` — frozen, and the backend session is
  building against them.
- Every new colour pair must pass `PaletteTests` (AA on its own fill). No exceptions.
- Reduce Motion still returns `nil` from `Motion.respecting`.
- Keep the accessibility identifiers — the walker depends on them.

---

## Job 2 — App Store

In order, and most of it is not code:

1. **Register a domain.** `vlogify.app` is free as of today. Buy it, deploy `web/`
   (static, `vercel.json` already there), confirm `/privacy`, `/terms`, `/support` all
   return 200. Until then `scripts/pre-submit.sh` fails on exactly those three.
2. **Backend.** `docs/BACKEND-README.md` is the paste-ready brief — Supabase + R2 +
   Resend + APNs against the frozen contract. Without it the app can't honestly claim
   what its listing says.
3. **Phone number** → beta review details.
4. **Browser fields** in App Store Connect (see `docs/ASC-SETUP.md` §Step 4): privacy
   URL, category Social Networking / Photo & Video, content rights = no third-party,
   age rating 13+ with User-Generated Content = Yes, App Privacy labels = Contact Info
   (Name, Email) · User Content (Photos or Videos) · Identifiers (User ID), purpose App
   Functionality, **none used for tracking** — must match `PrivacyInfo.xcprivacy`
   exactly or it's an automatic rejection.
5. **Screenshots** 1320×2868 from the redesigned app, showing it in use.
6. `scripts/pre-submit.sh` green → `scripts/testflight.sh` → `--upload-only`.

---

## House rules that bite

- **Never push.** Matthew pushes. Commit after every stage.
- **Never touch `.env*` or `Secrets.xcconfig`.**
- **Test suites and simulator walks only overnight or when Matthew says "test it."**
  After a small or medium change: build, maybe one screenshot, commit, move on.
- Shut down any simulator you boot (`xcrun simctl shutdown`) — `mediaanalysisd` pegs a
  core otherwise.
- The 20-item launch checklist (`docs/LAUNCH-CHECKLIST.md`) gets walked before "done",
  reported item by item as done / n-a-with-reason.
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
  VlogifyDesign/             Palette, Sticker, Motion, Elevation, Blobs, Typography, Spacing, Doodles
  VlogifyEngine/             DayClock, SlotPing, RoomRules, InviteCode, StitchPlan   ← frozen
  VlogifyContract/           wire types, 8 protocols, MockBackend                    ← frozen
ios/VlogifyUITests/          screen walker + launch/flow metrics
web/                         privacy, terms, support, 404, OG, sitemap — undeployed
qa/, scripts/, docs/         overnight harness, dev/run/pre-submit/testflight, all docs
```

Run: `scripts/dev.sh` (regenerate) · `scripts/run.sh --demo full` (build + screenshot +
shut down) · `swift test --package-path ios/VlogifyDesign`.

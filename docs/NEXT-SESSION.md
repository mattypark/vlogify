# vlogify — next session brief

Updated 2026-09-29, after build 5 (the drawn home + the camera fixes).

## Where it stands

- **App**: ink-on-paper redesign done (`docs/DESIGN.md`), onboarding asks you to draw
  your mark, Setlog-era drawings/words/layouts gone. `swift test --package-path
  ios/VlogifyDesign` = 77 green.
- **Backend is live**: Cloudflare Worker `vlogify` on Matthew's own account
  (`https://vlogify.matthew-parkk0.workers.dev`), D1 `vlogify`, R2 `vlogify-clips` with a
  7-day lifecycle on `clips/`. `cd worker && npm test` = 73 green. Deploy:
  `scripts/deploy-worker.sh` (idempotent) or `cd worker && npx wrangler deploy`.
  The same Worker serves `web/` (privacy, terms, support, 404).
- **App Store Connect** (app `6811419336`, HMU, INC.):
  - Build 1.0 (2) and 1.0 (3) uploaded through the asc-mcp `build_uploads_*` tools
    (Xcode has no ASC account signed in; the MCP key does the upload).
  - Filled: description, keywords (no "bereal"), promo text, URLs, subtitle "one hour at a
    time", Social Networking + Photo & Video, content rights (third-party content: yes),
    age rating 13+ (override), App Privacy label published (Name, Photos/Videos, Audio,
    Other User Content, User ID — linked, app functionality, no tracking), Free, 148
    countries (EU off), Mac/Vision off, 5 screenshots (6.5"), copyright, review contact
    + notes, release automatically after approval.
  - TestFlight: internal group `team` with Matthew; external group `friends` unused.
- **Review room**: code **REV-1EF**, capacity 20, three demo members. Re-seed each day
  while in review: `scripts/seed-review-room.sh <yesterday> <today>`.

## Build 5 (2026-09-29)

- **Uploaded, processed (VALID), in the internal TestFlight group `team`.** Not yet
  attached to version 1.0 -- build 3 still is. Attaching and swapping the screenshots are
  browser-only (asc-mcp has no versions/screenshots tools, on purpose); the Chrome
  extension was not connected when build 5 went up.
- What's in it: home as a self-drawing notebook page (`docs/DESIGN.md`), the drawn `+`
  card, and two camera fixes -- the hour is centred and turns the way the phone is held
  (top-left by default), and the room a clip goes to is derived, so the "pick a room"
  dead state (pill ignores taps, shutter does nothing) is gone. Builds 3 and 4 have that
  bug; do not ship them.
- New App Store screenshots: `build/screenshots/store/v5/appstore69-{1..5}.png`
  (1320x2868) and `appstore65-{1..5}.png` (1284x2778). Order: room, home, mark, new room,
  intro. Framing script lives in the session scratchpad; re-derive from
  `build/screenshots/store/*.png` raw shots if needed.
- **Before Matthew presses Submit:**
  1. Version 1.0 -> Build -> swap build 3 for build 6 (see below). Replace the five screenshots.
  2. He tests recording on his phone from TestFlight (both sideways directions, a room
     with a friend). The simulator has no camera.
  3. Re-seed the review room for the day it goes in (`scripts/seed-review-room.sh`,
     writes production D1 -- ask first).
  4. Strongly recommended: Sign in with Apple revoke secrets on the Worker
     (APPLE_TEAM_ID / APPLE_KEY_ID / APPLE_PRIVATE_KEY, commands at the end of
     `scripts/deploy-worker.sh`). Without them account deletion does not revoke the Apple
     grant, which App Review cites.
- Reports land in D1 with **no alert** (no TG_* secrets; Matthew declined for now). The
  24-hour promise in `docs/MODERATION.md` means checking the queue daily.
- **No build uploads, attaches or swaps without Matthew's explicit OK** for that build.

## After build 5 (not in any uploaded build yet)

Hour turned by tap (starts facing 9 o'clock, saved), "today" -> calendar / "back" on the
camera, own "just me" vlog made automatically, friends-only new room. **The own-vlog change
matters for review** (a fresh account could not record in build 5), so the build to attach
to 1.0 is **build 6**. **Uploaded 2026-09-29** (Matthew said "upload build 6"); final
App Store screenshots for it are `build/screenshots/store/v6/` (#4 re-taken: friends-only
new room). Review notes to paste are in the chat log of that session and in
`nextsessions/app-store-ready-any-app.md` step 8's spirit: Sign in with Apple with any
Apple ID -> own "just me" vlog -> + > join with a code > REV-1EF for the demo room.

## Ready for Submit (2026-09-30)

Version 1.0 has **build 6** attached (verified via API), Matthew's new screenshots are on
the 6.9" slot, review notes updated (own "just me" vlog, no-room recording, the calendar),
Sign-in required unticked, release automatic after approval. Review room seeded for
2026-09-29 (full) and 2026-09-30 (morning). Matthew presses **Add for Review -> Submit**.
While in review: re-seed each morning (`scripts/seed-review-room.sh <yesterday> <today>`).

## Design work still open

Stage 2 of the drawn redesign (plan in the session log): room view, new room / join /
invite, profile + blocked, notifications, history, players, report sheet -- same pen
language as home, camera untouched except what Matthew asks for.

## Open after launch

- Native review of JA / zh-Hant / VI / RU strings (drafted, `needs_review`).
- Domain (`vlogify.app`): unlocks email codes, Google sign-in, universal invite links,
  prettier legal URLs. The invite share link is `vlogify://` and does nothing without the
  app installed.
- EU trader status decision, then turn the EU storefronts on.
- `docs/SESSION-BACKEND.md`, `nextsessions/*` and `.env.example` still describe the old
  Supabase plan.
- The UI walker (`ios/VlogifyUITests`) still uses pre-redesign identifiers in places;
  run it only when asked ("test it") and update ids as it finds them.
- Dead files kept rather than deleted without asking: `Components/SegmentToggle.swift`,
  `Components/ColorRingPicker.swift`, `Components/RoomTypeCard.swift`,
  `scripts/art-slots.py`, `docs/ART-SLOTS.md`.

## House rules that bite

Never push (Matthew pushes). Commit every viable change as Matthew Park. Never touch
`.env*` / `.dev.vars` / `Secrets.xcconfig`. ASC is a real account with 12 other apps: act
only on `6811419336`, never submit for release, never touch money. Shut down any
simulator you boot.

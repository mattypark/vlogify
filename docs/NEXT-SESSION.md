# vlogify — next session brief

Updated 2026-09-28, the night of the first App Store submission.

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

## Before the next build (Matthew is iterating on the design first)

- **No build uploads, attaches or swaps without Matthew's explicit OK** for that build.
- Version 1.0 has **build 3** attached. **Build 4** (hand font everywhere, write-in
  animations, drawn-in buttons) is uploaded to App Store Connect but not attached. The next
  build Matthew approves replaces both.
- Screenshots on the listing already show the hand font (build 4 look); re-take them if
  the design changes again.
- When he says ship: attach the approved build, then Matthew presses **Add for Review →
  Submit**. Optional first: Sign in with Apple key secrets on the Worker (commands at the
  end of `scripts/deploy-worker.sh`) so account deletion revokes the Apple grant.

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

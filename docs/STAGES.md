# Build stages

UI session, 2026-09-11. Each stage is a commit.

- [x] **0 — Scaffold** — repo, remote `mattypark/vlogify` (no push), `.gitignore`, `.env.example`, XcodeGen spec, privacy manifest, config switch, sample clip, icon renderer
- [x] **1 — Design system** — paper-only OKLCH palette with derived text roles, type, spacing, motion, art slots; `PaletteTests`
- [x] **2 — Engine** — `DayClock` (4 AM), `SlotPing`, `RoomRules`, `InviteCode`, `StitchPlan`; 20+ Swift Testing cases incl. DST
- [x] **3 — Contract + mock** — wire types, eight service protocols, `MockBackend` that says no, `BackendConfig` switch
- [x] **4 — Onboarding** — welcome, Apple (native sheet, mock exchange), Google (system browser), email code, permissions typewriter, profile
- [x] **5 — Home + rooms** — cards with hour dots, pill bar, `+` menu, new-room sheet, invite, join
- [x] **6 — Camera** — AVFoundation capture, orientation, 2 s ring, local-first write, upload, one-per-slot
- [x] **7 — Room + playback + history** — timeline, tiles, clip player, history, past days
- [x] **8 — Compositor + export** — `DayCompositor`, save to Photos, share
- [x] **9 — Profile / safety / legal** — name, in-app language picker, blocked list, report/block, delete account, legal links
- [x] **10 — Notifications** — `HourlyScheduler` plans the day's pings on foreground
- [x] **11 — Localization** — language asked right after sign-in (`LanguageView`), `Localizable.xcstrings` + `InfoPlist.xcstrings`, 172 keys × 6 languages (EN/KO hand-written; JA/zh-Hant/VI/RU drafted, marked needs_review)
- [x] **12 — App Store hardening** — `pre-submit.sh`, `testflight.sh`, `docs/TESTFLIGHT.md`, `docs/APP-STORE-CHECKLIST.md`
- [x] **13 — Companion web** — privacy, terms, support (with form), 404, OG, sitemap, robots, security headers
- [x] **14 — Overnight QA** — `VlogifyUITests` walker + metrics, `qa-matrix.sh`, `overnight.sh`, global rule + guard/audit hooks
- [x] **15 — Handoff** — session docs, paste-ready prompts, this file

- [x] **16 — Alive** — sticker buttons everywhere, seven playful fills, Bagel/Gloria voices, tap bursts on onboarding, paint-blob placeholders
- [x] **17 — Pages** — local-only Notion-style day page (title, blocks, rooms as blocks, clip strip) + room notes
- [x] **18 — Camera extras** — centred stamp, `Aa` font shuffle (burned into export), outline colour = profile colour (rings on tiles, frame, export)
- [x] **19 — App Store Connect record** — record `6811419336`, metadata via MCP, browser-only fields via Chrome

2026-09-28, the ship day:

- [x] **20 — Contract v2** — `Mark`, `Profile.mark`, Apple auth code, one Worker URL, UUID clip ids, upload queue
- [x] **21 — Cloudflare relay** — Worker + D1 + R2 (7-day), `CloudflareBackend`, deploy + seed scripts, 73 tests
- [x] **22 — Ink on paper** — palette, pen outlines, hand face, code-drawn doodles, new icon
- [x] **23 — Draw your mark** — intro, permissions, name, mark canvas, coach marks
- [x] **24 — De-Setlog** — bar, sentence new-room sheet, camera ring, tiles, copy, export signatures
- [x] **25 — App Review hardening** — audit fixes, legal pages, privacy label, age rating
- [ ] **26 — Submit** — attach build 3, Matthew presses Submit

## Open before launch (not this session)

- [x] ~~Artist replaces the 19 art slots~~ — doodles are code now; the mark is the mascot
- [ ] Native review of JA / zh-Hant / VI / RU strings (marked `needs_review` in the catalog)
- [x] Backend (Cloudflare relay, not Supabase)
- [x] Legal pages live on the Worker
- [x] App Store record, age rating, screenshots
- [ ] Physical-device pass: real camera, Photos save, Sign in with Apple sheet

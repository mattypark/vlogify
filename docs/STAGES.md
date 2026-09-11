# Build stages

UI session, 2026-09-11. Each stage is a commit.

- [x] **0 — Scaffold** — repo, remote `mattypark/vlogify` (no push), `.gitignore`, `.env.example`, XcodeGen spec, privacy manifest, config switch, sample clip, icon renderer
- [x] **1 — Design system** — OKLCH palette with derived text roles, type, spacing, motion, art slots; `PaletteTests`
- [x] **2 — Engine** — `DayClock` (4 AM), `SlotPing`, `RoomRules`, `InviteCode`, `StitchPlan`; 20+ Swift Testing cases incl. DST
- [x] **3 — Contract + mock** — wire types, eight service protocols, `MockBackend` that says no, `BackendConfig` switch
- [x] **4 — Onboarding** — welcome, Apple (native sheet, mock exchange), Google (system browser), email code, permissions typewriter, profile
- [x] **5 — Home + rooms** — cards with hour dots, pill bar, `+` menu, new-room sheet, invite, join
- [x] **6 — Camera** — AVFoundation capture, orientation, 2 s ring, local-first write, upload, one-per-slot
- [x] **7 — Room + playback + history** — timeline, tiles, clip player, history, past days
- [x] **8 — Compositor + export** — `DayCompositor`, save to Photos, share
- [x] **9 — Profile / safety / legal** — name, in-app language picker, blocked list, report/block, delete account, legal links
- [x] **10 — Notifications** — `HourlyScheduler` plans the day's pings on foreground
- [x] **11 — Localization** — language asked on first launch (`LanguageView`), `Localizable.xcstrings` + `InfoPlist.xcstrings`, 172 keys × 6 languages (EN/KO hand-written; JA/zh-Hant/VI/RU drafted, marked needs_review)
- [x] **12 — App Store hardening** — `pre-submit.sh`, `testflight.sh`, `docs/TESTFLIGHT.md`, `docs/APP-STORE-CHECKLIST.md`
- [x] **13 — Companion web** — privacy, terms, support (with form), 404, OG, sitemap, robots, security headers
- [x] **14 — Overnight QA** — `VlogifyUITests` walker + metrics, `qa-matrix.sh`, `overnight.sh`, global rule + guard/audit hooks
- [x] **15 — Handoff** — session docs, paste-ready prompts, this file

## Open before launch (not this session)

- [ ] Artist replaces the 19 art slots (`docs/ART-SLOTS.md`); mascot through `ip-as-logo`
- [ ] Native review of JA / zh-Hant / VI / RU strings (marked `needs_review` in the catalog)
- [ ] Backend session: Supabase schema + RLS + edge functions + R2 + APNs (`nextsessions/backend-session.md`)
- [ ] Deploy `web/` so privacy/terms/support return 200 (pre-submit checks this)
- [ ] App Store record, age rating questionnaire, screenshots (`nextsessions/appstore-session.md`)
- [ ] Physical-device pass: real camera, Photos save, Sign in with Apple sheet

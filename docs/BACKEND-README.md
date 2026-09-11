# vlogify — backend session README

Paste this whole file as the first message of the backend session. It is the only
context that session needs beyond the repo itself.

## What vlogify is

A private room of friends all get the same ping once an hour; each shoots a two-second,
one-take clip; the app stitches everyone's day into one video. Solo vlogs have no
limits. The day resets at 4 AM. Free, no ads, no analytics. Six languages.

Repo: `~/Downloads/current-projects/appscurrent/vlogify` → `github.com/mattypark/vlogify`
(Matthew pushes; never push from a session). Native SwiftUI, iOS 18+, Xcode 26.

## What already exists (do not rebuild)

- **The app**, complete and runnable on an on-device mock backend. Every screen works
  with no server: rooms, codes, clips (the simulator "records" a bundled sample),
  stitched export, save to Photos, report/block, delete account, notes (local-only).
- **`ios/VlogifyDesign/Sources/VlogifyContract/`** — the frozen boundary you implement:
  - `WireTypes.swift` — `Profile`, `Room`, `RoomDraft`, `Membership`, `Clip`, `DayLog`,
    `SignedUpload`, `Report`, `Session`, `ContractError`, `EncryptedBlob` (reserved).
    JSON keys are spelled out in snake_case by hand; dates ISO-8601; `DayKey` is
    `2026-09-11`; `InviteCode` is its six characters.
  - `Services.swift` — eight protocols: `AuthService`, `ProfileService`, `RoomService`,
    `ClipService`, `MediaStore`, `PresenceService`, `SafetyService`, `PushService`, bundled
    as `Backend`.
  - `MockBackend.swift` — **the behavioural spec.** Same inputs must give the same
    errors: `roomFull`, `slotAlreadyPosted`, `clipTooLong`, `invalidCode`,
    `invalidEmailCode`, `notOwner`, `notMember`.
  - `BackendConfig.swift` — nil for empty / `$(…)` / non-https; nil means mock.
- **`ios/VlogifyDesign/Sources/VlogifyEngine/`** — pure rules the server must share:
  `DayClock` (4 AM boundary), `SlotPing` (deterministic ping minute), `RoomRules`
  (capacity, 2 s, one-per-slot), `InviteCode` (Crockford + checksum), `StitchPlan`.
- `docs/CONTRACT.md` — the human copy of the contract, tables, invariants, errors.
- `docs/DECISIONS.md` — why things are the way they are. Read before changing anything.
- `.env.example` — every key the backend needs, blank. Matthew fills the real `.env`
  and `ios/Vlogify/Secrets.xcconfig` himself; **never read or write either.**

## What you build

Target stack (decided): **Supabase** (Postgres + RLS + Auth + Realtime + edge
functions) + **Cloudflare R2** (video bytes, presigned PUT/GET) + **Resend** (email
codes) + **APNs** (pings).

1. `supabase/` — `config.toml`, `migrations/0001_init.sql`, `0002_rls.sql`,
   `tests/rls_test.sql`, `scripts/test-db.sh` (copy the idiom from
   `~/Downloads/current-projects/appscurrent/chingo/scripts/test-db.sql`).
   Tables: `profiles(id=auth.uid, display_name, avatar_seed, created_at)`,
   `rooms(id, name, type, capacity, owner_id, invite_code unique, created_at)`,
   `memberships(room_id, user_id, joined_at) pk(room_id,user_id)`,
   `clips(id, room_id, member_id, day, hour, duration_ms, width, height, storage_key, created_at)`
   with `unique(room_id, member_id, day, hour) where type in (log, stack)`,
   `reports`, `blocks(blocker, blocked)`, `push_tokens`.
   RLS: a member reads only rooms they belong to; owners manage; blocks hide both ways.
2. Edge functions: `mint-upload` (presigned R2 PUT, key `room/day/hour-member.mov`),
   `sign-download` (presigned GET, 10 min), `post-clip` (re-enforce ≤2000 ms +250,
   one-per-slot), `join` (capacity + checksum), `delete-account` (rows, R2 objects,
   revoke SIWA token via Apple's REST API), `ping-scheduler` (APNs on the minute from
   `SlotPing`: splitmix-finalised FNV-1a 64 of `"<room_id>|<day>/<hour>"` mod 51;
   reference FNV-1a("a") = `0xaf63dc4c8601ec8c` — verify against
   `VlogifyEngineTests/SlotPingTests.swift`).
3. Auth: Apple (verify identity token + nonce), Google via Supabase OAuth with
   `redirect_to = vlogify://auth/google`, email OTP **sent through Resend** from
   `hello@vlogify.app` (6 digits, 10-minute expiry) with `review@vlogify.app` pinned to
   `000000` for App Review. Ask Matthew before creating the Resend domain/API key.
4. `SupabaseBackend.swift` in `VlogifyContract/` conforming to all eight protocols using
   `URLSession` only (no vendor SDK unless Matthew says so), and the one-line switch in
   `ios/Vlogify/Sources/Services/BackendRoot.swift`.
5. Realtime: `PresenceService.subscribe` on `clips` + `memberships` filtered by room.
6. `ProfileService.update(avatarSeed:)` — a column update; friends see the colour.

## Verifying

```sh
supabase start && scripts/test-db.sh                       # RLS tests, rolled back
swift test --package-path ios/VlogifyDesign                # contract + engine (must stay green)
scripts/run.sh --demo full                                 # app against local Supabase once Secrets.xcconfig points at it
scripts/qa-matrix.sh --only ScreenWalkerTests/testNewRoomAndJoin   # only when Matthew says "test it"
```

## Rules

- The contract is frozen. If a protocol cannot be satisfied, change the protocol first,
  add a DECISIONS.md entry, and say so in your summary. Never let the app quietly adapt.
- Never read, print, or write `.env*` or `Secrets.xcconfig`. Ship `.env.example` updates.
- No localhost in any production config. RLS on every table. R2 buckets never public.
- Do not touch views, the engine, the design system, or the UI tests.
- Commit after every stage; never push. Test suites run only when Matthew asks or overnight.

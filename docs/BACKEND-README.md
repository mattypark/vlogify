# vlogify — the backend

One Cloudflare Worker (`worker/`) is the whole backend: a **relay** that moves clips
between friends. Clips live on the phones; the Worker keeps metadata in D1 and a copy of
each clip in R2 for 7 days. Why it is shaped like this: `docs/DECISIONS.md`, "Cloudflare
relay replaces Supabase". The API, route by route: `docs/CONTRACT.md`.

Repo: `~/Downloads/current-projects/appscurrent/vlogify` → `github.com/mattypark/vlogify`
(Matthew pushes; never push from a session).

## Map

| where | what |
|---|---|
| `worker/src/index.ts` | routes, auth gate on `/v1/*`, error handler |
| `worker/src/routes/` | `auth` (Apple), `account` (me, delete), `rooms`, `clips` (+ media sign), `safety` (reports, blocks), `support` (the web form) |
| `worker/src/media.ts` | Worker-signed upload/playback URLs, byte ranges, 410 for expired copies |
| `worker/src/rules.ts` | TypeScript port of `RoomRules`, `InviteCode`, `DayKey`/`Slot` and the `Mark` decoder |
| `worker/src/auth.ts` | Apple token verification, session JWTs, Apple code exchange + revoke |
| `worker/migrations/` | D1 schema (`0001_init.sql`) |
| `worker/test/` | vitest in the Workers runtime: parity vectors from the Swift tests, IDOR, clips, media, blocks, delete account |
| `ios/VlogifyDesign/Sources/VlogifyContract/Cloudflare/` | `CloudflareBackend`, the Swift client (URLSession only) |
| `ios/Vlogify/Sources/Services/KeychainTokenStore.swift` | where the app keeps the session |
| `scripts/deploy-worker.sh` | from nothing to a live Worker, idempotent |
| `scripts/seed-review-room.sh` | the App Review demo room (code REV-1EF) |
| `docs/MODERATION.md` | reports, bans, the 24-hour promise |

## Run it

```sh
cd worker && npm install
npm test                                   # the Worker's tests (no network, no account)
npx tsc --noEmit                           # types
cp .dev.vars.example .dev.vars             # fill locally (never commit), then:
npx wrangler d1 migrations apply vlogify --local
npx wrangler dev                           # http://localhost:8787
LOCAL=1 ../scripts/seed-review-room.sh 2026-09-29 2026-09-30   # the demo room, locally
```

A debug build can point at `wrangler dev` with `VLOGIFY_API_URL = http:/$()/localhost:8787`
in the gitignored `ios/Vlogify/Secrets.xcconfig` (`BackendConfig` allows http only for
localhost, only in debug). The Swift side:

```sh
swift test --package-path ios/VlogifyDesign     # includes CloudflareBackendTests (stubbed network)
```

## Ship it

```sh
scripts/deploy-worker.sh                         # login, D1, R2 + lifecycle, secrets, migrations, tests, deploy, /health
git add worker/wrangler.toml && git commit       # the D1 id the script wrote in (not a secret)
# ios/Vlogify/Base.xcconfig: VLOGIFY_API_URL = https:/$()/vlogify.<subdomain>.workers.dev
scripts/seed-review-room.sh <day1> <day2>        # the App Review room
```

App Store Connect: Privacy Policy URL `<worker>/privacy`, Support URL `<worker>/support`
(the Worker serves `web/` until there is a domain).

## Secrets

Set with `wrangler secret put`; names in `worker/.dev.vars.example`. Never read, print or
commit a value.

| name | required | what |
|---|---|---|
| `SESSION_SECRET` | yes | signs session tokens (the deploy script generates it) |
| `PEPPER` | yes | HMAC key for Apple subjects; never change it (generated) |
| `MEDIA_SIGNING_KEY` | yes | signs media URLs (generated) |
| `TOKEN_KEY` | yes | AES-256 key sealing Apple refresh tokens (generated) |
| `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY` | no | Sign in with Apple key: lets delete-account revoke Apple's grant |
| `TG_BOT_TOKEN`, `TG_CHAT_ID` | no | Telegram alert on every report and support message |

## Rules for whoever changes it

- The contract is frozen. A route's JSON keys are the Swift `CodingKeys`, by hand.
- `MockBackend` is the behavioural spec: same inputs, same errors. Add a Worker test for
  any rule you touch; `worker/test/rules.test.ts` holds vectors printed by the Swift
  package — regenerate them from Swift, never edit them to make a test pass.
- Dates leave the Worker through `iso()` (no milliseconds).
- Every query that lists people or clips filters blocks both ways.
- Never `wrangler deploy`, create resources or run `--remote` migrations from a session —
  that is `scripts/deploy-worker.sh`, run by Matthew.

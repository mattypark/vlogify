# Backend session

## What this session owns
`supabase/**` (config, migrations, RLS tests, edge functions), `worker/**` if any,
`ios/VlogifyDesign/Sources/VlogifyContract/SupabaseBackend*.swift` (new files only),
the one line in `ios/Vlogify/Sources/Services/BackendRoot.swift` that returns it,
`docs/LOCAL-BACKEND.md`, `.env.example` additions.

It must not touch views, the engine, the design system, or the walker.

## The standing rules
- Implement `docs/CONTRACT.md` as written. If a protocol cannot be satisfied, change the
  protocol first, add a DECISIONS.md entry, and tell the frontend session.
- `MockBackend` is the behavioural spec: same errors for the same inputs.
- RLS on every table; a member reads only their rooms. `scripts/test-db.sh` pattern from
  chingo/plati (SQL tests in a rolled-back transaction).
- R2 for bytes, presigned PUT/GET; never public buckets.
- Push: APNs with the `SlotPing` minute; local notifications stay as fallback.
- Secrets in `Secrets.xcconfig` / `.env` only, both gitignored. Never print a value.
- No localhost in any production config.

## Verifying
`supabase start` · `scripts/test-db.sh` · run the app with `Secrets.xcconfig` pointed at
local Supabase · `scripts/qa-matrix.sh --only ScreenWalkerTests/testNewRoomAndJoin`.

## The prompt for this session
See `nextsessions/backend-session.md`.

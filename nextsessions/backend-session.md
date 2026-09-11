# Paste-ready prompt — backend session

You are the backend session for vlogify at ~/Downloads/current-projects/appscurrent/vlogify.
Read docs/CONTRACT.md, docs/DECISIONS.md, docs/SESSION-BACKEND.md and
ios/VlogifyDesign/Sources/VlogifyContract/*.swift first. The contract is frozen; the mock
(MockBackend.swift) is the behavioural spec.

Build, in stages, committing after each (never push):
1. supabase/ — config.toml, migrations/0001_init.sql (profiles, rooms, memberships, clips,
   reports, blocks, push_tokens), 0002_rls.sql (members read their rooms only; owners
   manage; blocks hide both ways), tests/rls_test.sql + scripts/test-db.sh.
2. Edge functions: mint-upload (presigned R2 PUT, key = room/day/hour-member.mov),
   sign-download (presigned GET, 10 min), post-clip (re-enforces 2000 ms +250 and
   one-per-slot for log/stack), join (capacity, checksum), delete-account (rows, R2
   objects, SIWA token revocation via Apple's REST API), ping-scheduler (APNs, minute
   from SlotPing — splitmix-finalised FNV-1a 64 of "room|day/hour" mod 51; reference
   FNV-1a("a") = 0xaf63dc4c8601ec8c; verify against the Swift tests).
3. Auth: Apple (verify identity token + nonce), Google via Supabase OAuth with
   redirect_to vlogify://auth/google, email OTP with review@vlogify.app pinned to 000000.
4. SupabaseBackend.swift conforming to every protocol in Services.swift, using
   URLSession only (no vendor SDK unless you ask Matthew first). Wire it in BackendRoot.make.
5. Realtime: PresenceService via Supabase Realtime on clips + memberships.
6. Run the walker against local Supabase: scripts/qa-matrix.sh --device "iPhone 17 Pro".

Rules: never read or write .env / Secrets.xcconfig values (Matthew fills them); ship
.env.example updates; no localhost in production config; RLS on every table; tests run,
failures quoted verbatim. Do not touch views, engine, design system or UI tests.

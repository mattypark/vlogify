# The backend contract

`ios/VlogifyDesign/Sources/VlogifyContract/` is the frozen boundary. The backend
session implements it; it does not change it. If something genuinely cannot be
implemented as written, the change is made **here first**, in the Swift protocols, with
a note in DECISIONS.md — never by the app quietly adapting to a server.

## Wire types (`WireTypes.swift`)

All `Codable` + `Sendable`, JSON keys spelled out in snake_case by hand. Dates are
ISO-8601. `DayKey` is the string `2026-09-11`; `InviteCode` is its six characters.

| type | fields | table |
|---|---|---|
| `Profile` | id, display_name, avatar_seed, created_at | `profiles` (id = auth.uid) |
| `Room` | id, name?, type (`log\|stack\|vlog\|zip`), capacity, owner_id, invite_code, created_at | `rooms` |
| `Membership` | room_id, user_id, profile, joined_at | `memberships` (pk room_id+user_id) |
| `Clip` | id, room_id, member_id, day, hour (4…27), duration_ms, width, height, storage_key, created_at | `clips` (unique room_id+member_id+day+hour for log/stack) |
| `DayLog` | room_id, day, members[], clips[] | a query, not a table |
| `SignedUpload` | url, headers, storage_key, expires_at | minted by an edge function |
| `Report` | reporter_id, clip_id?, user_id?, reason, note?, created_at | `reports` |
| `Block` (via `SafetyService`) | blocker, blocked | `blocks` |
| `Session` | user_id, provider, issued_at | Supabase session |
| `EncryptedBlob` | ciphertext, nonce, wrapped_key_id | **reserved, v2** |

## Services (`Services.swift`)

- `AuthService` — Apple (identity token + raw nonce; verify with Apple), Google via an
  authorize URL the app opens in `ASWebAuthenticationSession` with callback scheme
  `vlogify://auth/google`, email one-time code (**sent via Resend** from
  `hello@vlogify.app`; six digits, 10-minute expiry, `review@vlogify.app` pinned to
  `000000`), `signOut`, **`deleteAccount`** (must revoke the SIWA token server-side —
  5.1.1(v)).
- `ProfileService` — `me`, `update(displayName:)`, `update(avatarSeed:)` (0…11; the user's colour, shown to rooms).
- `RoomService` — `rooms`, `room(id:)`, `create`, `preview(code:)` (no join), `join(code:)`,
  `leave`, `members`, `removeMember` (owner only), `regenerateInvite` (owner only).
- `ClipService` — `post` (metadata after bytes are stored; **server re-enforces** 2 s
  and one-per-slot), `day(roomID:day:)`, `history(roomID:)` (days with ≥1 clip, newest
  first), `delete(clipID:)` (own only).
- `MediaStore` — `uploadURL(for:)` → presigned PUT to R2, `upload(fileURL:to:)`,
  `downloadURL(storageKey:)` → short-lived presigned GET.
- `PresenceService` — `subscribe(roomID:)` → `AsyncStream<RoomEvent>` (Supabase Realtime
  on `clips` + `memberships` filtered by room).
- `SafetyService` — `report`, `block`, `unblock`, `blocked`. Blocking hides both ways.
- `PushService` — `register(deviceToken:)`, `unregister`.

## Invariants the server must share with the phone

1. **The day starts at 4 AM in the poster's time zone.** `day` and `hour` are computed
   on the phone with `DayClock` and sent as fields; the server stores them, it does not
   recompute from `created_at`.
2. **The ping minute is `SlotPing.minute(room:slot:)`** — splitmix-finalised FNV-1a 64 of
   `"<room_id>|<day>/<hour>"`, mod 51. A push scheduler must use the identical function
   (reference vector: FNV-1a("a") = 0xaf63dc4c8601ec8c). Both phones and server agree
   with no round-trip.
3. **Capacity**: log 2–20, stack ≤40, vlog 1. `join` fails with `roomFull` at capacity.
4. **Clip length**: log/stack ≤ 2 000 ms (+250 ms tolerance); vlog unlimited.
5. **One clip per member per slot** in log/stack; unlimited in vlog.
6. **Invite codes** are Crockford base32 with a check character (`InviteCode`); the
   server validates the checksum too and treats codes as case-insensitive.
7. **Blocking** removes the blocked member's clips and membership from every response
   to the blocker, and vice versa.
8. **Delete account** removes profile, memberships, owned rooms and every clip the user
   posted (and the R2 objects), then revokes the SIWA refresh token.

## Errors

`ContractError`: notSignedIn, roomFull, roomNotFound, invalidCode, slotAlreadyPosted,
clipTooLong, notOwner, notMember, invalidEmailCode, network. Map HTTP/PostgREST errors
onto these; the UI shows copy per case.

## Configuration switch

`ios/Vlogify/Secrets.xcconfig` (gitignored) sets `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
`MEDIA_BASE_URL`. `BackendConfig` returns nil for empty / `$(…)` / non-https values, and
nil means `MockBackend`. `BackendRoot.make` is the one line to change.

## The mock is the reference

`MockBackend` enforces every invariant above and is what `MockBackendTests` and the
overnight walker run against. When in doubt about behaviour, the mock is the spec.

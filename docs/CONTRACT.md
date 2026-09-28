# The backend contract

`ios/VlogifyDesign/Sources/VlogifyContract/` is the frozen boundary. The backend
implements it; it does not change it. If something genuinely cannot be implemented as
written, the change is made **here first**, in the Swift protocols, with a note in
DECISIONS.md — never by the app quietly adapting to a server.

Two implementations satisfy it: `MockBackend` (on-device, the behavioural spec) and
`CloudflareBackend` (`Cloudflare/`, the client for the Worker in `worker/`).

## Wire types (`WireTypes.swift`)

All `Codable` + `Sendable`, JSON keys spelled out in snake_case by hand. Dates are
ISO-8601 **without fractional seconds** (`2026-09-28T17:05:00Z`; the app's decoder rejects
milliseconds). `DayKey` is the string `2026-09-11`; `InviteCode` is its six characters.

| type | fields | D1 table |
|---|---|---|
| `Profile` | id, display_name, avatar_seed (0…11), mark?, created_at | `profiles` |
| `Room` | id, name?, type (`log\|stack\|vlog\|zip`), capacity, owner_id, invite_code, created_at | `rooms` |
| `RoomDraft` | name?, type, capacity | — |
| `Membership` | room_id, user_id, profile, joined_at | `memberships` (pk room_id+user_id) |
| `Clip` | id, room_id, member_id, day, hour (4…27), duration_ms, width, height, storage_key, created_at | `clips` (+ status pending/posted) |
| `DayLog` | room_id, day, members[], clips[] | a query |
| `SignedUpload` | url, headers, storage_key, expires_at | minted by the Worker |
| `Report` | reporter_id, clip_id?, user_id?, reason, note?, created_at | `reports` |
| `Session` | user_id, provider, issued_at | the session JWT's claims |
| `EncryptedBlob` | ciphertext, nonce, wrapped_key_id | **reserved, v2** |

`mark` is the drawn doodle in its wire form (`Mark.swift`: base64url of version byte 1,
then per stroke a u8 count and that many u8 x,y pairs; ≤ 64 strokes, ≤ 640 points,
≤ 1800 characters). The Worker decodes it before storing and refuses one the app could
not draw. An absent mark is omitted from the JSON.

## HTTP API (the Worker)

Base URL: `VLOGIFY_API_URL` (`https://vlogify.<subdomain>.workers.dev`). Every `/v1` route
except `/v1/auth/*` needs `Authorization: Bearer <token>`. Bodies are JSON with the wire
keys above.

| protocol method | route | body → response |
|---|---|---|
| `AuthService.signInWithApple` | `POST /v1/auth/apple` | `{identity_token, nonce, authorization_code?, full_name?}` → `{token, session}` |
| Google / email methods | `/v1/auth/google/*`, `/v1/auth/email/*` | → 501 `unsupported` (the client throws without calling) |
| `AuthService.deleteAccount` | `DELETE /v1/account` | → 204 |
| `ProfileService.me` | `GET /v1/me` | → `Profile` |
| `ProfileService.update(…)` | `PATCH /v1/me` | any of `{display_name, avatar_seed, mark}` → `Profile` |
| `RoomService.rooms` | `GET /v1/rooms` | → `[Room]`, newest first |
| `RoomService.create` | `POST /v1/rooms` | `RoomDraft` → 201 `Room` |
| `RoomService.room(id:)` | `GET /v1/rooms/:id` | → `Room` |
| `RoomService.preview(code:)` | `GET /v1/rooms/preview/:code` | → `{room, member_count}` |
| `RoomService.join(code:)` | `POST /v1/rooms/join` | `{code}` → `Room` |
| `RoomService.leave` | `POST /v1/rooms/:id/leave` | → 204 |
| `RoomService.members` | `GET /v1/rooms/:id/members` | → `[Membership]` |
| `RoomService.removeMember` | `DELETE /v1/rooms/:id/members/:userId` | → 204 (owner) |
| `RoomService.regenerateInvite` | `POST /v1/rooms/:id/invite` | → `{invite_code}` (owner) |
| `MediaStore.uploadURL(for:)` | `POST /v1/clips/upload-url` | `{clip}` → `SignedUpload` |
| `MediaStore.upload` | `PUT <SignedUpload.url>` | file bytes with `SignedUpload.headers`, no bearer → 204 |
| `ClipService.post` | `POST /v1/clips` | `{clip}` → 201 `Clip` (200 with the first post on a repeat) |
| `ClipService.day` | `GET /v1/rooms/:id/days/:day` | → `DayLog` |
| `ClipService.history` | `GET /v1/rooms/:id/history` | → `[DayKey]`, newest first |
| `ClipService.delete` | `DELETE /v1/clips/:id` | → 204 (own clip) |
| `MediaStore.downloadURL` | `GET /v1/media/sign?key=` | → `{url, expires_at}`; the url is `GET /media/<key>?exp&sig` |
| `SafetyService.report` | `POST /v1/reports` | `Report` → 204 |
| `SafetyService.block` / `unblock` | `POST /v1/blocks` `{user_id}` / `DELETE /v1/blocks/:userId` | → 204 |
| `SafetyService.blocked` | `GET /v1/blocks` | → `[Profile]` |
| `PushService` | `POST`/`DELETE /v1/push/register` | → 204, no-op (the client does not call it) |
| `PresenceService.subscribe` | polls `GET /v1/rooms/:id/days/<today>` every 30 s | yields joins, leaves, new clips |

Path components are percent-encoded one by one: a clip id may contain `/` (the camera
builds ids from the slot key, `<day>/<hour>`) and travels as `%2F`.

Media: upload URLs live 10 minutes, playback URLs an hour. Playback serves byte ranges
(AVPlayer needs them). An upload is capped at 25 MB for log/stack rooms, 100 MB for vlogs.

## Services (`Services.swift`)

- `AuthService` — Apple only in v1: identity token + raw nonce (the Worker checks Apple's
  signature, the bundle id, and that the token's nonce is SHA-256 of the raw one). The
  authorization code is exchanged once for the refresh token that `deleteAccount` revokes
  (5.1.1(v)), when the Apple key secrets are set. Google and email throw `.unsupported`
  until there is a domain. `signOut` forgets the token locally.
- `ProfileService` — `me`, `update(displayName:)` (trimmed, ≤ 20 characters),
  `update(avatarSeed:)` (any integer, wrapped to 0…11), `update(mark:)`.
- `RoomService` — `rooms`, `room(id:)`, `create`, `preview(code:)` (no join), `join(code:)`
  (idempotent), `leave`, `members`, `removeMember` (owner only), `regenerateInvite` (owner only).
- `ClipService` — `post` (after the bytes are uploaded; **the server re-enforces** 2 s and
  one-per-slot), `day(roomID:day:)`, `history(roomID:)`, `delete(clipID:)` (own only).
- `MediaStore` — `uploadURL(for:)`, `upload(fileURL:to:)`, `downloadURL(storageKey:)`.
- `PresenceService` — `subscribe(roomID:)` → `AsyncStream<RoomEvent>`, by polling.
- `SafetyService` — `report`, `block`, `unblock`, `blocked`. Blocking hides both ways.
- `PushService` — `register(deviceToken:)`, `unregister`: no-ops in v1 (pings are local).

## Invariants the server shares with the phone

1. **The day starts at 4 AM in the poster's time zone.** `day` and `hour` are computed on
   the phone with `DayClock` and sent as fields; the server stores them, it does not
   recompute them. It only checks that `hour` is 4…27 and `day` is a real date within
   `CLIP_TTL_DAYS` back and one day ahead of today (UTC).
2. **The ping minute is `SlotPing.minute(room:slot:)`**, computed on each phone. v1 has no
   server pings.
3. **Capacity**: log 2–20, stack 2–40, vlog 1, zip 2. A draft outside that is `roomFull`
   (as in the mock); `join` at capacity is `roomFull`.
4. **Clip length**: log/stack ≤ 2 000 ms + 250 ms tolerance; vlog/zip unlimited.
5. **One clip per member per slot** in log/stack (checked, and a partial unique index);
   unlimited in vlog.
6. **Invite codes** are Crockford base32 with a check character (`InviteCode`); the server
   validates the checksum, maps I/L→1 and O→0, ignores case and dashes.
7. **Blocking** removes the other person's membership and clips from every response to
   both of them.
8. **Posting is idempotent on clip id**: the same member posting the same id again gets the
   first post back.
9. **Delete account** removes the profile, memberships, owned rooms (with every clip in
   them), every clip the user posted and its R2 copy, blocks both ways, then revokes the
   Sign in with Apple token.
10. **Clip copies are temporary.** R2 keeps `clips/` objects for 7 days; rows stay. A
    playback URL for an expired copy answers 410 and the app plays its local copy.

## Errors

The Worker answers every refusal as `{ "error": "<code>" }`. `CloudflareBackend` maps:

| code | status | `ContractError` |
|---|---|---|
| `not_signed_in`, `banned` | 401 / 403 | `.notSignedIn` (the stored session is cleared) |
| `not_member` | 403 | `.notMember` |
| `not_owner` | 403 | `.notOwner` |
| `room_not_found` | 404 | `.roomNotFound` |
| `invalid_code` | 404 | `.invalidCode` |
| `room_full` | 409 | `.roomFull` |
| `slot_already_posted` | 409 | `.slotAlreadyPosted` |
| `clip_too_long` | 422 | `.clipTooLong` |
| `rate_limited` | 429 | `.rateLimited` (ten wrong codes per 15 minutes) |
| `unsupported` | 501 | `.unsupported` |
| `bad_request`, `bad_signature`, `too_large`, `gone`, `not_found`, `server_error`, no body | 400–5xx | `.network` |

A room that does not exist and a room you are not in both answer `not_member`, and an
unknown clip id on delete answers `not_owner`, exactly as the mock does — ids cannot be
probed.

## Configuration switch

`VLOGIFY_API_URL` in `ios/Vlogify/Base.xcconfig` (committed: a URL is not a secret). Blank,
`$(…)`, or non-https means `MockBackend`; UI tests and `-vlogifyDemo` always get the mock.
`BackendRoot.make` returns `CloudflareBackend(config:tokens: KeychainTokenStore())`
otherwise. xcconfig treats `//` as a comment, so the value is written
`https:/$()/vlogify.<subdomain>.workers.dev`.

## The mock is the reference

`MockBackend` enforces every invariant above and is what `MockBackendTests` and the
overnight walker run against. When in doubt about behaviour, the mock is the spec; the
Worker's tests (`worker/test/`) check the same rules against the real routes.

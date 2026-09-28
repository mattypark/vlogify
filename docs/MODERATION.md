# Moderation

App Review Guideline 1.2 (user-generated content) asks for four things: a way to report
content, a way to block people, a way to filter it, and **action on reports within 24
hours**. The app has the first two on every member and clip; this is the third and
fourth: what happens after someone taps report, and what the moderator runs.

## The promise

- Every report is looked at **within 24 hours** of arriving.
- Content that breaks the terms (harassment, nudity, violence, spam, impersonation) is
  removed, and a person who posted it is banned, in the same sitting.
- Support messages from `/support` are answered within two days (the page says so).

## How a report arrives

1. Someone reports a clip or a person in the app. The app sends `POST /v1/reports`.
2. The Worker writes a row to D1 `reports`: reporter, the clip (and its room and R2 key)
   or the person, the reason, their note, the time. The reporter must be in the clip's
   room, so a report cannot be used to probe ids.
3. **The reporter stops seeing the clip at once** -- the day log filters out every clip
   its viewer reported. Blocking hides both people from each other everywhere.
4. If `TG_BOT_TOKEN` and `TG_CHAT_ID` are set on the Worker, a Telegram message arrives
   with the report id, reason, clip and user. Without them, check the queue daily.

Support-form messages land in D1 `support_messages` the same way (and alert the same
Telegram chat).

## The queries

Run from `worker/` (or add `--config worker/wrangler.toml`). Every command reads or writes
production -- read the row before you change it.

**Open reports, oldest first**

```sh
npx wrangler d1 execute vlogify --remote --command "SELECT id, created_at, reason, clip_id, user_id, room_id, storage_key, note FROM reports WHERE resolved_at IS NULL ORDER BY created_at"
```

**Watch a reported clip** (copy it out of R2; clips/ copies expire after 7 days)

```sh
npx wrangler r2 object get "vlogify-clips/<storage_key>" --remote --file ~/Downloads/report-<id>.mov
```

**Who is this person** (reports against them, what they post, where)

```sh
npx wrangler d1 execute vlogify --remote --command "SELECT u.id, u.created_at, u.banned_at, p.display_name, (SELECT COUNT(*) FROM reports r WHERE r.user_id = u.id) AS reports_against, (SELECT COUNT(*) FROM clips c WHERE c.member_id = u.id) AS clips, (SELECT COUNT(*) FROM memberships m WHERE m.user_id = u.id) AS rooms FROM users u JOIN profiles p ON p.id = u.id WHERE u.id = '<user_id>'"
```

**Remove one clip** (row, then the R2 copy)

```sh
npx wrangler d1 execute vlogify --remote --command "DELETE FROM clips WHERE id = '<clip_id>'"
npx wrangler r2 object delete "vlogify-clips/<storage_key>" --remote
```

**Ban a person.** Their sessions stop working on the next request and the same Apple ID
cannot sign in again (the identity row is kept, marked banned). Then remove what they
posted and take them out of every room:

```sh
# 1. Ban.
npx wrangler d1 execute vlogify --remote --command "UPDATE users SET banned_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now') WHERE id = '<user_id>'"

# 2. List their clips' R2 keys, then delete each one (skip demo/ keys).
npx wrangler d1 execute vlogify --remote --command "SELECT storage_key FROM clips WHERE member_id = '<user_id>' AND storage_key LIKE 'clips/%'"
npx wrangler r2 object delete "vlogify-clips/<storage_key>" --remote     # once per key

# 3. Delete their clips, hand rooms they own to the next member, drop rooms nobody else is in,
#    and take them out of every room.
npx wrangler d1 execute vlogify --remote --command "DELETE FROM clips WHERE member_id = '<user_id>'; DELETE FROM rooms WHERE owner_id = '<user_id>' AND NOT EXISTS (SELECT 1 FROM memberships m WHERE m.room_id = rooms.id AND m.user_id != '<user_id>'); UPDATE rooms SET owner_id = (SELECT m.user_id FROM memberships m WHERE m.room_id = rooms.id AND m.user_id != '<user_id>' ORDER BY m.joined_at LIMIT 1) WHERE owner_id = '<user_id>'; DELETE FROM memberships WHERE user_id = '<user_id>'"
```

Dropping a room in step 3 also drops the other clips in it (there are none from anyone
still in it, by definition) -- list `SELECT storage_key FROM clips WHERE room_id IN (SELECT id FROM rooms WHERE owner_id = '<user_id>')`
first if you want to delete those R2 copies too; otherwise they expire within 7 days.

**Unban**

```sh
npx wrangler d1 execute vlogify --remote --command "UPDATE users SET banned_at = NULL WHERE id = '<user_id>'"
```

**Close a report** (after acting, or deciding it needs no action)

```sh
npx wrangler d1 execute vlogify --remote --command "UPDATE reports SET resolved_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now') WHERE id = '<report_id>'"
```

**Reports older than 24 hours still open** (should always be empty)

```sh
npx wrangler d1 execute vlogify --remote --command "SELECT id, created_at, reason FROM reports WHERE resolved_at IS NULL AND created_at < strftime('%Y-%m-%dT%H:%M:%SZ', 'now', '-1 day')"
```

**Support messages**

```sh
npx wrangler d1 execute vlogify --remote --command "SELECT id, created_at, email, message FROM support_messages WHERE resolved_at IS NULL ORDER BY created_at"
npx wrangler d1 execute vlogify --remote --command "UPDATE support_messages SET resolved_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now') WHERE id = '<id>'"
```

## What the moderator cannot do

- **Write back to a reporter in the app.** Sign in with Apple gives the Worker no email
  address, and none is stored. A reporter who wants an answer writes through `/support`.
- **See clips older than 7 days.** R2 copies expire; the phones keep theirs. A report on
  an old clip is judged on the reporter's note and the person's recent clips.
- **See private notes.** Notes never leave the phone.

## If a report is about the App Review demo room

The room `demo-review-room` and its three people (`demo-matthew`, `demo-jiwoo`,
`demo-sam`) are seeded by `scripts/seed-review-room.sh`; nobody can sign in as them. Close
the report; there is no one to ban.

## What the app does on its own (2026-09-28)

- A clip with an **open** report is hidden from everyone in its room at once; resolving the
  report (`UPDATE reports SET resolved_at = …`) brings it back for everyone except the
  person who reported it. Removing it for good: delete the clip row and its R2 object
  (commands above), or ban the account.
- Display names and room names go through `worker/src/filter.ts` (masking, not refusing).
- Reports are limited to 20 an hour per person; the support form to 3 an hour per address.


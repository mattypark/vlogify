-- The relay's metadata. Video bytes are never here: they are on the phones, and a copy sits in
-- R2 under clips/ for seven days. Every table that belongs to a person cascades from users, so
-- deleting the users row is most of account deletion (the R2 objects are the rest).
--
-- D1 enforces foreign keys. Dates are ISO-8601 strings without milliseconds, the shape the
-- app's decoder accepts.

CREATE TABLE users (
  id         TEXT PRIMARY KEY,
  created_at TEXT NOT NULL,
  -- Set by a moderator (docs/MODERATION.md). A banned account's sessions stop working and it
  -- cannot sign in again with the same Apple ID.
  banned_at  TEXT
);

-- A sign-in door into an account. Only HMAC(PEPPER, apple sub) is kept, never the sub.
CREATE TABLE identities (
  sub_hash   TEXT PRIMARY KEY,
  user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider   TEXT NOT NULL CHECK (provider IN ('apple', 'google', 'email')),
  created_at TEXT NOT NULL
);
CREATE INDEX identities_user ON identities(user_id);

CREATE TABLE profiles (
  id           TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL DEFAULT '',
  avatar_seed  INTEGER NOT NULL DEFAULT 0 CHECK (avatar_seed BETWEEN 0 AND 11),
  -- The drawn mark, in the wire form Mark.swift defines. Validated by decoding before it lands.
  mark         TEXT CHECK (mark IS NULL OR length(mark) <= 1800),
  created_at   TEXT NOT NULL
);

-- Kept only so deleting the account can revoke Apple's grant (guideline 5.1.1(v)).
CREATE TABLE apple_tokens (
  user_id     TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  client_id   TEXT NOT NULL,
  refresh_enc TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);

CREATE TABLE rooms (
  id          TEXT PRIMARY KEY,
  name        TEXT,
  type        TEXT NOT NULL CHECK (type IN ('log', 'stack', 'vlog', 'zip')),
  capacity    INTEGER NOT NULL CHECK (capacity >= 1),
  owner_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  invite_code TEXT NOT NULL UNIQUE,
  created_at  TEXT NOT NULL
);
CREATE INDEX rooms_owner ON rooms(owner_id);

CREATE TABLE memberships (
  room_id   TEXT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  user_id   TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at TEXT NOT NULL,
  PRIMARY KEY (room_id, user_id)
);
CREATE INDEX memberships_user ON memberships(user_id);

-- One row per clip id (a client UUID). 'pending' from the moment an upload URL is minted,
-- 'posted' once the bytes are in R2 and the rules passed. Rows outlive their R2 objects so
-- history still lists the days; a gone object answers 410 and the app plays its own copy.
CREATE TABLE clips (
  id           TEXT PRIMARY KEY,
  room_id      TEXT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  member_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  day          TEXT NOT NULL,
  hour         INTEGER NOT NULL CHECK (hour BETWEEN 4 AND 27),
  duration_ms  INTEGER NOT NULL CHECK (duration_ms >= 0),
  width        INTEGER NOT NULL,
  height       INTEGER NOT NULL,
  storage_key  TEXT NOT NULL,
  status       TEXT NOT NULL CHECK (status IN ('pending', 'posted')),
  -- 1 for room types with one capture per slot (log, stack). Copied from the room at post
  -- time so the index below can enforce the rule without a join.
  one_per_slot INTEGER NOT NULL DEFAULT 0,
  created_at   TEXT NOT NULL
);
CREATE INDEX clips_room_day ON clips(room_id, day);
CREATE INDEX clips_member ON clips(member_id);
CREATE INDEX clips_storage_key ON clips(storage_key);
-- The database's copy of "one clip per member per slot": two posts racing each other cannot
-- both land.
CREATE UNIQUE INDEX clips_one_per_slot ON clips(room_id, member_id, day, hour)
  WHERE status = 'posted' AND one_per_slot = 1;

-- Moderation records. No foreign keys on purpose: a report outlives the clip it names and the
-- account that filed it, so the moderator still sees what happened.
CREATE TABLE reports (
  id          TEXT PRIMARY KEY,
  reporter_id TEXT NOT NULL,
  clip_id     TEXT,
  user_id     TEXT,
  room_id     TEXT,
  storage_key TEXT,
  reason      TEXT NOT NULL CHECK (reason IN ('harassment', 'nudity', 'violence', 'spam', 'impersonation', 'other')),
  note        TEXT,
  created_at  TEXT NOT NULL,
  resolved_at TEXT
);
CREATE INDEX reports_reporter ON reports(reporter_id);
CREATE INDEX reports_open ON reports(resolved_at, created_at);

-- Blocking hides both ways: every query that lists people or clips checks both directions.
CREATE TABLE blocks (
  blocker    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL,
  PRIMARY KEY (blocker, blocked)
);
CREATE INDEX blocks_blocked ON blocks(blocked);

-- Invite-code lookups per person, for the rate limit on guessing codes.
CREATE TABLE join_attempts (
  id      INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  ok      INTEGER NOT NULL,
  at      TEXT NOT NULL
);
CREATE INDEX join_attempts_user_at ON join_attempts(user_id, at);

-- The support form on /support.
CREATE TABLE support_messages (
  id          TEXT PRIMARY KEY,
  email       TEXT NOT NULL,
  message     TEXT NOT NULL,
  created_at  TEXT NOT NULL,
  resolved_at TEXT
);

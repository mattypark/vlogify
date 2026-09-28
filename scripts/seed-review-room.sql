-- The App Review demo room. Applied by scripts/seed-review-room.sh, which substitutes
-- {{DAY1}} and {{DAY2}} (app days, 2026-09-29) and uploads demo/sample-clip.mov.
--
-- Three demo people who can never sign in (no identities row), one log room with a fixed
-- invite code and room for the reviewer, and a day and a morning of clips. Every statement is
-- idempotent: running the script again refreshes names, marks and the code, and adds nothing
-- twice. All clips share one R2 object under demo/, which the lifecycle rule on clips/ never
-- touches and the Worker never deletes.

INSERT OR IGNORE INTO users (id, created_at) VALUES
  ('demo-matthew', '{{DAY1}}T00:00:00Z'),
  ('demo-jiwoo', '{{DAY1}}T00:00:00Z'),
  ('demo-sam', '{{DAY1}}T00:00:00Z');

-- Marks are Mark.sample(0), (1), (2) exactly as Mark.swift encodes them: a face, a star,
-- a spiral.
INSERT INTO profiles (id, display_name, avatar_seed, mark, created_at) VALUES
  ('demo-matthew', 'matthew', 7, 'AR3bgNmU0qfHubnHp9KU2YDba9lY0kbHOLktpyaUJIAmay1YOEZGOFgtayZ_JJQmpy25OMdG0ljZa9t_AWFrAZ5rDaaRo5meoJilkKqIrICtd6xvqmelYaBcmVmR', '{{DAY1}}T00:00:00Z'),
  ('demo-jiwoo', 'jiwoo', 2, 'AQaAH7vXHmXhZUTXfx8', '{{DAY1}}T00:00:00Z'),
  ('demo-sam', 'sam', 11, 'AT2AgIGAgoGDg4OFgoiAinyLeYt1inGIbYRrgGp6a3RtbXJoeGSAYYhgkGKZZqBtpXWof6mKppagoJepjK-As3KyZK9Yp02cRo9CgENvSF9RUV1FbTx_OJI5pT-2ScNYzWvRf9CVyaq9vazMl9eA22faUNI7xCqxH5kZgA', '{{DAY1}}T00:00:00Z')
ON CONFLICT(id) DO UPDATE SET display_name = excluded.display_name, avatar_seed = excluded.avatar_seed, mark = excluded.mark;

-- REV1EF is a valid code (check character F, verified against InviteCode.swift). Capacity 6:
-- three demo people, the reviewer, and room to spare for a second reviewer device.
INSERT INTO rooms (id, name, type, capacity, owner_id, invite_code, created_at) VALUES
  ('demo-review-room', 'app review', 'log', 6, 'demo-matthew', 'REV1EF', '{{DAY1}}T00:00:00Z')
ON CONFLICT(id) DO UPDATE SET name = excluded.name, capacity = excluded.capacity, owner_id = excluded.owner_id,
  invite_code = excluded.invite_code;

INSERT OR IGNORE INTO memberships (room_id, user_id, joined_at) VALUES
  ('demo-review-room', 'demo-matthew', '{{DAY1}}T00:00:00Z'),
  ('demo-review-room', 'demo-jiwoo', '{{DAY1}}T00:01:00Z'),
  ('demo-review-room', 'demo-sam', '{{DAY1}}T00:02:00Z');

-- Day one: 8 AM to 10 PM, everyone most hours; each person skips a different hour, as the
-- mock seeds it, because an empty tile is a state the reviewer should see.
WITH RECURSIVE
  hours(h) AS (SELECT 8 UNION ALL SELECT h + 1 FROM hours WHERE h < 22),
  people(idx, id) AS (VALUES (0, 'demo-matthew'), (1, 'demo-jiwoo'), (2, 'demo-sam'))
INSERT OR IGNORE INTO clips (id, room_id, member_id, day, hour, duration_ms, width, height, storage_key, status, one_per_slot, created_at)
SELECT 'demo-{{DAY1}}-' || p.id || '-' || h, 'demo-review-room', p.id, '{{DAY1}}', h, 2000, 1080, 1920,
       'demo/sample-clip.mov', 'posted', 1, '{{DAY1}}T' || printf('%02d', h) || ':05:00Z'
  FROM hours, people p
 WHERE (h + p.idx) % 7 != 0;

-- Day two: just the early morning, so whatever hour the reviewer opens the room, the clips
-- are in the past and the current hour is theirs to post.
WITH RECURSIVE
  hours(h) AS (SELECT 6 UNION ALL SELECT h + 1 FROM hours WHERE h < 8),
  people(idx, id) AS (VALUES (0, 'demo-matthew'), (1, 'demo-jiwoo'), (2, 'demo-sam'))
INSERT OR IGNORE INTO clips (id, room_id, member_id, day, hour, duration_ms, width, height, storage_key, status, one_per_slot, created_at)
SELECT 'demo-{{DAY2}}-' || p.id || '-' || h, 'demo-review-room', p.id, '{{DAY2}}', h, 2000, 1080, 1920,
       'demo/sample-clip.mov', 'posted', 1, '{{DAY2}}T' || printf('%02d', h) || ':05:00Z'
  FROM hours, people p
 WHERE (h + p.idx) % 7 != 0;

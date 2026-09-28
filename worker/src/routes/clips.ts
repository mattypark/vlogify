import { Hono } from "hono";
import { z } from "zod";
import { blockedEitherWay, CLIP_PREFIX, clipJSON, deleteObjects, requireMemberRoom, type ClipRow, type RoomRow } from "../db";
import type { AppEnv, Env } from "../env";
import { fail } from "../errors";
import { originOf, readBody } from "../http";
import { CLIP_CONTENT_TYPE, DOWNLOAD_TTL_SECONDS, pathTail, signDownloadURL, signUploadURL, UPLOAD_TTL_SECONDS } from "../media";
import { capturesPerSlot, isClipTooLong, isDayInWindow, isValidHour } from "../rules";
import { iso } from "../util";

export const clipRoutes = new Hono<AppEnv>();
export const mediaRoutes = new Hono<AppEnv>();

/// `Clip` as WireTypes.swift encodes it. Clip ids come from the phone and end up in R2 keys and
/// (percent-encoded) in URL paths: letters, digits, "-", "_" and "/" -- the app builds ids from
/// the slot key, which is "<day>/<hour>". No dots, so never "..".
export const CLIP_ID = /^[A-Za-z0-9_\-/]{1,200}$/;
export const WireClip = z.object({
  id: z.string().regex(CLIP_ID),
  room_id: z.string().min(1).max(100),
  member_id: z.string().max(100),
  day: z.string().max(10),
  hour: z.number().int(),
  duration_ms: z.number().int().min(0).max(3_600_000),
  width: z.number().int().min(0).max(20_000),
  height: z.number().int().min(0).max(20_000),
  storage_key: z.string().max(500),
  created_at: z.string().max(40),
});
type WireClip = z.infer<typeof WireClip>;
const Envelope = z.object({ clip: WireClip });

function ttlDays(env: Env): number {
  const days = Number(env.CLIP_TTL_DAYS);
  return Number.isFinite(days) && days > 0 ? days : 7;
}

/// Where a clip's bytes go. Built here, never taken from the client: one object per clip id,
/// so a vlog's second clip in an hour never overwrites its first.
export function storageKeyFor(roomId: string, day: string, clipId: string): string {
  return `${CLIP_PREFIX}${roomId}/${day}/${clipId}.mov`;
}

/// Shape checks that need no database: a real day near now, an hour of the app-day.
function checkShape(env: Env, clip: WireClip): void {
  if (!isValidHour(clip.hour)) fail("bad_request", "hour outside 4...27");
  if (!isDayInWindow(clip.day, new Date(), ttlDays(env))) fail("bad_request", "day outside the window");
}

function createdAt(clip: WireClip): string {
  const parsed = Date.parse(clip.created_at);
  return iso(Number.isFinite(parsed) ? new Date(parsed) : new Date());
}

/// Another posted clip of this member's in this slot, for room types with one per slot.
async function slotTaken(env: Env, room: RoomRow, userId: string, clip: WireClip): Promise<boolean> {
  if (capturesPerSlot(room.type) === null) return false;
  const other = await env.DB.prepare(
    `SELECT 1 AS taken FROM clips WHERE room_id = ? AND member_id = ? AND day = ? AND hour = ?
       AND status = 'posted' AND id != ? LIMIT 1`,
  ).bind(room.id, userId, clip.day, clip.hour, clip.id).first();
  return other !== null;
}

async function clipRow(env: Env, clipId: string): Promise<ClipRow | null> {
  return env.DB.prepare("SELECT * FROM clips WHERE id = ?").bind(clipId).first<ClipRow>();
}

/// Mints the upload URL and records the clip as pending. The same rules as posting run first,
/// so a clip that could never be posted is refused before any bytes move.
clipRoutes.post("/upload-url", async (c) => {
  const userId = c.get("userId");
  const { clip } = await readBody(c, Envelope);
  checkShape(c.env, clip);
  const room = await requireMemberRoom(c.env, clip.room_id, userId);
  if (isClipTooLong(room.type, clip.duration_ms)) fail("clip_too_long");
  if (await slotTaken(c.env, room, userId, clip)) fail("slot_already_posted");

  const key = storageKeyFor(room.id, clip.day, clip.id);
  const onePerSlot = capturesPerSlot(room.type) === null ? 0 : 1;
  // A retry refreshes a pending row; a posted row, or someone else's id, is left alone.
  await c.env.DB.prepare(
    `INSERT INTO clips (id, room_id, member_id, day, hour, duration_ms, width, height, storage_key, status, one_per_slot, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?)
     ON CONFLICT(id) DO UPDATE SET hour = excluded.hour, duration_ms = excluded.duration_ms, width = excluded.width,
       height = excluded.height, created_at = excluded.created_at
     WHERE clips.status = 'pending' AND clips.member_id = excluded.member_id
       AND clips.room_id = excluded.room_id AND clips.day = excluded.day`,
  ).bind(clip.id, room.id, userId, clip.day, clip.hour, clip.duration_ms, clip.width, clip.height, key, onePerSlot, createdAt(clip)).run();
  const row = await clipRow(c.env, clip.id);
  if (!row || row.member_id !== userId || row.room_id !== room.id || row.day !== clip.day) {
    fail("bad_request", "clip id already in use");
  }

  const exp = Math.floor(Date.now() / 1000) + UPLOAD_TTL_SECONDS;
  return c.json({
    url: await signUploadURL(c.env, originOf(c), row.id, row.storage_key, exp),
    headers: { "Content-Type": CLIP_CONTENT_TYPE },
    storage_key: row.storage_key,
    expires_at: iso(new Date(exp * 1000)),
  });
});

/// Posts a clip whose bytes are already uploaded. The server re-checks everything the phone
/// checked: membership, length, one per slot. Posting the same clip id again returns the first
/// post -- the upload queue retries when a response is lost, and depends on that.
clipRoutes.post("/", async (c) => {
  const userId = c.get("userId");
  const { clip } = await readBody(c, Envelope);
  checkShape(c.env, clip);
  const room = await requireMemberRoom(c.env, clip.room_id, userId);
  const existing = await clipRow(c.env, clip.id);
  if (existing?.status === "posted") {
    if (existing.member_id === userId) return c.json(clipJSON(existing));
    fail("bad_request", "clip id already in use");
  }
  if (isClipTooLong(room.type, clip.duration_ms)) fail("clip_too_long");
  if (await slotTaken(c.env, room, userId, clip)) fail("slot_already_posted");
  if (!existing || existing.member_id !== userId || existing.room_id !== room.id || existing.day !== clip.day) {
    fail("bad_request", "ask for an upload URL first");
  }
  if (!(await c.env.CLIPS.head(existing.storage_key))) fail("bad_request", "the upload has not arrived");

  try {
    await c.env.DB.prepare(
      `UPDATE clips SET status = 'posted', hour = ?, duration_ms = ?, width = ?, height = ?, one_per_slot = ?, created_at = ?
        WHERE id = ? AND status = 'pending'`,
    ).bind(clip.hour, clip.duration_ms, clip.width, clip.height, capturesPerSlot(room.type) === null ? 0 : 1,
      createdAt(clip), clip.id).run();
  } catch (error) {
    // Two posts for one slot raced; the partial unique index let exactly one through.
    if (/UNIQUE constraint failed/.test(String((error as Error).message))) fail("slot_already_posted");
    throw error;
  }
  const posted = await clipRow(c.env, clip.id);
  if (!posted || posted.status !== "posted" || posted.member_id !== userId) fail("server_error", "post did not land");
  return c.json(clipJSON(posted), 201);
});

/// Deletes one of your own clips, row and R2 copy. Anyone else's (or an unknown id) is not_owner.
clipRoutes.delete("/*", async (c) => {
  const row = await clipRow(c.env, pathTail(c, "/v1/clips/"));
  if (!row || row.member_id !== c.get("userId")) fail("not_owner");
  await c.env.DB.prepare("DELETE FROM clips WHERE id = ?").bind(row.id).run();
  await deleteObjects(c.env, [row.storage_key]);
  return c.body(null, 204);
});

/// A playback URL for a storage key, only for someone in the room that clip was posted to.
/// Looked up by key, not prefix, so seeded `demo/` clips play the same way. A copy that is no
/// longer in R2 is `gone` here, before any URL exists: the app's cache downloads whatever the
/// URL returns, and a 410 body must never land on disk as a .mov. A clips/ copy older than
/// the lifecycle rule is reported gone without asking R2.
mediaRoutes.get("/sign", async (c) => {
  const userId = c.get("userId");
  const key = c.req.query("key") ?? "";
  if (!key || key.length > 500) fail("bad_request", "key required");
  const row = await c.env.DB.prepare(
    `SELECT c.created_at FROM clips c
       JOIN memberships m ON m.room_id = c.room_id AND m.user_id = ?
      WHERE c.storage_key = ? AND (c.status = 'posted' OR c.member_id = ?)
        AND NOT ${blockedEitherWay("c.member_id")}
      LIMIT 1`,
  ).bind(userId, key, userId, userId, userId).first<{ created_at: string }>();
  if (!row) fail("not_member");
  const ageMs = Date.now() - Date.parse(row.created_at);
  if (key.startsWith(CLIP_PREFIX) && ageMs > (ttlDays(c.env) + 1) * 86_400_000) fail("gone");
  if (!(await c.env.CLIPS.head(key))) fail("gone");

  const exp = Math.floor(Date.now() / 1000) + DOWNLOAD_TTL_SECONDS;
  return c.json({ url: await signDownloadURL(c.env, originOf(c), key, exp), expires_at: iso(new Date(exp * 1000)) });
});

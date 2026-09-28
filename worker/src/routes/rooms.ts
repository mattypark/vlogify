import { Hono } from "hono";
import { z } from "zod";
import {
  blockedEitherWay, clipJSON, deleteObjects, isMember, membershipJSON, requireMemberRoom, requireOwnedRoom, roomJSON,
  visibleMembers, type ClipRow, type RoomRow,
} from "../db";
import type { AppEnv, Env } from "../env";
import { fail } from "../errors";
import { readBody } from "../http";
import { isValidCapacity, normalizedName, parseDayKey, parseInviteCode, randomInviteCode, ROOM_TYPES } from "../rules";
import { iso, now, randomId } from "../util";

export const roomRoutes = new Hono<AppEnv>();

/// Guessing codes: this many misses in the window and every lookup answers rate_limited until
/// the window slides. 32^5 codes against ten guesses a quarter hour is not a strategy.
export const JOIN_MAX_FAILURES = 10;
export const JOIN_WINDOW_MS = 15 * 60 * 1000;

const Draft = z.object({
  name: z.string().max(500).nullish(),
  type: z.enum(ROOM_TYPES),
  capacity: z.number().int(),
});

roomRoutes.get("/", async (c) => {
  const { results } = await c.env.DB.prepare(
    `SELECT r.* FROM rooms r JOIN memberships m ON m.room_id = r.id
      WHERE m.user_id = ? ORDER BY r.created_at DESC, r.id`,
  ).bind(c.get("userId")).all<RoomRow>();
  return c.json(results.map(roomJSON));
});

/// A capacity the rules do not allow is `room_full`, as in the mock: the app only offers the
/// pills, so anything else is a client that is not the app.
roomRoutes.post("/", async (c) => {
  const userId = c.get("userId");
  const draft = await readBody(c, Draft);
  if (!isValidCapacity(draft.capacity, draft.type)) fail("room_full");
  const id = randomId();
  const stamp = now();
  const name = draft.name == null ? null : normalizedName(draft.name);
  const inviteCode = await withFreshCode(c.env, (code) => c.env.DB.batch([
    c.env.DB.prepare(
      "INSERT INTO rooms (id, name, type, capacity, owner_id, invite_code, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
    ).bind(id, name, draft.type, draft.capacity, userId, code, stamp),
    c.env.DB.prepare("INSERT INTO memberships (room_id, user_id, joined_at) VALUES (?, ?, ?)").bind(id, userId, stamp),
  ]));
  return c.json(roomJSON({
    id, name, type: draft.type, capacity: draft.capacity, owner_id: userId, invite_code: inviteCode, created_at: stamp,
  }), 201);
});

roomRoutes.get("/preview/:code", async (c) => {
  const room = await lookUpCode(c.env, c.get("userId"), c.req.param("code"));
  const count = await c.env.DB.prepare("SELECT COUNT(*) AS n FROM memberships WHERE room_id = ?")
    .bind(room.id).first<{ n: number }>();
  return c.json({ room: roomJSON(room), member_count: count?.n ?? 0 });
});

/// Idempotent: joining a room you are already in returns it. The capacity check and the insert
/// are one statement, so two people racing for the last seat cannot both get it.
roomRoutes.post("/join", async (c) => {
  const userId = c.get("userId");
  const { code } = await readBody(c, z.object({ code: z.string().max(64) }));
  const room = await lookUpCode(c.env, userId, code);
  if (await isMember(c.env, room.id, userId)) return c.json(roomJSON(room));
  const inserted = await c.env.DB.prepare(
    `INSERT OR IGNORE INTO memberships (room_id, user_id, joined_at)
     SELECT ?1, ?2, ?3 WHERE (SELECT COUNT(*) FROM memberships WHERE room_id = ?1) < ?4`,
  ).bind(room.id, userId, now(), room.capacity).run();
  if (!inserted.meta.changes && !(await isMember(c.env, room.id, userId))) fail("room_full");
  return c.json(roomJSON(room));
});

roomRoutes.get("/:id", async (c) => c.json(roomJSON(await requireMemberRoom(c.env, c.req.param("id"), c.get("userId")))));

roomRoutes.post("/:id/leave", async (c) => {
  const userId = c.get("userId");
  const room = await requireMemberRoom(c.env, c.req.param("id"), userId);
  await removeMembership(c.env, room, userId);
  return c.body(null, 204);
});

roomRoutes.get("/:id/members", async (c) => {
  const userId = c.get("userId");
  const room = await requireMemberRoom(c.env, c.req.param("id"), userId);
  return c.json((await visibleMembers(c.env, room.id, userId)).map(membershipJSON));
});

roomRoutes.delete("/:id/members/:userId", async (c) => {
  const room = await requireOwnedRoom(c.env, c.req.param("id"), c.get("userId"));
  await removeMembership(c.env, room, c.req.param("userId"));
  return c.body(null, 204);
});

roomRoutes.post("/:id/invite", async (c) => {
  const room = await requireOwnedRoom(c.env, c.req.param("id"), c.get("userId"));
  const inviteCode = await withFreshCode(c.env, (code) =>
    c.env.DB.prepare("UPDATE rooms SET invite_code = ? WHERE id = ?").bind(code, room.id).run());
  return c.json({ invite_code: inviteCode });
});

/// One day of a room: the members and every posted clip, minus anyone blocked either way and
/// any clip the viewer reported.
roomRoutes.get("/:id/days/:day", async (c) => {
  const userId = c.get("userId");
  const day = c.req.param("day");
  if (!parseDayKey(day)) fail("bad_request", "bad day");
  const room = await requireMemberRoom(c.env, c.req.param("id"), userId);
  const members = await visibleMembers(c.env, room.id, userId);
  const { results } = await c.env.DB.prepare(
    `SELECT c.* FROM clips c
      WHERE c.room_id = ? AND c.day = ? AND c.status = 'posted'
        AND NOT ${blockedEitherWay("c.member_id")}
        AND NOT EXISTS (SELECT 1 FROM reports r WHERE r.reporter_id = ? AND r.clip_id = c.id)
      ORDER BY c.hour, c.created_at, c.id`,
  ).bind(room.id, day, userId, userId, userId).all<ClipRow>();
  return c.json({ room_id: room.id, day, members: members.map(membershipJSON), clips: results.map(clipJSON) });
});

/// Days with at least one visible clip, newest first. Rows outlive their R2 copies, so history
/// keeps listing days whose videos only the phones still hold.
roomRoutes.get("/:id/history", async (c) => {
  const userId = c.get("userId");
  const room = await requireMemberRoom(c.env, c.req.param("id"), userId);
  const { results } = await c.env.DB.prepare(
    `SELECT DISTINCT c.day FROM clips c
      WHERE c.room_id = ? AND c.status = 'posted' AND NOT ${blockedEitherWay("c.member_id")}
      ORDER BY c.day DESC`,
  ).bind(room.id, userId, userId).all<{ day: string }>();
  return c.json(results.map((row) => row.day));
});

/// Resolves an invite code for preview or join, counting misses toward the rate limit.
async function lookUpCode(env: Env, userId: string, input: string): Promise<RoomRow> {
  const since = iso(new Date(Date.now() - JOIN_WINDOW_MS));
  const misses = await env.DB.prepare("SELECT COUNT(*) AS n FROM join_attempts WHERE user_id = ? AND ok = 0 AND at > ?")
    .bind(userId, since).first<{ n: number }>();
  if ((misses?.n ?? 0) >= JOIN_MAX_FAILURES) fail("rate_limited");
  const code = parseInviteCode(input);
  const room = code ? await env.DB.prepare("SELECT * FROM rooms WHERE invite_code = ?").bind(code).first<RoomRow>() : null;
  if (room) return room;
  await env.DB.batch([
    env.DB.prepare("INSERT INTO join_attempts (user_id, ok, at) VALUES (?, 0, ?)").bind(userId, now()),
    env.DB.prepare("DELETE FROM join_attempts WHERE user_id = ? AND at < ?")
      .bind(userId, iso(new Date(Date.now() - 24 * 60 * 60 * 1000))),
  ]);
  fail("invalid_code");
}

/// Runs `write` with a fresh code, retrying on the (astronomically rare) collision.
async function withFreshCode(env: Env, write: (code: string) => Promise<unknown>): Promise<string> {
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = randomInviteCode();
    try {
      await write(code);
      return code;
    } catch (error) {
      if (!/UNIQUE constraint failed: rooms\.invite_code/.test(String((error as Error).message))) throw error;
    }
  }
  fail("server_error", "could not mint a unique invite code");
}

/// Takes someone out of a room. The owner leaving hands the room to whoever joined next; the
/// last person leaving deletes the room and its clips, since nobody could reach them again.
export async function removeMembership(env: Env, room: RoomRow, userId: string): Promise<void> {
  await env.DB.prepare("DELETE FROM memberships WHERE room_id = ? AND user_id = ?").bind(room.id, userId).run();
  const next = await env.DB.prepare("SELECT user_id FROM memberships WHERE room_id = ? ORDER BY joined_at, user_id LIMIT 1")
    .bind(room.id).first<{ user_id: string }>();
  if (!next) {
    const { results } = await env.DB.prepare("SELECT storage_key FROM clips WHERE room_id = ?")
      .bind(room.id).all<{ storage_key: string }>();
    await env.DB.prepare("DELETE FROM rooms WHERE id = ?").bind(room.id).run();
    await deleteObjects(env, results.map((row) => row.storage_key));
    return;
  }
  if (room.owner_id === userId) {
    await env.DB.prepare("UPDATE rooms SET owner_id = ? WHERE id = ?").bind(next.user_id, room.id).run();
  }
}

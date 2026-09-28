import { Hono } from "hono";
import { z } from "zod";
import { alert } from "../alerts";
import { profileJSON, type ProfileRow } from "../db";
import type { AppEnv } from "../env";
import { fail } from "../errors";
import { background, readBody } from "../http";
import { iso, now, randomId } from "../util";

export const safetyRoutes = new Hono<AppEnv>();

export const REPORT_REASONS = ["harassment", "nudity", "violence", "spam", "impersonation", "other"] as const;

/// `Report` as WireTypes.swift encodes it. The reporter is whoever is signed in, whatever the
/// body says, and the time is the server's.
const WireReport = z.object({
  reporter_id: z.string().max(100).optional(),
  clip_id: z.string().max(100).nullish(),
  user_id: z.string().max(100).nullish(),
  reason: z.enum(REPORT_REASONS),
  note: z.string().max(1000).nullish(),
  created_at: z.string().max(40).optional(),
});

/// Guideline 1.2. A report hides the clip from the reporter at once (the day log filters it)
/// and waits for a moderator: docs/MODERATION.md.
const REPORTS_PER_HOUR = 20;

safetyRoutes.post("/reports", async (c) => {
  const userId = c.get("userId");
  const report = await readBody(c, WireReport);
  if (!report.clip_id && !report.user_id) fail("bad_request", "report a clip or a person");
  // Every report pings a person. Twenty an hour is far past honest use.
  const recent = await c.env.DB.prepare("SELECT COUNT(*) AS n FROM reports WHERE reporter_id = ? AND created_at > ?")
    .bind(userId, iso(new Date(Date.now() - 3_600_000))).first<{ n: number }>();
  if ((recent?.n ?? 0) >= REPORTS_PER_HOUR) fail("rate_limited");
  let roomId: string | null = null;
  let storageKey: string | null = null;
  let subject = report.user_id ?? null;
  if (report.clip_id) {
    // Only clips you can see: a report is not a way to learn whether an id exists.
    const clip = await c.env.DB.prepare(
      `SELECT c.room_id, c.storage_key, c.member_id FROM clips c
         JOIN memberships m ON m.room_id = c.room_id AND m.user_id = ?
        WHERE c.id = ?`,
    ).bind(userId, report.clip_id).first<{ room_id: string; storage_key: string; member_id: string }>();
    if (!clip) fail("not_member");
    roomId = clip.room_id;
    storageKey = clip.storage_key;
    subject ??= clip.member_id;
  }
  const id = randomId();
  await c.env.DB.prepare(
    `INSERT INTO reports (id, reporter_id, clip_id, user_id, room_id, storage_key, reason, note, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  ).bind(id, userId, report.clip_id ?? null, subject, roomId, storageKey, report.reason, report.note ?? null, now()).run();
  background(c, alert(c.env, `vlogify report ${id}: ${report.reason}${report.clip_id ? ` clip ${report.clip_id}` : ""}${subject ? ` user ${subject}` : ""}. Review within 24 h (docs/MODERATION.md).`));
  return c.body(null, 204);
});

safetyRoutes.post("/blocks", async (c) => {
  const userId = c.get("userId");
  const { user_id: blocked } = await readBody(c, z.object({ user_id: z.string().min(1).max(100) }));
  if (blocked === userId) fail("bad_request", "cannot block yourself");
  try {
    await c.env.DB.prepare("INSERT OR IGNORE INTO blocks (blocker, blocked, created_at) VALUES (?, ?, ?)")
      .bind(userId, blocked, now()).run();
  } catch (error) {
    // Blocking an account that no longer exists: there is nobody left to hide.
    if (!/FOREIGN KEY constraint failed/.test(String((error as Error).message))) throw error;
  }
  return c.body(null, 204);
});

safetyRoutes.delete("/blocks/:userId", async (c) => {
  await c.env.DB.prepare("DELETE FROM blocks WHERE blocker = ? AND blocked = ?").bind(c.get("userId"), c.req.param("userId")).run();
  return c.body(null, 204);
});

safetyRoutes.get("/blocks", async (c) => {
  const { results } = await c.env.DB.prepare(
    `SELECT p.id, p.display_name, p.avatar_seed, p.mark, p.created_at FROM blocks b JOIN profiles p ON p.id = b.blocked
      WHERE b.blocker = ? ORDER BY p.display_name, p.id`,
  ).bind(c.get("userId")).all<ProfileRow>();
  return c.json(results.map(profileJSON));
});

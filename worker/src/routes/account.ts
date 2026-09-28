import { Hono } from "hono";
import { z } from "zod";
import { revokeAppleToken, sealedAppleToken } from "../auth";
import { deleteObjects, profileJSON, profileRow } from "../db";
import type { AppEnv } from "../env";
import { fail } from "../errors";
import { readBody } from "../http";
import { isValidMark } from "../rules";
import { cleanDisplayName, normalizedAvatarSeed } from "../users";

export const accountRoutes = new Hono<AppEnv>();

accountRoutes.get("/me", async (c) => {
  const profile = await profileRow(c.env, c.get("userId"));
  return c.json(profileJSON(profile ?? fail("not_signed_in")));
});

const ProfilePatch = z.object({
  display_name: z.string().max(500).optional(),
  avatar_seed: z.number().int().optional(),
  mark: z.string().max(4000).optional(),
});

/// Any subset of name, colour and mark. The mark is decoded here exactly as the app decodes it,
/// so a row can never hold one the app would refuse to draw.
accountRoutes.patch("/me", async (c) => {
  const userId = c.get("userId");
  const patch = await readBody(c, ProfilePatch);
  if (patch.mark !== undefined && !isValidMark(patch.mark)) fail("bad_request", "not a version-1 mark");
  const sets: string[] = [];
  const values: (string | number)[] = [];
  if (patch.display_name !== undefined) {
    sets.push("display_name = ?");
    values.push(cleanDisplayName(patch.display_name));
  }
  if (patch.avatar_seed !== undefined) {
    sets.push("avatar_seed = ?");
    values.push(normalizedAvatarSeed(patch.avatar_seed));
  }
  if (patch.mark !== undefined) {
    sets.push("mark = ?");
    values.push(patch.mark);
  }
  if (sets.length) {
    await c.env.DB.prepare(`UPDATE profiles SET ${sets.join(", ")} WHERE id = ?`).bind(...values, userId).run();
  }
  const profile = await profileRow(c.env, userId);
  return c.json(profileJSON(profile ?? fail("not_signed_in")));
});

/// Guideline 5.1.1(v). Removes the person and everything they made: their clips everywhere,
/// the rooms they own (with everyone's clips in them), memberships, blocks, the R2 copies, then
/// Apple's grant. Reports they filed stay, as moderation records naming an id that is gone.
accountRoutes.delete("/account", async (c) => {
  const userId = c.get("userId");
  const sealed = await sealedAppleToken(c.env, userId);
  const { results } = await c.env.DB.prepare(
    `SELECT storage_key FROM clips WHERE member_id = ?
     UNION SELECT c.storage_key FROM clips c JOIN rooms r ON r.id = c.room_id WHERE r.owner_id = ?`,
  ).bind(userId, userId).all<{ storage_key: string }>();

  // The users row cascades to identities, profile, Apple token, owned rooms (and their
  // memberships and clips), memberships, clips, blocks both ways and join attempts.
  await c.env.DB.prepare("DELETE FROM users WHERE id = ?").bind(userId).run();
  try {
    await deleteObjects(c.env, results.map((row) => row.storage_key));
  } catch (error) {
    // The rows are gone, so nothing can reach the objects; the lifecycle rule removes them
    // within CLIP_TTL_DAYS regardless.
    console.error("delete account: R2 cleanup failed", (error as Error).message);
  }
  await revokeAppleToken(c.env, sealed);
  return c.body(null, 204);
});

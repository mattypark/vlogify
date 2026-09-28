// Rows and their wire shapes. Every key here is spelled exactly as WireTypes.swift spells it;
// the app decodes these with no key strategy, so a renamed key is a decoding failure.

import type { Env } from "./env";
import { fail } from "./errors";
import type { RoomType } from "./rules";

/// Where uploaded clips live in R2. The bucket's lifecycle rule expires this prefix.
export const CLIP_PREFIX = "clips/";

export interface ProfileRow {
  id: string;
  display_name: string;
  avatar_seed: number;
  mark: string | null;
  created_at: string;
}

export interface RoomRow {
  id: string;
  name: string | null;
  type: RoomType;
  capacity: number;
  owner_id: string;
  invite_code: string;
  created_at: string;
}

export interface ClipRow {
  id: string;
  room_id: string;
  member_id: string;
  day: string;
  hour: number;
  duration_ms: number;
  width: number;
  height: number;
  storage_key: string;
  status: "pending" | "posted";
  one_per_slot: number;
  created_at: string;
}

export interface MembershipRow extends ProfileRow {
  room_id: string;
  user_id: string;
  joined_at: string;
}

export function profileJSON(row: ProfileRow) {
  return {
    id: row.id,
    display_name: row.display_name,
    avatar_seed: row.avatar_seed,
    ...(row.mark ? { mark: row.mark } : {}),
    created_at: row.created_at,
  };
}

export function roomJSON(row: RoomRow) {
  return {
    id: row.id,
    name: row.name,
    type: row.type,
    capacity: row.capacity,
    owner_id: row.owner_id,
    invite_code: row.invite_code,
    created_at: row.created_at,
  };
}

export function clipJSON(row: ClipRow) {
  return {
    id: row.id,
    room_id: row.room_id,
    member_id: row.member_id,
    day: row.day,
    hour: row.hour,
    duration_ms: row.duration_ms,
    width: row.width,
    height: row.height,
    storage_key: row.storage_key,
    created_at: row.created_at,
  };
}

export function membershipJSON(row: MembershipRow) {
  return {
    room_id: row.room_id,
    user_id: row.user_id,
    profile: profileJSON({
      id: row.user_id,
      display_name: row.display_name,
      avatar_seed: row.avatar_seed,
      mark: row.mark,
      created_at: row.created_at,
    }),
    joined_at: row.joined_at,
  };
}

/// SQL that is true when `?me` and the person in `column` have blocked each other either way.
/// `me` is bound twice, as ?1-style numbered params would tangle with each caller's own.
export function blockedEitherWay(column: string): string {
  return `EXISTS (SELECT 1 FROM blocks b WHERE (b.blocker = ? AND b.blocked = ${column}) OR (b.blocker = ${column} AND b.blocked = ?))`;
}

export async function profileRow(env: Env, userId: string): Promise<ProfileRow | null> {
  return env.DB.prepare("SELECT id, display_name, avatar_seed, mark, created_at FROM profiles WHERE id = ?")
    .bind(userId).first<ProfileRow>();
}

export async function roomRow(env: Env, roomId: string): Promise<RoomRow | null> {
  return env.DB.prepare("SELECT * FROM rooms WHERE id = ?").bind(roomId).first<RoomRow>();
}

export async function isMember(env: Env, roomId: string, userId: string): Promise<boolean> {
  const row = await env.DB.prepare("SELECT 1 AS ok FROM memberships WHERE room_id = ? AND user_id = ?")
    .bind(roomId, userId).first();
  return row !== null;
}

/// The room, if the caller is in it. A room that does not exist and a room the caller is not in
/// look the same from outside (not_member), as they do in the mock: no probing for ids.
export async function requireMemberRoom(env: Env, roomId: string, userId: string): Promise<RoomRow> {
  if (!(await isMember(env, roomId, userId))) fail("not_member");
  return (await roomRow(env, roomId)) ?? fail("room_not_found");
}

/// The room, if the caller owns it. Unknown rooms are not_owner, as in the mock.
export async function requireOwnedRoom(env: Env, roomId: string, userId: string): Promise<RoomRow> {
  const room = await roomRow(env, roomId);
  if (!room || room.owner_id !== userId) fail("not_owner");
  return room;
}

/// Members of a room with their profiles, oldest first, minus anyone blocked either way.
export async function visibleMembers(env: Env, roomId: string, viewerId: string): Promise<MembershipRow[]> {
  const { results } = await env.DB.prepare(
    `SELECT m.room_id, m.user_id, m.joined_at, p.id, p.display_name, p.avatar_seed, p.mark, p.created_at
       FROM memberships m JOIN profiles p ON p.id = m.user_id
      WHERE m.room_id = ? AND NOT ${blockedEitherWay("m.user_id")}
      ORDER BY m.joined_at, m.user_id`,
  ).bind(roomId, viewerId, viewerId).all<MembershipRow>();
  return results;
}

/// Deletes R2 objects in batches (the API takes up to 1000 keys per call). Only keys under
/// `clips/` -- the ones this Worker minted. Seeded `demo/` objects are shared by many rows and
/// belong to scripts/seed-review-room.sh.
export async function deleteObjects(env: Env, keys: string[]): Promise<void> {
  const unique = [...new Set(keys)].filter((key) => key.startsWith(CLIP_PREFIX));
  for (let i = 0; i < unique.length; i += 1000) {
    await env.CLIPS.delete(unique.slice(i, i + 1000));
  }
}

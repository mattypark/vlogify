import type { Env } from "./env";
import { maskProfanity } from "./filter";
import { now, prefixGraphemes, randomId } from "./util";

/// The longest display name, in characters. What fits under an avatar on the smallest phone.
export const DISPLAY_NAME_MAX = 20;
export const AVATAR_SEEDS = 12;

/// Trimmed, capped, and passed through the word filter: a name is shown to everyone in a room.
export function cleanDisplayName(raw: string | null | undefined): string {
  return maskProfanity(prefixGraphemes((raw ?? "").trim(), DISPLAY_NAME_MAX));
}

/// Swift's `((seed % 12) + 12) % 12`, which is what the mock stores for any integer.
export function normalizedAvatarSeed(seed: number): number {
  return ((seed % AVATAR_SEEDS) + AVATAR_SEEDS) % AVATAR_SEEDS;
}

function randomAvatarSeed(): number {
  return crypto.getRandomValues(new Uint8Array(1))[0]! % AVATAR_SEEDS;
}

export interface NewUser {
  displayName?: string | null;
  avatarSeed?: number;
  /// HMAC of the provider subject. Absent for accounts made by scripts and tests.
  identity?: { subHash: string; provider: "apple" | "google" | "email" };
}

/// Makes a user and their profile in one transaction. If the identity already exists (two
/// first sign-ins racing), the batch rolls back and the caller finds the winner.
export async function createUser(env: Env, input: NewUser = {}): Promise<string> {
  const id = randomId();
  const stamp = now();
  const statements = [
    env.DB.prepare("INSERT INTO users (id, created_at) VALUES (?, ?)").bind(id, stamp),
    env.DB.prepare("INSERT INTO profiles (id, display_name, avatar_seed, mark, created_at) VALUES (?, ?, ?, NULL, ?)")
      .bind(id, cleanDisplayName(input.displayName), input.avatarSeed ?? randomAvatarSeed(), stamp),
  ];
  if (input.identity) {
    statements.push(env.DB.prepare("INSERT INTO identities (sub_hash, user_id, provider, created_at) VALUES (?, ?, ?, ?)")
      .bind(input.identity.subHash, id, input.identity.provider, stamp));
  }
  await env.DB.batch(statements);
  return id;
}

export async function userForIdentity(env: Env, subHash: string): Promise<{ id: string; banned_at: string | null } | null> {
  return env.DB.prepare(
    "SELECT u.id, u.banned_at FROM identities i JOIN users u ON u.id = i.user_id WHERE i.sub_hash = ?",
  ).bind(subHash).first<{ id: string; banned_at: string | null }>();
}

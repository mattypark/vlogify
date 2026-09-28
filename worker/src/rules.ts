// The server's copy of the rules in ios/VlogifyDesign/Sources/VlogifyEngine (RoomRules,
// InviteCode, DayKey, Slot) and of the Mark wire format in VlogifyContract/Mark.swift.
// test/rules.test.ts runs the same vectors as the Swift tests; if a number here and a number
// there disagree, one of the two has drifted.

import { fromBase64url, prefixGraphemes } from "./util";

// MARK: - Room types and rules (RoomRules.swift)

export const ROOM_TYPES = ["log", "stack", "vlog", "zip"] as const;
export type RoomType = (typeof ROOM_TYPES)[number];

export function isValidCapacity(capacity: number, type: RoomType): boolean {
  if (!Number.isInteger(capacity)) return false;
  switch (type) {
    case "log": return capacity >= 2 && capacity <= 20;
    case "stack": return capacity >= 2 && capacity <= 40;
    case "vlog": return capacity === 1;
    case "zip": return capacity === 2;
  }
}

/// Clip length in seconds; null means unlimited.
export function clipLimit(type: RoomType): number | null {
  return type === "log" || type === "stack" ? 2.0 : null;
}

/// Clips one member may post into one slot; null means unlimited.
export function capturesPerSlot(type: RoomType): number | null {
  return type === "log" || type === "stack" ? 1 : null;
}

/// The phone enforces the limit first; the server allows the same 250 ms of slack the mock does
/// for a recording that stopped a frame late.
export const CLIP_LENGTH_TOLERANCE_MS = 250;

export function isClipTooLong(type: RoomType, durationMs: number): boolean {
  const limit = clipLimit(type);
  return limit !== null && durationMs > limit * 1000 + CLIP_LENGTH_TOLERANCE_MS;
}

export const MAX_NAME_LENGTH = 24;

export function normalizedName(raw: string): string | null {
  const trimmed = raw.trim();
  if (!trimmed) return null;
  return prefixGraphemes(trimmed, MAX_NAME_LENGTH);
}

export function canJoin(memberCount: number, capacity: number): boolean {
  return memberCount < capacity;
}

// MARK: - Invite codes (InviteCode.swift)

export const ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
export const CODE_LENGTH = 6;

/// Uppercases, strips separators, and maps the confusable letters back. Walks grapheme
/// clusters, as Swift walks `Character`s: an accented A is one character and is dropped.
export function normalizeCode(input: string): string {
  const segmenter = new Intl.Segmenter(undefined, { granularity: "grapheme" });
  let out = "";
  for (const { segment: character } of segmenter.segment(input.toUpperCase())) {
    if (character === "I" || character === "L") out += "1";
    else if (character === "O") out += "0";
    else if (character === "-" || character === " " || character === "_") continue;
    else if (ALPHABET.includes(character)) out += character;
  }
  return out;
}

/// Weighted sum of the body's symbol values, modulo the alphabet size.
export function checkCharacter(body: string): string | null {
  let sum = 0;
  let position = 0;
  for (const character of body) {
    const index = ALPHABET.indexOf(character);
    if (index < 0) return null;
    sum += index * (position + 1);
    position += 1;
  }
  return ALPHABET[sum % ALPHABET.length] ?? null;
}

/// The canonical six characters, or null unless the input is a well-formed code whose check
/// character matches.
export function parseInviteCode(input: string): string | null {
  const normalized = normalizeCode(input);
  if (normalized.length !== CODE_LENGTH) return null;
  const check = checkCharacter(normalized.slice(0, -1));
  return check !== null && normalized.endsWith(check) ? normalized : null;
}

/// Mints a code from a 64-bit generator, exactly as `InviteCode.generate(using:)` does, so a
/// seeded generator gives the same code on both sides.
export function generateInviteCode(next: () => bigint): string {
  let body = "";
  for (let i = 0; i < CODE_LENGTH - 1; i++) {
    body += ALPHABET[Number(next() % BigInt(ALPHABET.length))];
  }
  return body + (checkCharacter(body) ?? "0");
}

/// A fresh code from the platform CSPRNG.
export function randomInviteCode(): string {
  return generateInviteCode(() => {
    const words = crypto.getRandomValues(new BigUint64Array(1));
    return words[0] ?? 0n;
  });
}

// MARK: - Days and slots (DayClock.swift)

export const RESET_HOUR = 4;
export const FIRST_HOUR = RESET_HOUR;
export const LAST_HOUR = RESET_HOUR + 23;

/// `2026-09-11`, strictly: the app always sends `DayKey.description`, which is zero-padded.
export function parseDayKey(value: string): { year: number; month: number; day: number } | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) return null;
  const [year, month, day] = [Number(match[1]), Number(match[2]), Number(match[3])];
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  // Reject 2026-02-31 and friends: the date must survive a round trip through UTC.
  const date = new Date(Date.UTC(year, month - 1, day));
  if (date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) return null;
  return { year, month, day };
}

export function isValidHour(hour: number): boolean {
  return Number.isInteger(hour) && hour >= FIRST_HOUR && hour <= LAST_HOUR;
}

/// Whether a day is close enough to now to be posted into. A phone anywhere on Earth is within
/// a day of UTC; the upload queue can hold a clip for a while offline, so the window reaches
/// back as far as the clip copies live.
export function isDayInWindow(day: string, at: Date, backDays: number): boolean {
  const parsed = parseDayKey(day);
  if (!parsed) return false;
  const dayStart = Date.UTC(parsed.year, parsed.month - 1, parsed.day);
  const today = Date.UTC(at.getUTCFullYear(), at.getUTCMonth(), at.getUTCDate());
  const diffDays = Math.round((dayStart - today) / 86_400_000);
  return diffDays >= -(backDays + 1) && diffDays <= 1;
}

// MARK: - Marks (Mark.swift)

export const MARK_VERSION = 1;
export const MARK_MAX_STROKES = 64;
export const MARK_MAX_POINTS = 640;
export const MARK_MAX_ENCODED_LENGTH = 1800;

/// True for a well-formed version-1 mark within the caps -- the same test as
/// `Mark(encoded:)`. The server stores the string; it never draws it.
export function isValidMark(encoded: string): boolean {
  if (!encoded || encoded.length > MARK_MAX_ENCODED_LENGTH) return false;
  const bytes = fromBase64url(encoded);
  if (!bytes || bytes[0] !== MARK_VERSION) return false;
  let index = 1;
  let strokes = 0;
  let points = 0;
  while (index < bytes.length) {
    const count = bytes[index]!;
    index += 1;
    if (count === 0 || index + count * 2 > bytes.length) return false;
    index += count * 2;
    strokes += 1;
    points += count;
  }
  return strokes > 0 && strokes <= MARK_MAX_STROKES && points <= MARK_MAX_POINTS;
}

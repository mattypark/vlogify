// Media URLs the Worker signs for itself. There are no R2 API keys anywhere: the app PUTs to
// /media/upload/<clip id> and plays from /media/<key>, each carrying an expiry and an HMAC over
// what it may touch. The bytes stream through the Worker to and from the CLIPS binding.

import type { Context } from "hono";
import type { AppEnv, Env } from "./env";
import { errorResponse, fail } from "./errors";
import type { RoomType } from "./rules";
import { hmacHex, hmacVerify } from "./util";

/// An upload URL is good for ten minutes: long enough for a slow uplink, short enough that a
/// leaked one is useless by the time anyone finds it.
export const UPLOAD_TTL_SECONDS = 600;
/// A playback URL is good for an hour. AVPlayer asks for byte ranges as it plays, so it must
/// outlive a single request.
export const DOWNLOAD_TTL_SECONDS = 3600;

/// Upload caps. A two-second log clip is a few MB; a solo vlog can run longer.
export const MAX_UPLOAD_BYTES: Record<RoomType, number> = {
  log: 25 * 1024 * 1024,
  stack: 25 * 1024 * 1024,
  vlog: 100 * 1024 * 1024,
  zip: 100 * 1024 * 1024,
};

const UPLOAD_CONTENT_TYPES = new Set(["video/quicktime", "video/mp4"]);
export const CLIP_CONTENT_TYPE = "video/quicktime";

function uploadMessage(clipId: string, storageKey: string, exp: number): string {
  return `put\n${clipId}\n${storageKey}\n${exp}`;
}

function downloadMessage(storageKey: string, exp: number): string {
  return `get\n${storageKey}\n${exp}`;
}

function encodeKeyPath(storageKey: string): string {
  return storageKey.split("/").map(encodeURIComponent).join("/");
}

export async function signUploadURL(env: Env, origin: string, clipId: string, storageKey: string, exp: number): Promise<string> {
  const sig = await hmacHex(env.MEDIA_SIGNING_KEY, uploadMessage(clipId, storageKey, exp));
  return `${origin}/media/upload/${encodeURIComponent(clipId)}?exp=${exp}&sig=${sig}`;
}

export async function signDownloadURL(env: Env, origin: string, storageKey: string, exp: number): Promise<string> {
  const sig = await hmacHex(env.MEDIA_SIGNING_KEY, downloadMessage(storageKey, exp));
  return `${origin}/media/${encodeKeyPath(storageKey)}?exp=${exp}&sig=${sig}`;
}

function expiryFrom(c: Context<AppEnv>): number {
  const exp = Number(c.req.query("exp"));
  if (!Number.isInteger(exp) || exp < Math.floor(Date.now() / 1000)) fail("bad_signature", "expired");
  return exp;
}

/// The rest of the path after `prefix`, percent-decoded as one value. Clip ids may hold a "/"
/// (the app builds them from the slot key), which arrives as %2F; a route parameter would
/// depend on the router's decoding rules, this does not.
export function pathTail(c: Context<AppEnv>, prefix: string): string {
  const raw = new URL(c.req.url).pathname.slice(prefix.length);
  try {
    return decodeURIComponent(raw);
  } catch {
    fail("bad_request", "malformed path");
  }
}

/// PUT /media/upload/<clip id> -- streams the body into R2 at the key minted for that clip.
export async function handleUpload(c: Context<AppEnv>): Promise<Response> {
  const clipId = pathTail(c, "/media/upload/");
  const exp = expiryFrom(c);
  const row = await c.env.DB.prepare(
    "SELECT c.storage_key, r.type FROM clips c JOIN rooms r ON r.id = c.room_id WHERE c.id = ?",
  ).bind(clipId).first<{ storage_key: string; type: RoomType }>();
  // An unknown clip id answers exactly like a bad signature: nothing to learn by guessing.
  if (!row) fail("bad_signature");
  const ok = await hmacVerify(c.env.MEDIA_SIGNING_KEY, uploadMessage(clipId, row.storage_key, exp), c.req.query("sig") ?? "");
  if (!ok) fail("bad_signature");

  const length = Number(c.req.header("Content-Length"));
  if (!Number.isInteger(length) || length <= 0) fail("bad_request", "Content-Length required");
  if (length > MAX_UPLOAD_BYTES[row.type]) fail("too_large");
  const body = c.req.raw.body;
  if (!body) fail("bad_request", "empty body");

  const declared = (c.req.header("Content-Type") ?? "").split(";")[0]!.trim().toLowerCase();
  const contentType = UPLOAD_CONTENT_TYPES.has(declared) ? declared : CLIP_CONTENT_TYPE;
  await c.env.CLIPS.put(row.storage_key, body, { httpMetadata: { contentType } });
  return new Response(null, { status: 204 });
}

type ParsedRange = { offset: number; length?: number } | { suffix: number };

/// `bytes=a-b`, `bytes=a-` or `bytes=-n`. Multiple ranges are not offered; anything unreadable
/// is ignored and the whole object is sent, as RFC 9110 allows.
export function parseRange(header: string | undefined): ParsedRange | null {
  const match = header ? /^bytes=(\d*)-(\d*)$/.exec(header.trim()) : null;
  if (!match) return null;
  const [start, end] = [match[1]!, match[2]!];
  if (!start && !end) return null;
  if (!start) return { suffix: Number(end) };
  const offset = Number(start);
  if (!end) return { offset };
  const last = Number(end);
  if (last < offset) return null;
  return { offset, length: last - offset + 1 };
}

/// GET or HEAD /media/<key> -- playback. 410 when the object has expired out of R2: the app
/// then plays its own copy if it has one.
export async function handleDownload(c: Context<AppEnv>): Promise<Response> {
  const path = new URL(c.req.url).pathname.slice("/media/".length);
  let storageKey: string;
  try {
    storageKey = path.split("/").map(decodeURIComponent).join("/");
  } catch {
    fail("bad_signature");
  }
  const exp = expiryFrom(c);
  const ok = await hmacVerify(c.env.MEDIA_SIGNING_KEY, downloadMessage(storageKey, exp), c.req.query("sig") ?? "");
  if (!ok) fail("bad_signature");

  const baseHeaders = (object: R2Object) => {
    const headers = new Headers();
    headers.set("Content-Type", object.httpMetadata?.contentType ?? CLIP_CONTENT_TYPE);
    headers.set("Accept-Ranges", "bytes");
    headers.set("ETag", object.httpEtag);
    headers.set("Cache-Control", "private, max-age=3600");
    return headers;
  };

  if (c.req.method === "HEAD") {
    const head = await c.env.CLIPS.head(storageKey);
    if (!head) return errorResponse("gone");
    const headers = baseHeaders(head);
    headers.set("Content-Length", String(head.size));
    return new Response(null, { status: 200, headers });
  }

  const range = parseRange(c.req.header("Range"));
  let object: R2ObjectBody | null;
  try {
    object = await c.env.CLIPS.get(storageKey, range ? { range } : undefined);
  } catch {
    // R2 refuses a range past the end of the object.
    const head = await c.env.CLIPS.head(storageKey);
    if (!head) return errorResponse("gone");
    return new Response(null, { status: 416, headers: { "Content-Range": `bytes */${head.size}` } });
  }
  if (!object) return errorResponse("gone");

  const headers = baseHeaders(object);
  if (!range) {
    headers.set("Content-Length", String(object.size));
    return new Response(object.body, { status: 200, headers });
  }
  const size = object.size;
  const start = "suffix" in range ? Math.max(size - range.suffix, 0) : range.offset;
  const end = "suffix" in range ? size - 1 : Math.min(range.length === undefined ? size - 1 : start + range.length - 1, size - 1);
  if (start >= size || end < start) {
    await object.body.cancel();
    return new Response(null, { status: 416, headers: { "Content-Range": `bytes */${size}` } });
  }
  headers.set("Content-Range", `bytes ${start}-${end}/${size}`);
  headers.set("Content-Length", String(end - start + 1));
  return new Response(object.body, { status: 206, headers });
}

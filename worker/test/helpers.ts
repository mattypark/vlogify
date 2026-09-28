import { env, SELF } from "cloudflare:test";
import { issueSession } from "../src/auth";
import { createUser } from "../src/users";

export const ORIGIN = "https://vlogify.test";

export interface TestUser {
  id: string;
  token: string;
}

/// A fresh account with a session, made directly (no Apple round trip).
export async function newUser(name = "tester"): Promise<TestUser> {
  const id = await createUser(env, { displayName: name, avatarSeed: 3 });
  return { id, token: await issueSession(env, id, new Date()) };
}

export function api(path: string, user?: TestUser | null, init: RequestInit & { json?: unknown } = {}): Promise<Response> {
  const { json, ...rest } = init;
  const headers = new Headers(rest.headers);
  if (user) headers.set("Authorization", `Bearer ${user.token}`);
  if (json !== undefined) headers.set("Content-Type", "application/json");
  return SELF.fetch(`${ORIGIN}${path}`, {
    ...rest,
    headers,
    ...(json !== undefined ? { body: JSON.stringify(json), method: rest.method ?? "POST" } : {}),
  });
}

export async function body<T = any>(response: Response): Promise<T> {
  return (await response.json()) as T;
}

export async function errorOf(response: Response): Promise<{ status: number; error: string }> {
  const json = await response.json().catch(() => ({})) as { error?: string };
  return { status: response.status, error: json.error ?? "" };
}

/// Today's UTC date: always inside the server's posting window.
export function today(): string {
  return new Date().toISOString().slice(0, 10);
}

export async function createRoom(user: TestUser, draft: { name?: string | null; type: string; capacity: number }) {
  const response = await api("/v1/rooms", user, { json: draft });
  if (response.status !== 201) throw new Error(`create room: ${response.status} ${await response.text()}`);
  return body(response);
}

export async function join(user: TestUser, code: string): Promise<Response> {
  return api("/v1/rooms/join", user, { json: { code } });
}

let clipCounter = 0;

export function wireClip(roomId: string, user: TestUser, overrides: Record<string, unknown> = {}) {
  clipCounter += 1;
  return {
    id: `CLIP-${crypto.randomUUID().toUpperCase()}`,
    room_id: roomId,
    member_id: user.id,
    day: today(),
    hour: 10 + (clipCounter % 10),
    duration_ms: 2000,
    width: 1080,
    height: 1920,
    storage_key: "",
    created_at: new Date().toISOString().replace(/\.\d{3}Z$/, "Z"),
    ...overrides,
  };
}

export const CLIP_BYTES = new Uint8Array([0, 0, 0, 20, 102, 116, 121, 112, 113, 116, 32, 32, 1, 2, 3, 4, 5, 6, 7, 8]);

/// upload-url, PUT the bytes, post. Returns each response so tests can look at any step.
export async function uploadAndPost(user: TestUser, clip: ReturnType<typeof wireClip>) {
  const minted = await api("/v1/clips/upload-url", user, { json: { clip } });
  if (minted.status !== 200) return { minted, upload: null, posted: null };
  const signed = await body(minted);
  const upload = await SELF.fetch(signed.url, { method: "PUT", headers: signed.headers, body: CLIP_BYTES });
  const posted = await api("/v1/clips", user, { json: { clip: { ...clip, storage_key: signed.storage_key } } });
  return { minted, signed, upload, posted };
}

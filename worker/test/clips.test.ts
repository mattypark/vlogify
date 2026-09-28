import { env, SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { signDownloadURL, signUploadURL } from "../src/media";
import { api, body, CLIP_BYTES, createRoom, errorOf, join, newUser, ORIGIN, today, uploadAndPost, wireClip } from "./helpers";

async function logRoom() {
  const owner = await newUser("owner");
  const friend = await newUser("friend");
  const room = await createRoom(owner, { type: "log", capacity: 3 });
  await join(friend, room.invite_code);
  return { owner, friend, room };
}

describe("posting clips", () => {
  it("upload-url, PUT, post: the clip lands in the day log with the server's storage key", async () => {
    const { owner, friend, room } = await logRoom();
    const clip = wireClip(room.id, friend, { hour: 9 });
    const { minted, signed, upload, posted } = await uploadAndPost(friend, clip);
    expect(minted.status).toBe(200);
    expect(signed.storage_key).toBe(`clips/${room.id}/${clip.day}/${clip.id}.mov`);
    expect(signed.headers).toEqual({ "Content-Type": "video/quicktime" });
    expect(signed.url).toMatch(new RegExp(`^${ORIGIN}/media/upload/${clip.id}\\?exp=\\d+&sig=[0-9a-f]{64}$`));
    expect(signed.expires_at).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/);
    expect(upload!.status).toBe(204);
    expect(posted!.status).toBe(201);
    const saved = await body(posted!);
    expect(saved).toEqual({ ...clip, member_id: friend.id, storage_key: signed.storage_key });
    expect(await env.CLIPS.head(signed.storage_key)).not.toBeNull();

    const log = await body(await api(`/v1/rooms/${room.id}/days/${today()}`, owner));
    expect(log.room_id).toBe(room.id);
    expect(log.day).toBe(today());
    expect(log.members.map((m: { user_id: string }) => m.user_id).sort()).toEqual([owner.id, friend.id].sort());
    expect(log.clips).toEqual([saved]);
    expect(await body(await api(`/v1/rooms/${room.id}/history`, owner))).toEqual([today()]);
  });

  it("a pending clip is not in the day log", async () => {
    const { owner, room } = await logRoom();
    const clip = wireClip(room.id, owner, { hour: 5 });
    expect((await api("/v1/clips/upload-url", owner, { json: { clip } })).status).toBe(200);
    const log = await body(await api(`/v1/rooms/${room.id}/days/${today()}`, owner));
    expect(log.clips.find((c: { id: string }) => c.id === clip.id)).toBeUndefined();
  });

  it("one clip per slot in a log; posting the same clip again returns the first post", async () => {
    const { friend, room } = await logRoom();
    const first = wireClip(room.id, friend, { hour: 12 });
    const { posted } = await uploadAndPost(friend, first);
    const saved = await body(posted!);

    const again = await api("/v1/clips", friend, { json: { clip: { ...first, duration_ms: 1500 } } });
    expect(again.status).toBe(200);
    expect(await body(again)).toEqual(saved);

    const second = wireClip(room.id, friend, { hour: 12 });
    expect(await errorOf(await api("/v1/clips/upload-url", friend, { json: { clip: second } })))
      .toEqual({ status: 409, error: "slot_already_posted" });
    // And the next hour is free.
    expect((await uploadAndPost(friend, wireClip(room.id, friend, { hour: 13 }))).posted!.status).toBe(201);
  });

  it("two pending clips racing for one slot: only one posts", async () => {
    const { friend, room } = await logRoom();
    const a = wireClip(room.id, friend, { hour: 20 });
    const b = wireClip(room.id, friend, { hour: 20 });
    const signedA = await body(await api("/v1/clips/upload-url", friend, { json: { clip: a } }));
    const signedB = await body(await api("/v1/clips/upload-url", friend, { json: { clip: b } }));
    await SELF.fetch(signedA.url, { method: "PUT", headers: signedA.headers, body: CLIP_BYTES });
    await SELF.fetch(signedB.url, { method: "PUT", headers: signedB.headers, body: CLIP_BYTES });
    expect((await api("/v1/clips", friend, { json: { clip: a } })).status).toBe(201);
    expect(await errorOf(await api("/v1/clips", friend, { json: { clip: b } })))
      .toEqual({ status: 409, error: "slot_already_posted" });
  });

  it("a vlog takes any number of clips in one hour, of any length", async () => {
    const owner = await newUser();
    const room = await createRoom(owner, { type: "vlog", capacity: 1 });
    for (const duration of [2000, 90_000]) {
      const { posted } = await uploadAndPost(owner, wireClip(room.id, owner, { hour: 15, duration_ms: duration }));
      expect(posted!.status).toBe(201);
    }
    expect((await body(await api(`/v1/rooms/${room.id}/days/${today()}`, owner))).clips).toHaveLength(2);
  });

  it("refuses a log clip over two seconds plus 250 ms", async () => {
    const { friend, room } = await logRoom();
    expect(await errorOf(await api("/v1/clips/upload-url", friend, { json: { clip: wireClip(room.id, friend, { duration_ms: 2251 }) } })))
      .toEqual({ status: 422, error: "clip_too_long" });
    expect((await uploadAndPost(friend, wireClip(room.id, friend, { hour: 22, duration_ms: 2250 }))).posted!.status).toBe(201);
  });

  it("refuses an hour outside 4...27, a day far from now, and an unsafe id", async () => {
    const { friend, room } = await logRoom();
    for (const overrides of [{ hour: 3 }, { hour: 28 }, { day: "2020-01-01" }, { day: "2026-02-31" }, { id: "../etc" }]) {
      const response = await api("/v1/clips/upload-url", friend, { json: { clip: wireClip(room.id, friend, overrides) } });
      expect(await errorOf(response), JSON.stringify(overrides)).toEqual({ status: 400, error: "bad_request" });
    }
  });

  it("posting before the bytes arrive is refused", async () => {
    const { friend, room } = await logRoom();
    const clip = wireClip(room.id, friend, { hour: 23 });
    expect((await api("/v1/clips", friend, { json: { clip } })).status).toBe(400);
    await api("/v1/clips/upload-url", friend, { json: { clip } });
    expect(await errorOf(await api("/v1/clips", friend, { json: { clip } }))).toEqual({ status: 400, error: "bad_request" });
  });

  it("deletes your own clip and its R2 copy; anyone else's is not_owner", async () => {
    const { owner, friend, room } = await logRoom();
    const { signed, posted } = await uploadAndPost(friend, wireClip(room.id, friend, { hour: 7 }));
    const saved = await body(posted!);
    expect(await errorOf(await api(`/v1/clips/${saved.id}`, owner, { method: "DELETE" }))).toEqual({ status: 403, error: "not_owner" });
    expect(await errorOf(await api("/v1/clips/no-such-clip", owner, { method: "DELETE" }))).toEqual({ status: 403, error: "not_owner" });
    expect((await api(`/v1/clips/${saved.id}`, friend, { method: "DELETE" })).status).toBe(204);
    expect(await env.CLIPS.head(signed.storage_key)).toBeNull();
    expect((await body(await api(`/v1/rooms/${room.id}/days/${today()}`, owner))).clips).toEqual([]);
  });
});

describe("signed media URLs", () => {
  it("an upload URL with a tampered signature, another clip's signature, or a past expiry is refused", async () => {
    const { friend, room } = await logRoom();
    const clip = wireClip(room.id, friend, { hour: 16 });
    const signed = await body(await api("/v1/clips/upload-url", friend, { json: { clip } }));
    const put = (url: string) => SELF.fetch(url, { method: "PUT", headers: signed.headers, body: CLIP_BYTES });

    const tampered = signed.url.replace(/sig=([0-9a-f])/, (_: string, c: string) => `sig=${c === "0" ? "1" : "0"}`);
    expect(await errorOf(await put(tampered))).toEqual({ status: 403, error: "bad_signature" });
    const longer = signed.url.replace(/exp=(\d+)/, (_: string, e: string) => `exp=${Number(e) + 3600}`);
    expect(await errorOf(await put(longer))).toEqual({ status: 403, error: "bad_signature" });
    const other = wireClip(room.id, friend, { hour: 17 });
    await api("/v1/clips/upload-url", friend, { json: { clip: other } });
    expect(await errorOf(await put(signed.url.replace(clip.id, other.id)))).toEqual({ status: 403, error: "bad_signature" });

    const past = Math.floor(Date.now() / 1000) - 5;
    const expired = await signUploadURL(env, ORIGIN, clip.id, signed.storage_key, past);
    expect(await errorOf(await put(expired))).toEqual({ status: 403, error: "bad_signature" });
    expect((await put(signed.url)).status).toBe(204);
  });

  it("refuses an upload over the room's size cap", async () => {
    const { friend, room } = await logRoom();
    const signed = await body(await api("/v1/clips/upload-url", friend, { json: { clip: wireClip(room.id, friend, { hour: 18 }) } }));
    const huge = await SELF.fetch(signed.url, {
      method: "PUT", headers: { ...signed.headers, "Content-Length": String(26 * 1024 * 1024) }, body: CLIP_BYTES,
    });
    expect(huge.status).toBe(413);
  });

  it("plays back to members with byte ranges; 410 once the copy has expired", async () => {
    const { owner, friend, room } = await logRoom();
    const { signed } = await uploadAndPost(friend, wireClip(room.id, friend, { hour: 19 }));
    const sign = await api(`/v1/media/sign?key=${encodeURIComponent(signed.storage_key)}`, owner);
    expect(sign.status).toBe(200);
    const { url, expires_at } = await body(sign);
    expect(expires_at).toMatch(/Z$/);

    const whole = await SELF.fetch(url);
    expect(whole.status).toBe(200);
    expect(whole.headers.get("Content-Type")).toBe("video/quicktime");
    expect(whole.headers.get("Accept-Ranges")).toBe("bytes");
    expect(new Uint8Array(await whole.arrayBuffer())).toEqual(CLIP_BYTES);

    // AVPlayer's first request.
    const probe = await SELF.fetch(url, { headers: { Range: "bytes=0-1" } });
    expect(probe.status).toBe(206);
    expect(probe.headers.get("Content-Range")).toBe(`bytes 0-1/${CLIP_BYTES.length}`);
    expect(new Uint8Array(await probe.arrayBuffer())).toEqual(CLIP_BYTES.slice(0, 2));
    const tail = await SELF.fetch(url, { headers: { Range: "bytes=-4" } });
    expect(tail.status).toBe(206);
    expect(new Uint8Array(await tail.arrayBuffer())).toEqual(CLIP_BYTES.slice(-4));
    const beyond = await SELF.fetch(url, { headers: { Range: "bytes=500-" } });
    expect(beyond.status).toBe(416);

    const forged = url.replace(signed.storage_key.split("/").pop()!, "other.mov");
    expect((await SELF.fetch(forged)).status).toBe(403);
    const expired = await signDownloadURL(env, ORIGIN, signed.storage_key, Math.floor(Date.now() / 1000) - 1);
    expect((await SELF.fetch(expired)).status).toBe(403);

    await env.CLIPS.delete(signed.storage_key);
    expect(await errorOf(await SELF.fetch(url))).toEqual({ status: 410, error: "gone" });
  });

  it("a demo/ key plays for members of the room its rows are in", async () => {
    const { owner, room } = await logRoom();
    await env.CLIPS.put("demo/sample-clip.mov", CLIP_BYTES, { httpMetadata: { contentType: "video/quicktime" } });
    await env.DB.prepare(
      `INSERT INTO clips (id, room_id, member_id, day, hour, duration_ms, width, height, storage_key, status, one_per_slot, created_at)
       VALUES (?, ?, ?, ?, 8, 2000, 1080, 1920, 'demo/sample-clip.mov', 'posted', 1, '2020-01-01T08:00:00Z')`,
    ).bind(`demo-${crypto.randomUUID()}`, room.id, owner.id, today()).run();
    const sign = await api("/v1/media/sign?key=demo/sample-clip.mov", owner);
    expect(sign.status).toBe(200);
    expect((await SELF.fetch((await body(sign)).url)).status).toBe(200);
    expect((await api("/v1/media/sign?key=demo/sample-clip.mov", await newUser())).status).toBe(403);
  });
});

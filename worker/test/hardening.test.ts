import { env, SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { api, body, CLIP_BYTES, createRoom, errorOf, newUser, uploadAndPost, wireClip } from "./helpers";

describe("hardening from the pre-launch security review", () => {
  it("stores nothing when the body is longer than the declared Content-Length", async () => {
    const owner = await newUser("owner");
    const room = await createRoom(owner, { name: "solo", type: "vlog", capacity: 1 });
    const clip = wireClip(room.id, owner, { hour: 10 });
    const signed = await body(await api("/v1/clips/upload-url", owner, { json: { clip } }));
    const lying = await SELF.fetch(signed.url, {
      method: "PUT",
      headers: { ...signed.headers, "Content-Length": "4" },
      body: new ReadableStream({
        start(controller) {
          controller.enqueue(CLIP_BYTES);
          controller.close();
        },
      }),
      // @ts-expect-error -- Workers fetch accepts duplex for streamed bodies.
      duplex: "half",
    });
    expect(lying.status).toBeGreaterThanOrEqual(400);
    expect(await env.CLIPS.head(signed.storage_key)).toBeNull();
  });

  it("limits one person to twenty reports an hour", async () => {
    const reporter = await newUser("reporter");
    const target = await newUser("target");
    const report = { reporter_id: reporter.id, user_id: target.id, reason: "spam", created_at: new Date().toISOString() };
    for (let i = 0; i < 20; i++) {
      expect((await api("/v1/reports", reporter, { json: report })).status).toBe(204);
    }
    expect(await errorOf(await api("/v1/reports", reporter, { json: report }))).toEqual({ status: 429, error: "rate_limited" });
  });

  it("keeps a flood of support messages from one address out of the table, quietly", async () => {
    const send = () => SELF.fetch("https://vlogify.test/support", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ email: "flood@example.com", message: "hello there, this is a message" }),
      redirect: "manual",
    });
    for (let i = 0; i < 5; i++) {
      const response = await send();
      expect(response.headers.get("Location")).toContain("sent=1");
    }
    const stored = await env.DB.prepare("SELECT COUNT(*) AS n FROM support_messages WHERE email = ?")
      .bind("flood@example.com").first<{ n: number }>();
    expect(stored?.n).toBe(3);
  });

  it("caps a just-me room at a day's worth of clips per person", async () => {
    const owner = await newUser("prolific");
    const room = await createRoom(owner, { name: "solo", type: "vlog", capacity: 1 });
    const day = wireClip(room.id, owner).day;
    const rows = Array.from({ length: 300 }, (_, i) =>
      env.DB.prepare(
        `INSERT INTO clips (id, room_id, member_id, day, hour, duration_ms, width, height, storage_key, status, one_per_slot, created_at)
         VALUES (?, ?, ?, ?, 10, 2000, 1, 1, ?, 'posted', 0, ?)`,
      ).bind(`seed-${i}`, room.id, owner.id, day, `clips/${room.id}/${day}/seed-${i}.mov`, new Date().toISOString()));
    await env.DB.batch(rows);
    const next = wireClip(room.id, owner, { hour: 11 });
    expect(await errorOf(await api("/v1/clips/upload-url", owner, { json: { clip: next } })))
      .toEqual({ status: 429, error: "rate_limited" });
    // A room with one clip per hour is not affected by the cap.
    const friendsRoom = await createRoom(owner, { name: "friends", type: "log", capacity: 3 });
    expect((await uploadAndPost(owner, wireClip(friendsRoom.id, owner, { hour: 12 }))).posted?.status).toBe(201);
  });
});

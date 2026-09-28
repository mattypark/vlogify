import { env } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { api, body, createRoom, join, newUser, today, uploadAndPost, wireClip } from "./helpers";

async function roomOfThree() {
  const a = await newUser("ana");
  const b = await newUser("ben");
  const c = await newUser("cam");
  const room = await createRoom(a, { type: "log", capacity: 3 });
  await join(b, room.invite_code);
  await join(c, room.invite_code);
  const clipA = await body((await uploadAndPost(a, wireClip(room.id, a, { hour: 10 }))).posted!);
  const clipB = await body((await uploadAndPost(b, wireClip(room.id, b, { hour: 10 }))).posted!);
  return { a, b, c, room, clipA, clipB };
}

const ids = (list: { id?: string; user_id?: string }[]) => list.map((item) => item.user_id ?? item.id).sort();

describe("blocking", () => {
  it("hides both ways: members, clips and history, for the blocker and the blocked", async () => {
    const { a, b, c, room, clipA, clipB } = await roomOfThree();
    expect((await api("/v1/blocks", a, { json: { user_id: b.id } })).status).toBe(204);

    const seenByA = await body(await api(`/v1/rooms/${room.id}/days/${today()}`, a));
    expect(ids(seenByA.members)).toEqual([a.id, c.id].sort());
    expect(ids(seenByA.clips)).toEqual([clipA.id]);
    const seenByB = await body(await api(`/v1/rooms/${room.id}/days/${today()}`, b));
    expect(ids(seenByB.members)).toEqual([b.id, c.id].sort());
    expect(ids(seenByB.clips)).toEqual([clipB.id]);
    expect(ids(await body(await api(`/v1/rooms/${room.id}/members`, b)))).toEqual([b.id, c.id].sort());
    // A bystander still sees everyone.
    expect(ids((await body(await api(`/v1/rooms/${room.id}/days/${today()}`, c))).clips)).toEqual([clipA.id, clipB.id].sort());

    // The blocked person's media is off limits to the blocker too.
    expect((await api(`/v1/media/sign?key=${encodeURIComponent(clipB.storage_key)}`, a)).status).toBe(403);

    const blocked = await body(await api("/v1/blocks", a));
    expect(blocked).toHaveLength(1);
    expect(blocked[0]).toMatchObject({ id: b.id, display_name: "ben" });
    expect(await body(await api("/v1/blocks", b))).toEqual([]);

    expect((await api(`/v1/blocks/${b.id}`, a, { method: "DELETE" })).status).toBe(204);
    expect(ids((await body(await api(`/v1/rooms/${room.id}/days/${today()}`, a))).clips)).toEqual([clipA.id, clipB.id].sort());
  });

  it("blocking yourself is refused; blocking twice is fine", async () => {
    const a = await newUser();
    const b = await newUser();
    expect((await api("/v1/blocks", a, { json: { user_id: a.id } })).status).toBe(400);
    expect((await api("/v1/blocks", a, { json: { user_id: b.id } })).status).toBe(204);
    expect((await api("/v1/blocks", a, { json: { user_id: b.id } })).status).toBe(204);
    expect((await api("/v1/blocks", a, { json: { user_id: "gone-account" } })).status).toBe(204);
  });
});

describe("reports", () => {
  it("stores the report with the reporter from the session and hides the clip from the room", async () => {
    const { a, b, c, room, clipB } = await roomOfThree();
    const report = {
      reporter_id: "someone-else", clip_id: clipB.id, user_id: null, reason: "harassment", note: "not ok",
      created_at: "2026-09-28T10:00:00Z",
    };
    expect((await api("/v1/reports", a, { json: report })).status).toBe(204);
    const row = await env.DB.prepare("SELECT * FROM reports WHERE clip_id = ?").bind(clipB.id).first<Record<string, string>>();
    expect(row).toMatchObject({ reporter_id: a.id, user_id: b.id, room_id: room.id, reason: "harassment", note: "not ok" });

    expect(ids((await body(await api(`/v1/rooms/${room.id}/days/${today()}`, a))).clips)).not.toContain(clipB.id);
    // Open reports hide the clip from the whole room until a moderator resolves them.
    expect(ids((await body(await api(`/v1/rooms/${room.id}/days/${today()}`, c))).clips)).not.toContain(clipB.id);
  });

  it("a person can be reported without a clip; a report needs one or the other and a known reason", async () => {
    const a = await newUser();
    const b = await newUser();
    expect((await api("/v1/reports", a, { json: { user_id: b.id, reason: "impersonation" } })).status).toBe(204);
    expect((await api("/v1/reports", a, { json: { reason: "spam" } })).status).toBe(400);
    expect((await api("/v1/reports", a, { json: { user_id: b.id, reason: "boring" } })).status).toBe(400);
  });
});

describe("push", () => {
  it("register and unregister are accepted and do nothing", async () => {
    const a = await newUser();
    expect((await api("/v1/push/register", a, { json: { token: "abc" } })).status).toBe(204);
    expect((await api("/v1/push/register", a, { method: "DELETE" })).status).toBe(204);
  });
});

import { env } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { JOIN_MAX_FAILURES } from "../src/routes/rooms";
import { parseInviteCode } from "../src/rules";
import { api, body, createRoom, errorOf, join, newUser } from "./helpers";

describe("rooms", () => {
  it("creates a room with the owner in it and a valid invite code", async () => {
    const owner = await newUser("owner");
    const room = await createRoom(owner, { name: "  lololol testing  ", type: "log", capacity: 3 });
    expect(room).toMatchObject({ name: "lololol testing", type: "log", capacity: 3, owner_id: owner.id });
    expect(Object.keys(room).sort()).toEqual(["capacity", "created_at", "id", "invite_code", "name", "owner_id", "type"]);
    expect(parseInviteCode(room.invite_code)).toBe(room.invite_code);
    expect(room.created_at).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/);

    const listed = await body(await api("/v1/rooms", owner));
    expect(listed.map((r: { id: string }) => r.id)).toContain(room.id);
    expect(await body(await api(`/v1/rooms/${room.id}`, owner))).toEqual(room);
    const members = await body(await api(`/v1/rooms/${room.id}/members`, owner));
    expect(members).toHaveLength(1);
    expect(members[0]).toMatchObject({ room_id: room.id, user_id: owner.id, profile: { id: owner.id, display_name: "owner" } });
  });

  it("a nameless room has a null name", async () => {
    const owner = await newUser();
    expect((await createRoom(owner, { name: null, type: "vlog", capacity: 1 })).name).toBeNull();
    expect((await createRoom(owner, { name: "   ", type: "vlog", capacity: 1 })).name).toBeNull();
  });

  it("refuses capacities the rules do not allow, as room_full like the mock", async () => {
    const owner = await newUser();
    for (const draft of [{ type: "log", capacity: 1 }, { type: "log", capacity: 21 }, { type: "vlog", capacity: 2 }]) {
      expect(await errorOf(await api("/v1/rooms", owner, { json: draft }))).toEqual({ status: 409, error: "room_full" });
    }
    expect(await errorOf(await api("/v1/rooms", owner, { json: { type: "party", capacity: 3 } })))
      .toEqual({ status: 400, error: "bad_request" });
  });

  it("previews without joining, joins, is idempotent, and fills up", async () => {
    const owner = await newUser("owner");
    const friend = await newUser("friend");
    const late = await newUser("late");
    const room = await createRoom(owner, { type: "log", capacity: 2 });

    const preview = await body(await api(`/v1/rooms/preview/${room.invite_code.toLowerCase()}`, friend));
    expect(preview).toEqual({ room, member_count: 1 });
    expect((await api(`/v1/rooms/${room.id}`, friend)).status).toBe(403);

    // Formatted with a dash, as a person types it off the share sheet.
    const formatted = `${room.invite_code.slice(0, 3)}-${room.invite_code.slice(3)}`;
    expect(await body(await join(friend, formatted))).toEqual(room);
    expect(await body(await join(friend, room.invite_code))).toEqual(room);
    expect(await errorOf(await join(late, room.invite_code))).toEqual({ status: 409, error: "room_full" });
    expect((await body(await api(`/v1/rooms/preview/${room.invite_code}`, late))).member_count).toBe(2);
  });

  it("an unknown or mistyped code is invalid_code", async () => {
    const user = await newUser();
    expect(await errorOf(await join(user, "ZZZZZH"))).toEqual({ status: 404, error: "invalid_code" });
    expect(await errorOf(await join(user, "ZZZZZ0"))).toEqual({ status: 404, error: "invalid_code" });
    expect(await errorOf(await api("/v1/rooms/preview/nope", user))).toEqual({ status: 404, error: "invalid_code" });
  });

  it("rate-limits guessing: after ten misses even a good code waits", async () => {
    const owner = await newUser();
    const guesser = await newUser("guesser");
    const room = await createRoom(owner, { type: "log", capacity: 5 });
    for (let i = 0; i < JOIN_MAX_FAILURES; i++) {
      const miss = i % 2 ? await join(guesser, "000000") : await api("/v1/rooms/preview/ZZZZZH", guesser);
      expect(miss.status).toBe(404);
    }
    expect(await errorOf(await join(guesser, room.invite_code))).toEqual({ status: 429, error: "rate_limited" });
    expect(await errorOf(await api(`/v1/rooms/preview/${room.invite_code}`, guesser))).toEqual({ status: 429, error: "rate_limited" });
    // Someone else is unaffected.
    expect((await join(await newUser(), room.invite_code)).status).toBe(200);
  });

  it("only the owner removes members and regenerates the code; the old code stops working", async () => {
    const owner = await newUser("owner");
    const friend = await newUser("friend");
    const room = await createRoom(owner, { type: "log", capacity: 4 });
    await join(friend, room.invite_code);

    expect(await errorOf(await api(`/v1/rooms/${room.id}/invite`, friend, { method: "POST" })))
      .toEqual({ status: 403, error: "not_owner" });
    expect(await errorOf(await api(`/v1/rooms/${room.id}/members/${owner.id}`, friend, { method: "DELETE" })))
      .toEqual({ status: 403, error: "not_owner" });

    const { invite_code } = await body(await api(`/v1/rooms/${room.id}/invite`, owner, { method: "POST" }));
    expect(parseInviteCode(invite_code)).toBe(invite_code);
    expect(invite_code).not.toBe(room.invite_code);
    expect((await join(await newUser(), room.invite_code)).status).toBe(404);

    expect((await api(`/v1/rooms/${room.id}/members/${friend.id}`, owner, { method: "DELETE" })).status).toBe(204);
    expect((await api(`/v1/rooms/${room.id}`, friend)).status).toBe(403);
  });

  it("the owner leaving hands the room on; the last one out deletes it", async () => {
    const owner = await newUser("owner");
    const friend = await newUser("friend");
    const room = await createRoom(owner, { type: "log", capacity: 3 });
    await join(friend, room.invite_code);

    expect((await api(`/v1/rooms/${room.id}/leave`, owner, { method: "POST" })).status).toBe(204);
    expect((await body(await api(`/v1/rooms/${room.id}`, friend))).owner_id).toBe(friend.id);
    expect((await body(await api("/v1/rooms", owner))).map((r: { id: string }) => r.id)).not.toContain(room.id);

    expect((await api(`/v1/rooms/${room.id}/leave`, friend, { method: "POST" })).status).toBe(204);
    expect(await env.DB.prepare("SELECT id FROM rooms WHERE id = ?").bind(room.id).first()).toBeNull();
  });
});

import { env } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { api, body, createRoom, errorOf, join, newUser, uploadAndPost, wireClip } from "./helpers";

const FACE = "AR3bgNmU0qfHubnHp9KU2YDba9lY0kbHOLktpyaUJIAmay1YOEZGOFgtayZ_JJQmpy25OMdG0ljZa9t_AWFrAZ5rDaaRo5meoJilkKqIrICtd6xvqmelYaBcmVmR";

describe("profile", () => {
  it("updates name, colour and mark, each on its own", async () => {
    const user = await newUser("before");
    const named = await body(await api("/v1/me", user, { method: "PATCH", json: { display_name: "  a name that is far too long  " } }));
    expect(named.display_name).toBe("a name that is far t");
    // Any integer, wrapped like the mock: ((seed % 12) + 12) % 12.
    expect((await body(await api("/v1/me", user, { method: "PATCH", json: { avatar_seed: -1 } }))).avatar_seed).toBe(11);
    expect((await body(await api("/v1/me", user, { method: "PATCH", json: { avatar_seed: 25 } }))).avatar_seed).toBe(1);
    const marked = await body(await api("/v1/me", user, { method: "PATCH", json: { mark: FACE } }));
    expect(marked).toMatchObject({ id: user.id, display_name: "a name that is far t", avatar_seed: 1, mark: FACE });
    expect(await body(await api("/v1/me", user))).toEqual(marked);
  });

  it("refuses a mark the app could not draw, and keeps the old one", async () => {
    const user = await newUser();
    await api("/v1/me", user, { method: "PATCH", json: { mark: FACE } });
    for (const mark of ["", "!!", "AgEKCg", "AQUKCg", "A".repeat(1801)]) {
      expect(await errorOf(await api("/v1/me", user, { method: "PATCH", json: { mark } })), mark).toEqual({ status: 400, error: "bad_request" });
    }
    expect((await body(await api("/v1/me", user))).mark).toBe(FACE);
  });

  it("members see a friend's new mark in the room", async () => {
    const owner = await newUser();
    const friend = await newUser();
    const room = await createRoom(owner, { type: "log", capacity: 2 });
    await join(friend, room.invite_code);
    await api("/v1/me", friend, { method: "PATCH", json: { mark: FACE } });
    const members = await body(await api(`/v1/rooms/${room.id}/members`, owner));
    expect(members.find((m: { user_id: string }) => m.user_id === friend.id).profile.mark).toBe(FACE);
  });
});

describe("delete account", () => {
  it("removes every row and every R2 copy the person made, and the rooms they own", async () => {
    const leaver = await newUser("leaver");
    const other = await newUser("other");
    const owned = await createRoom(leaver, { type: "log", capacity: 3 });
    await join(other, owned.invite_code);
    const elsewhere = await createRoom(other, { type: "log", capacity: 3 });
    await join(leaver, elsewhere.invite_code);

    const mineInOwned = await uploadAndPost(leaver, wireClip(owned.id, leaver, { hour: 8 }));
    const theirsInOwned = await uploadAndPost(other, wireClip(owned.id, other, { hour: 8 }));
    const mineElsewhere = await uploadAndPost(leaver, wireClip(elsewhere.id, leaver, { hour: 9 }));
    const theirsElsewhere = await uploadAndPost(other, wireClip(elsewhere.id, other, { hour: 9 }));
    await api("/v1/blocks", leaver, { json: { user_id: other.id } });
    await api("/v1/me", leaver, { method: "PATCH", json: { mark: FACE } });

    expect((await api("/v1/account", leaver, { method: "DELETE" })).status).toBe(204);

    for (const table of ["users", "profiles"]) {
      expect(await env.DB.prepare(`SELECT 1 FROM ${table} WHERE id = ?`).bind(leaver.id).first(), table).toBeNull();
    }
    for (const [table, column] of [["memberships", "user_id"], ["clips", "member_id"], ["blocks", "blocker"], ["identities", "user_id"]]) {
      expect(await env.DB.prepare(`SELECT 1 FROM ${table} WHERE ${column} = ?`).bind(leaver.id).first(), table).toBeNull();
    }
    expect(await env.DB.prepare("SELECT 1 FROM rooms WHERE id = ?").bind(owned.id).first()).toBeNull();
    expect(await env.CLIPS.head(mineInOwned.signed.storage_key)).toBeNull();
    expect(await env.CLIPS.head(theirsInOwned.signed.storage_key)).toBeNull();
    expect(await env.CLIPS.head(mineElsewhere.signed.storage_key)).toBeNull();
    // Someone else's clip in someone else's room is theirs to keep.
    expect(await env.CLIPS.head(theirsElsewhere.signed.storage_key)).not.toBeNull();

    // The session died with the account.
    expect((await api("/v1/me", leaver)).status).toBe(401);
    const remaining = await body(await api(`/v1/rooms/${elsewhere.id}/members`, other));
    expect(remaining.map((m: { user_id: string }) => m.user_id)).toEqual([other.id]);
  });
});

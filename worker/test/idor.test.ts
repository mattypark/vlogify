// Someone who is not in a room must learn nothing about it and change nothing in it, whatever
// ids they put in the URL or the body.

import { env } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { api, body, createRoom, errorOf, join, newUser, today, uploadAndPost, wireClip } from "./helpers";

describe("outsiders", () => {
  it("get 403 on every room, clip and media route, and nothing changes", async () => {
    const owner = await newUser("owner");
    const friend = await newUser("friend");
    const outsider = await newUser("outsider");
    const room = await createRoom(owner, { type: "log", capacity: 3 });
    await join(friend, room.invite_code);
    const { signed, posted } = await uploadAndPost(friend, wireClip(room.id, friend, { hour: 11 }));
    const clip = await body(posted!);

    const checks: [string, string, unknown, string][] = [
      ["GET", `/v1/rooms/${room.id}`, undefined, "not_member"],
      ["GET", `/v1/rooms/${room.id}/members`, undefined, "not_member"],
      ["GET", `/v1/rooms/${room.id}/days/${today()}`, undefined, "not_member"],
      ["GET", `/v1/rooms/${room.id}/history`, undefined, "not_member"],
      ["POST", `/v1/rooms/${room.id}/leave`, undefined, "not_member"],
      ["POST", `/v1/rooms/${room.id}/invite`, undefined, "not_owner"],
      ["DELETE", `/v1/rooms/${room.id}/members/${friend.id}`, undefined, "not_owner"],
      ["POST", "/v1/clips/upload-url", { clip: wireClip(room.id, outsider) }, "not_member"],
      ["POST", "/v1/clips", { clip: { ...clip, member_id: outsider.id } }, "not_member"],
      ["DELETE", `/v1/clips/${clip.id}`, undefined, "not_owner"],
      ["GET", `/v1/media/sign?key=${encodeURIComponent(signed.storage_key)}`, undefined, "not_member"],
      ["POST", "/v1/reports", { clip_id: clip.id, reason: "spam" }, "not_member"],
      // A room that does not exist looks exactly like one you are not in.
      ["GET", "/v1/rooms/no-such-room", undefined, "not_member"],
    ];
    for (const [method, path, json, error] of checks) {
      const response = await api(path, outsider, json === undefined ? { method } : { method, json });
      expect(await errorOf(response), `${method} ${path}`).toEqual({ status: 403, error });
    }

    expect(await body(await api("/v1/rooms", outsider))).toEqual([]);
    const members = await env.DB.prepare("SELECT COUNT(*) AS n FROM memberships WHERE room_id = ?").bind(room.id).first<{ n: number }>();
    expect(members?.n).toBe(2);
    expect(await env.DB.prepare("SELECT id FROM clips WHERE id = ?").bind(clip.id).first()).not.toBeNull();
    expect((await body(await api(`/v1/rooms/${room.id}`, owner))).invite_code).toBe(room.invite_code);
  });

  it("a member who left loses access", async () => {
    const owner = await newUser();
    const friend = await newUser();
    const room = await createRoom(owner, { type: "log", capacity: 3 });
    await join(friend, room.invite_code);
    await api(`/v1/rooms/${room.id}/leave`, friend, { method: "POST" });
    expect((await api(`/v1/rooms/${room.id}/days/${today()}`, friend)).status).toBe(403);
  });

  it("cannot take over a clip id someone else is using", async () => {
    const owner = await newUser();
    const friend = await newUser();
    const room = await createRoom(owner, { type: "log", capacity: 3 });
    await join(friend, room.invite_code);
    const clip = wireClip(room.id, friend, { hour: 6 });
    await uploadAndPost(friend, clip);
    const stolen = await api("/v1/clips/upload-url", owner, { json: { clip: { ...clip, member_id: owner.id, hour: 14 } } });
    expect(await errorOf(stolen)).toEqual({ status: 400, error: "bad_request" });
    const reposted = await api("/v1/clips", owner, { json: { clip: { ...clip, member_id: owner.id } } });
    expect(await errorOf(reposted)).toEqual({ status: 400, error: "bad_request" });
  });
});

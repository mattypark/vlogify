import { env } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { maskProfanity } from "../src/filter";
import { api, body, createRoom, join, newUser, today, uploadAndPost, wireClip } from "./helpers";

describe("word filter", () => {
  it("masks offensive words, including spaced-out and number-swapped ones", () => {
    expect(maskProfanity("fuck this")).toBe("**** this");
    expect(maskProfanity("sh1t")).toBe("****");
    expect(maskProfanity("b.i.t.c.h")).toBe("*********");
    expect(maskProfanity("ass")).toBe("***");
  });

  it("leaves ordinary words alone", () => {
    for (const fine of ["classic", "spicy", "dickens", "Sunday people", "jiwoo", "matthew", "사랑", "Скотт"]) {
      expect(maskProfanity(fine)).toBe(fine);
    }
  });

  it("applies to display names and room names on the way in", async () => {
    const user = await newUser("x");
    const me = await body(await api("/v1/me", user, { method: "PATCH", json: { display_name: "shit head" } }));
    expect(me.display_name).toBe("**** head");
    const room = await createRoom(user, { name: "fuck club", type: "log", capacity: 3 });
    expect(room.name).toBe("**** club");
  });
});

describe("reports", () => {
  it("hide a clip from the whole room while open, and from the reporter for good", async () => {
    const owner = await newUser("owner");
    const friend = await newUser("friend");
    const third = await newUser("third");
    const room = await createRoom(owner, { name: "r", type: "log", capacity: 5 });
    await join(friend, room.invite_code);
    await join(third, room.invite_code);
    const clip = wireClip(room.id, friend, { hour: 9 });
    await uploadAndPost(friend, clip);
    const clipsFor = async (user: typeof owner) =>
      (await body(await api(`/v1/rooms/${room.id}/days/${today()}`, user))).clips.map((c: { id: string }) => c.id);

    expect(await clipsFor(third)).toContain(clip.id);
    const report = { reporter_id: owner.id, clip_id: clip.id, reason: "nudity", created_at: new Date().toISOString() };
    expect((await api("/v1/reports", owner, { json: report })).status).toBe(204);
    expect(await clipsFor(third)).not.toContain(clip.id);
    expect(await clipsFor(owner)).not.toContain(clip.id);

    // A moderator keeps it: back for everyone except the person who reported it.
    await env.DB.prepare("UPDATE reports SET resolved_at = ? WHERE clip_id = ?").bind(new Date().toISOString(), clip.id).run();
    expect(await clipsFor(third)).toContain(clip.id);
    expect(await clipsFor(owner)).not.toContain(clip.id);
  });
});

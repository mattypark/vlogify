import { env, SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { ORIGIN } from "./helpers";

function form(fields: Record<string, string>) {
  return SELF.fetch(`${ORIGIN}/support`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(fields).toString(),
    redirect: "manual",
  });
}

describe("site", () => {
  it("answers /health", async () => {
    const response = await SELF.fetch(`${ORIGIN}/health`);
    expect(await response.json()).toEqual({ ok: true });
  });

  it("serves the legal pages App Store Connect links to, and a 404 page for the rest", async () => {
    for (const path of ["/privacy", "/terms", "/support"]) {
      const response = await SELF.fetch(`${ORIGIN}${path}`);
      expect(response.status, path).toBe(200);
      expect(await response.text(), path).toContain("vlogify");
    }
    expect((await SELF.fetch(`${ORIGIN}/no-such-page`)).status).toBe(404);
  });

  it("stores a support message and sends the person back with ?sent=1", async () => {
    const response = await form({ email: "Someone@Example.com", message: "My friend cannot join the room." });
    expect(response.status).toBe(303);
    expect(response.headers.get("Location")).toBe("/support?sent=1");
    const row = await env.DB.prepare("SELECT email, message FROM support_messages WHERE email = ?")
      .bind("someone@example.com").first();
    expect(row).toEqual({ email: "someone@example.com", message: "My friend cannot join the room." });
  });

  it("a filled honeypot looks like success and stores nothing; junk fields get ?error=1", async () => {
    const bot = await form({ email: "bot@example.com", message: "buy things buy things", _gotcha: "http://spam" });
    expect(bot.headers.get("Location")).toBe("/support?sent=1");
    expect(await env.DB.prepare("SELECT 1 FROM support_messages WHERE email = ?").bind("bot@example.com").first()).toBeNull();
    expect((await form({ email: "not-an-email", message: "long enough message" })).headers.get("Location")).toBe("/support?error=1");
    expect((await form({ email: "a@example.com", message: "short" })).headers.get("Location")).toBe("/support?error=1");
  });

  it("unknown API paths are JSON 404s", async () => {
    const response = await SELF.fetch(`${ORIGIN}/v1/nothing-here`, { headers: { Authorization: "Bearer x" } });
    expect(response.status).toBe(401);
    const media = await SELF.fetch(`${ORIGIN}/media/upload/x`, { method: "POST" });
    expect(await media.json()).toEqual({ error: "not_found" });
  });
});

import { env } from "cloudflare:test";
import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT } from "jose";
import { describe, expect, it } from "vitest";
import { issueSession } from "../src/auth";
import { ApiError } from "../src/errors";
import { appleSignIn } from "../src/routes/auth";
import { sha256Hex } from "../src/util";
import { api, body, errorOf, newUser } from "./helpers";

async function appleFixture(nonce: string, overrides: { aud?: string; sub?: string } = {}) {
  const { publicKey, privateKey } = await generateKeyPair("RS256");
  const jwk = { ...(await exportJWK(publicKey)), kid: "test", alg: "RS256" };
  const token = await new SignJWT({ nonce: await sha256Hex(nonce) })
    .setProtectedHeader({ alg: "RS256", kid: "test" })
    .setIssuer("https://appleid.apple.com")
    .setAudience(overrides.aud ?? "com.matthewpark.vlogify")
    .setSubject(overrides.sub ?? `001234.${crypto.randomUUID()}.5678`)
    .setIssuedAt()
    .setExpirationTime("5m")
    .sign(privateKey);
  return { token, keys: createLocalJWKSet({ keys: [jwk] }) };
}

function signIn(token: string, nonce: string, extra: Record<string, string> = {}) {
  return { identity_token: token, nonce, ...extra };
}

async function refusal(promise: Promise<unknown>): Promise<string> {
  try {
    await promise;
  } catch (error) {
    if (error instanceof ApiError) return error.code;
    throw error;
  }
  return "accepted";
}

describe("Sign in with Apple", () => {
  it("makes the account on first sign-in, returns a working session, and finds it again", async () => {
    const sub = `001234.${crypto.randomUUID()}.5678`;
    const first = await appleFixture("nonce-first-123", { sub });
    const result = await appleSignIn(env, signIn(first.token, "nonce-first-123", { full_name: "  Jiwoo Park the Third, Esq.  " }), first.keys);
    expect(result.session.provider).toBe("apple");
    expect(result.session.issued_at).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/);

    const me = await api("/v1/me", { id: result.session.user_id, token: result.token });
    expect(me.status).toBe(200);
    const profile = await body(me);
    expect(profile.id).toBe(result.session.user_id);
    // Trimmed and capped at twenty characters.
    expect(profile.display_name).toBe("Jiwoo Park the Third");
    expect(profile.avatar_seed).toBeGreaterThanOrEqual(0);
    expect(profile.avatar_seed).toBeLessThanOrEqual(11);
    expect(profile.created_at).toMatch(/Z$/);
    expect(profile).not.toHaveProperty("mark");

    const again = await appleFixture("nonce-again-123", { sub });
    const second = await appleSignIn(env, signIn(again.token, "nonce-again-123"), again.keys);
    expect(second.session.user_id).toBe(result.session.user_id);
  });

  it("stores only a hash of the Apple subject", async () => {
    const sub = `001234.${crypto.randomUUID()}.5678`;
    const fixture = await appleFixture("nonce-hash-123", { sub });
    await appleSignIn(env, signIn(fixture.token, "nonce-hash-123"), fixture.keys);
    const { results } = await env.DB.prepare("SELECT sub_hash FROM identities").all<{ sub_hash: string }>();
    expect(results.every((row) => /^[0-9a-f]{64}$/.test(row.sub_hash) && !row.sub_hash.includes(sub))).toBe(true);
  });

  it("refuses a token minted for a different nonce", async () => {
    const { token, keys } = await appleFixture("the-right-nonce");
    expect(await refusal(appleSignIn(env, signIn(token, "another-nonce"), keys))).toBe("not_signed_in");
  });

  it("refuses a token made for another app", async () => {
    const { token, keys } = await appleFixture("nonce-aud-123", { aud: "com.someone.else" });
    expect(await refusal(appleSignIn(env, signIn(token, "nonce-aud-123"), keys))).toBe("not_signed_in");
  });

  it("refuses a banned account", async () => {
    const sub = `001234.${crypto.randomUUID()}.5678`;
    const first = await appleFixture("nonce-ban-1234", { sub });
    const { session } = await appleSignIn(env, signIn(first.token, "nonce-ban-1234"), first.keys);
    await env.DB.prepare("UPDATE users SET banned_at = ? WHERE id = ?").bind("2026-09-28T00:00:00Z", session.user_id).run();
    const again = await appleFixture("nonce-ban-5678", { sub });
    expect(await refusal(appleSignIn(env, signIn(again.token, "nonce-ban-5678"), again.keys))).toBe("banned");
  });

  it("answers a malformed token with not_signed_in and a malformed body with bad_request", async () => {
    const garbage = await api("/v1/auth/apple", null, { json: signIn("x".repeat(40), "nonce-12345") });
    expect(await errorOf(garbage)).toEqual({ status: 401, error: "not_signed_in" });
    const shapeless = await api("/v1/auth/apple", null, { json: { token: "nope" } });
    expect(await errorOf(shapeless)).toEqual({ status: 400, error: "bad_request" });
  });

  it("says Google and email sign-in are unsupported", async () => {
    for (const path of ["/v1/auth/google/begin", "/v1/auth/google/complete", "/v1/auth/email/request", "/v1/auth/email/verify"]) {
      expect(await errorOf(await api(path, null, { json: {} }))).toEqual({ status: 501, error: "unsupported" });
    }
  });
});

describe("sessions", () => {
  it("every /v1 route but sign-in needs a bearer token", async () => {
    for (const [method, path] of [
      ["GET", "/v1/me"], ["PATCH", "/v1/me"], ["DELETE", "/v1/account"], ["GET", "/v1/rooms"], ["POST", "/v1/rooms"],
      ["GET", "/v1/rooms/abc"], ["POST", "/v1/rooms/join"], ["GET", "/v1/rooms/preview/REV1EF"], ["POST", "/v1/clips"],
      ["POST", "/v1/clips/upload-url"], ["GET", "/v1/media/sign?key=x"], ["POST", "/v1/reports"], ["GET", "/v1/blocks"],
      ["POST", "/v1/push/register"],
    ] as const) {
      const response = await api(path, null, { method });
      expect(await errorOf(response), `${method} ${path}`).toEqual({ status: 401, error: "not_signed_in" });
    }
  });

  it("refuses a forged token, and a token for a deleted account", async () => {
    const forged = await api("/v1/me", { id: "x", token: "eyJhbGciOiJIUzI1NiJ9.e30.bad" });
    expect(forged.status).toBe(401);
    const user = await newUser();
    await env.DB.prepare("DELETE FROM users WHERE id = ?").bind(user.id).run();
    expect((await api("/v1/me", user)).status).toBe(401);
    // Signed with the right secret, for an id that never existed.
    const ghost = await issueSession(env, "never-existed", new Date());
    expect((await api("/v1/me", { id: "never-existed", token: ghost })).status).toBe(401);
  });
});

import { createMiddleware } from "hono/factory";
import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT, type JWTVerifyGetKey } from "jose";
import type { AppEnv, Env } from "./env";
import { fail } from "./errors";
import { hmacHex, now, openString, sealString, sha256Hex } from "./util";

const APPLE_ISSUER = "https://appleid.apple.com";
const SESSION_ISSUER = "vlogify";
/// There is no refresh flow in the contract, so a session lasts long enough that nobody is
/// signed out mid-season. Deleting or banning the account kills it early (requireUser).
const SESSION_TTL = "180d";
const appleJWKS = createRemoteJWKSet(new URL(`${APPLE_ISSUER}/auth/keys`));

/// Every bundle id Sign in with Apple may have been asked from.
export function appleAudiences(env: Env): string[] {
  return env.APPLE_BUNDLE_IDS.split(",").map((id) => id.trim()).filter(Boolean);
}

export interface VerifiedApple {
  sub: string;
  /// The bundle id the token was made for: the client id for the code exchange and revoke.
  audience: string;
}

/// Verifies an Apple identity token: Apple's signature, issuer, one of our bundle ids, not
/// expired, and a nonce equal to SHA-256 hex of the raw nonce the app kept. `keys` is
/// injectable so tests can sign their own tokens.
export async function verifyAppleToken(
  env: Env, identityToken: string, rawNonce: string, keys: JWTVerifyGetKey = appleJWKS,
): Promise<VerifiedApple> {
  let payload;
  try {
    ({ payload } = await jwtVerify(identityToken, keys, {
      issuer: APPLE_ISSUER,
      audience: appleAudiences(env),
      algorithms: ["RS256"],
    }));
  } catch {
    fail("not_signed_in", "Apple token did not verify");
  }
  if (payload.nonce !== (await sha256Hex(rawNonce))) fail("not_signed_in", "nonce mismatch");
  if (typeof payload.sub !== "string" || !payload.sub) fail("not_signed_in", "no subject");
  const audience = Array.isArray(payload.aud) ? payload.aud[0] : payload.aud;
  return { sub: payload.sub, audience: audience ?? appleAudiences(env)[0] ?? "" };
}

/// The hash an Apple account is stored under. The raw `sub` is never written anywhere.
export async function appleSubHash(env: Env, sub: string): Promise<string> {
  return hmacHex(env.PEPPER, `apple:${sub}`);
}

export async function issueSession(env: Env, userId: string, issuedAt: Date): Promise<string> {
  return new SignJWT({})
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(userId)
    .setIssuedAt(Math.floor(issuedAt.getTime() / 1000))
    .setExpirationTime(SESSION_TTL)
    .setIssuer(SESSION_ISSUER)
    .sign(new TextEncoder().encode(env.SESSION_SECRET));
}

export async function verifySession(env: Env, token: string): Promise<string> {
  const { payload } = await jwtVerify(token, new TextEncoder().encode(env.SESSION_SECRET), {
    issuer: SESSION_ISSUER,
    algorithms: ["HS256"],
  });
  if (!payload.sub) throw new Error("no subject");
  return payload.sub;
}

/// Bearer-token guard for every /v1 route except sign-in. A token for an account that was
/// deleted or banned stops working at once, whatever its expiry says.
export const requireUser = createMiddleware<AppEnv>(async (c, next) => {
  const header = c.req.header("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7).trim() : "";
  if (!token) fail("not_signed_in");
  let userId: string;
  try {
    userId = await verifySession(c.env, token);
  } catch {
    fail("not_signed_in");
  }
  const user = await c.env.DB.prepare("SELECT banned_at FROM users WHERE id = ?")
    .bind(userId).first<{ banned_at: string | null }>();
  if (!user || user.banned_at) fail("not_signed_in");
  c.set("userId", userId);
  await next();
});

// MARK: - Apple refresh token (kept only to revoke it when the account is deleted)

function appleKeyConfigured(env: Env): boolean {
  return Boolean(env.APPLE_TEAM_ID && env.APPLE_KEY_ID && env.APPLE_PRIVATE_KEY);
}

/// A .p8 key however it was pasted -- the whole file, one line, a literal "\n" between lines,
/// the base64 body alone -- rebuilt as the PEM `importPKCS8` accepts.
export function pemFromPasted(raw: string): string {
  const body = raw
    .replace(/\\n/g, "\n")
    .replace(/-----(BEGIN|END) [A-Z ]*PRIVATE KEY-----/g, "")
    .replace(/[^A-Za-z0-9+/=]/g, "");
  const lines = body.match(/.{1,64}/g) ?? [];
  return ["-----BEGIN PRIVATE KEY-----", ...lines, "-----END PRIVATE KEY-----"].join("\n");
}

async function appleClientSecret(env: Env, clientId: string): Promise<string> {
  const key = await importPKCS8(pemFromPasted(env.APPLE_PRIVATE_KEY ?? ""), "ES256");
  return new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: env.APPLE_KEY_ID })
    .setIssuer(env.APPLE_TEAM_ID ?? "")
    .setAudience(APPLE_ISSUER)
    .setSubject(clientId)
    .setIssuedAt()
    .setExpirationTime("5m")
    .sign(key);
}

/// Trades the one-time authorization code for a refresh token and keeps it sealed. Best effort:
/// sign-in succeeds without it; deletion just cannot revoke. Skipped when no key is set.
export async function keepAppleRefreshToken(env: Env, userId: string, code: string, clientId: string): Promise<void> {
  if (!appleKeyConfigured(env)) {
    console.log("apple: no Sign in with Apple key configured; skipping code exchange");
    return;
  }
  try {
    const response = await fetch(`${APPLE_ISSUER}/auth/token`, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        client_id: clientId,
        client_secret: await appleClientSecret(env, clientId),
        code,
        grant_type: "authorization_code",
      }),
    });
    if (!response.ok) {
      console.warn("apple: code exchange refused", response.status);
      return;
    }
    const json = (await response.json()) as { refresh_token?: string };
    if (!json.refresh_token) return;
    const sealed = await sealString(env.TOKEN_KEY, json.refresh_token);
    await env.DB.prepare(
      `INSERT INTO apple_tokens (user_id, client_id, refresh_enc, updated_at) VALUES (?, ?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET client_id = excluded.client_id, refresh_enc = excluded.refresh_enc,
         updated_at = excluded.updated_at`,
    ).bind(userId, clientId, sealed, now()).run();
  } catch (error) {
    console.warn("apple: code exchange failed", (error as Error).message);
  }
}

/// Revokes Apple's grant for an account being deleted. Reads the sealed token before the rows
/// go; call it with what `sealedAppleToken` returned.
export async function revokeAppleToken(env: Env, sealed: { client_id: string; refresh_enc: string } | null): Promise<void> {
  if (!sealed) return;
  if (!appleKeyConfigured(env)) {
    console.log("apple: no Sign in with Apple key configured; skipping revoke");
    return;
  }
  try {
    const token = await openString(env.TOKEN_KEY, sealed.refresh_enc);
    const response = await fetch(`${APPLE_ISSUER}/auth/revoke`, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        client_id: sealed.client_id,
        client_secret: await appleClientSecret(env, sealed.client_id),
        token,
        token_type_hint: "refresh_token",
      }),
    });
    if (!response.ok) console.warn("apple: revoke refused", response.status);
  } catch (error) {
    console.warn("apple: revoke failed", (error as Error).message);
  }
}

export async function sealedAppleToken(env: Env, userId: string) {
  return env.DB.prepare("SELECT client_id, refresh_enc FROM apple_tokens WHERE user_id = ?")
    .bind(userId).first<{ client_id: string; refresh_enc: string }>();
}

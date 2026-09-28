import { Hono } from "hono";
import type { JWTVerifyGetKey } from "jose";
import { z } from "zod";
import { appleSubHash, issueSession, keepAppleRefreshToken, verifyAppleToken } from "../auth";
import type { AppEnv, Env } from "../env";
import { fail } from "../errors";
import { readBody } from "../http";
import { createUser, userForIdentity } from "../users";
import { iso } from "../util";

export const authRoutes = new Hono<AppEnv>();

export const AppleBody = z.object({
  identity_token: z.string().min(20).max(8000),
  nonce: z.string().min(8).max(200),
  authorization_code: z.string().max(2000).nullish(),
  full_name: z.string().max(200).nullish(),
});

/// Sign in with Apple -> `{ token, session }`. The first sign-in makes the account; the name
/// Apple shares once becomes the display name.
authRoutes.post("/apple", async (c) => c.json(await appleSignIn(c.env, await readBody(c, AppleBody))));

/// Google and email sign-in need a sending domain and an OAuth client; neither exists yet.
/// The app hides both buttons when the backend answers `unsupported`.
for (const provider of ["google", "email"]) {
  authRoutes.all(`/${provider}`, () => fail("unsupported"));
  authRoutes.all(`/${provider}/*`, () => fail("unsupported"));
}

/// `keys` is injectable so tests can sign their own Apple tokens.
export async function appleSignIn(env: Env, body: z.infer<typeof AppleBody>, keys?: JWTVerifyGetKey) {
  const verified = await verifyAppleToken(env, body.identity_token, body.nonce, keys);
  const subHash = await appleSubHash(env, verified.sub);
  let user = await userForIdentity(env, subHash);
  if (!user) {
    try {
      await createUser(env, { displayName: body.full_name, identity: { subHash, provider: "apple" } });
    } catch {
      // Lost a race with this same person's other first sign-in; theirs is the account.
    }
    user = await userForIdentity(env, subHash);
  }
  if (!user) fail("server_error", "account was not created");
  if (user.banned_at) fail("banned");

  if (body.authorization_code) {
    await keepAppleRefreshToken(env, user.id, body.authorization_code, verified.audience);
  }
  const issuedAt = new Date(Math.floor(Date.now() / 1000) * 1000);
  return {
    token: await issueSession(env, user.id, issuedAt),
    session: { user_id: user.id, provider: "apple", issued_at: iso(issuedAt) },
  };
}

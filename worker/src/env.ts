/// Bindings, vars and secrets. Secrets come from `.dev.vars` locally and `wrangler secret put`
/// in production -- see `.dev.vars.example` for what each one is.
export interface Env {
  DB: D1Database;
  CLIPS: R2Bucket;
  ASSETS: Fetcher;

  /// Sign in with Apple audiences, comma-separated. The first is the app's bundle id.
  APPLE_BUNDLE_IDS: string;
  /// Days an uploaded clip stays in R2. The bucket's lifecycle rule is what deletes it.
  CLIP_TTL_DAYS: string;

  SESSION_SECRET: string;
  PEPPER: string;
  MEDIA_SIGNING_KEY: string;
  TOKEN_KEY: string;

  APPLE_TEAM_ID?: string;
  APPLE_KEY_ID?: string;
  APPLE_PRIVATE_KEY?: string;
  TG_BOT_TOKEN?: string;
  TG_CHAT_ID?: string;
}

/// Hono context variables set by the auth middleware.
export interface Vars {
  userId: string;
}

export type AppEnv = { Bindings: Env; Variables: Vars };

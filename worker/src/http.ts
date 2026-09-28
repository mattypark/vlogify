import type { Context } from "hono";
import type { z } from "zod";
import type { AppEnv } from "./env";
import { fail } from "./errors";

/// The request's JSON body, checked against `schema`. A body that is not JSON, or not the
/// shape, is `bad_request` -- the app never sends either, so the detail stays in the log.
export async function readBody<T extends z.ZodType>(c: Context<AppEnv>, schema: T): Promise<z.infer<T>> {
  let raw: unknown;
  try {
    raw = await c.req.json();
  } catch {
    fail("bad_request", "body is not JSON");
  }
  const parsed = schema.safeParse(raw);
  if (!parsed.success) {
    fail("bad_request", parsed.error.issues.map((issue) => `${issue.path.join(".")}: ${issue.message}`).join("; "));
  }
  return parsed.data;
}

/// The origin this request reached, for URLs the Worker signs for itself.
export function originOf(c: Context<AppEnv>): string {
  return new URL(c.req.url).origin;
}

/// Runs work after the response when there is an execution context (always, in production).
export function background(c: Context<AppEnv>, work: Promise<unknown>): void {
  try {
    c.executionCtx.waitUntil(work);
  } catch {
    // No execution context (called outside a request): let it run unawaited.
    void work;
  }
}

import { Hono } from "hono";
import { HTTPException } from "hono/http-exception";
import { requireUser } from "./auth";
import type { AppEnv } from "./env";
import { ApiError, type ErrorCode } from "./errors";
import { handleDownload, handleUpload } from "./media";
import { accountRoutes } from "./routes/account";
import { authRoutes } from "./routes/auth";
import { clipRoutes, mediaRoutes } from "./routes/clips";
import { roomRoutes } from "./routes/rooms";
import { safetyRoutes } from "./routes/safety";
import { handleSupport } from "./routes/support";

const app = new Hono<AppEnv>();

app.get("/health", (c) => c.json({ ok: true }));

// The API. Everything under /v1 needs a session except signing in.
app.route("/v1/auth", authRoutes);
app.use("/v1/*", async (c, next) => {
  if (c.req.path.startsWith("/v1/auth/")) return next();
  return requireUser(c, next);
});
app.route("/v1", accountRoutes);
app.route("/v1/rooms", roomRoutes);
app.route("/v1/clips", clipRoutes);
app.route("/v1/media", mediaRoutes);
app.route("/v1", safetyRoutes);
// v1 pings are local notifications scheduled on the phone from SlotPing, so there is nothing to
// register. Kept so the app's PushService has somewhere to call.
app.post("/v1/push/register", (c) => c.body(null, 204));
app.delete("/v1/push/register", (c) => c.body(null, 204));

// Media the Worker signed for itself: uploads in, playback out.
app.put("/media/upload/*", handleUpload);
app.on(["GET", "HEAD"], "/media/*", handleDownload);

// The site. /support is the Worker's only because the form posts to it.
app.get("/support", (c) => c.env.ASSETS.fetch(c.req.raw));
app.post("/support", handleSupport);

app.notFound((c) => {
  if (c.req.path.startsWith("/v1/") || c.req.path.startsWith("/media/")) return c.json({ error: "not_found" }, 404);
  return c.env.ASSETS.fetch(c.req.raw);
});

const STATUS_CODES: Partial<Record<number, ErrorCode>> = {
  400: "bad_request",
  401: "not_signed_in",
  404: "not_found",
  413: "too_large",
};

app.onError((error, c) => {
  if (error instanceof ApiError) {
    if (error.status >= 500) console.error("api", error.code, error.message);
    return c.json({ error: error.code }, error.status);
  }
  if (error instanceof HTTPException) {
    return c.json({ error: STATUS_CODES[error.status] ?? "bad_request" }, error.status);
  }
  console.error("unhandled", error);
  return c.json({ error: "server_error" }, 500);
});

export default app;
export { app };

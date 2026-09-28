import path from "node:path";
import { cloudflareTest, readD1Migrations } from "@cloudflare/vitest-pool-workers";
import { defineConfig } from "vitest/config";

export default defineConfig(async () => {
  const migrations = await readD1Migrations(path.join(import.meta.dirname, "migrations"));
  return {
    plugins: [
      cloudflareTest({
        wrangler: { configPath: "./wrangler.toml" },
        miniflare: {
          // Test-only secrets. Nothing here is real.
          bindings: {
            TEST_MIGRATIONS: migrations,
            SESSION_SECRET: "test-session-secret-0123456789abcdef",
            PEPPER: "test-pepper",
            MEDIA_SIGNING_KEY: "test-media-signing-key",
            TOKEN_KEY: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
            // A local .dev.vars is loaded too; its real keys must never reach a test.
            APPLE_TEAM_ID: "",
            APPLE_KEY_ID: "",
            APPLE_PRIVATE_KEY: "",
            TG_BOT_TOKEN: "",
            TG_CHAT_ID: "",
          },
        },
      }),
    ],
    test: {
      setupFiles: ["./test/setup.ts"],
    },
  };
});

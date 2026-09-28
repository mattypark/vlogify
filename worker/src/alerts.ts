import type { Env } from "./env";

/// Texts the moderator (Telegram) when a report or a support message arrives, so the 24-hour
/// response promise in docs/MODERATION.md does not depend on someone remembering to look.
/// Optional: without TG_BOT_TOKEN / TG_CHAT_ID it does nothing. Never throws -- an alert that
/// fails must not fail the report.
export async function alert(env: Env, text: string): Promise<void> {
  if (!env.TG_BOT_TOKEN || !env.TG_CHAT_ID) return;
  try {
    const response = await fetch(`https://api.telegram.org/bot${env.TG_BOT_TOKEN}/sendMessage`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ chat_id: env.TG_CHAT_ID, text: text.slice(0, 3500), disable_web_page_preview: true }),
    });
    if (!response.ok) console.warn("alert: telegram refused", response.status);
  } catch (error) {
    console.warn("alert: telegram failed", (error as Error).message);
  }
}

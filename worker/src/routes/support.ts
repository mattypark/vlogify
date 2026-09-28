import type { Context } from "hono";
import { alert } from "../alerts";
import type { AppEnv } from "../env";
import { background } from "../http";
import { now, randomId } from "../util";

const EMAIL = /^[^\s@]{1,64}@[^\s@]{1,190}\.[^\s@]{2,63}$/;

/// POST /support, the form on web/support.html. Form-encoded, no JavaScript. A filled honeypot
/// gets the same thank-you as a person, so a bot learns nothing. Always answers with a redirect
/// back to the page: `?sent=1` when stored, `?error=1` when the fields were not usable.
export async function handleSupport(c: Context<AppEnv>): Promise<Response> {
  let form: FormData;
  try {
    form = await c.req.formData();
  } catch {
    return c.redirect("/support?error=1", 303);
  }
  const field = (name: string) => {
    const value = form.get(name);
    return typeof value === "string" ? value.trim() : "";
  };
  if (field("_gotcha")) return c.redirect("/support?sent=1", 303);

  const email = field("email").toLowerCase();
  const message = field("message");
  if (!EMAIL.test(email) || email.length > 254 || message.length < 10 || message.length > 5000) {
    return c.redirect("/support?error=1", 303);
  }
  const id = randomId();
  await c.env.DB.prepare("INSERT INTO support_messages (id, email, message, created_at) VALUES (?, ?, ?, ?)")
    .bind(id, email, message, now()).run();
  background(c, alert(c.env, `vlogify support ${id} from ${email}:\n${message}`));
  return c.redirect("/support?sent=1", 303);
}

import { supabase } from "../_shared/supabase.ts";
import { handleSubmit, verifyTurnstile } from "./handler.ts";

const turnstileSecret = Deno.env.get("TURNSTILE_SECRET_KEY");
// Only for local development without a Turnstile key. Never set in production.
const skipCaptcha = Deno.env.get("SKIP_CAPTCHA_FOR_LOCAL_DEV") === "true";

Deno.serve((req) =>
  handleSubmit(req, {
    submit: async (fields) => {
      const { data, error } = await supabase.rpc("submit_enquiry", { p: fields });
      return error ? { data: null, error } : { data, error: null };
    },
    verifyCaptcha: (token, ip) => {
      if (skipCaptcha) return Promise.resolve(true);
      // Fail closed: without a secret key, no enquiry gets through.
      if (!turnstileSecret) return Promise.resolve(false);
      return verifyTurnstile(turnstileSecret, token, ip);
    },
  })
);

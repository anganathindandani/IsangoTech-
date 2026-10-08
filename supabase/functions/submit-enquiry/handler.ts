// Get started form → spam checks → public.submit_enquiry() in the database,
// which validates the answers, records consent and creates the lead (and the
// assessment booking, if a slot was picked).
import { json } from "../_shared/http.ts";

export interface Deps {
  /** Calls public.submit_enquiry(); returns its JSON or a database error code and message. */
  submit(fields: Record<string, unknown>): Promise<
    { data: { assessment_starts_at: string | null }; error: null } | {
      data: null;
      error: { code?: string; message: string };
    }
  >;
  /** Checks the Cloudflare Turnstile token. */
  verifyCaptcha(token: string, ip: string | null): Promise<boolean>;
}

const FIELDS = [
  "full_name",
  "business_name",
  "industry_id",
  "phone",
  "email",
  "stage_needed",
  "biggest_pain",
  "consent",
  "whatsapp_opt_in",
  "booking_slot_id",
] as const;

const MAX_BODY_BYTES = 10_000;

export async function handleSubmit(req: Request, deps: Deps): Promise<Response> {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: json(req, null).headers });
  if (req.method !== "POST") return json(req, { error: "Method not allowed" }, 405);

  const raw = await req.text();
  if (raw.length > MAX_BODY_BYTES) return json(req, { error: "Request too large" }, 413);

  let body: Record<string, unknown>;
  try {
    body = JSON.parse(raw);
    if (typeof body !== "object" || body === null || Array.isArray(body)) throw new Error();
  } catch {
    return json(req, { error: "Invalid request" }, 400);
  }

  // Honeypot: a field people never see. Bots that fill it get a normal-looking
  // reply and nothing is saved.
  if (typeof body.website === "string" && body.website.trim() !== "") {
    return json(req, { ok: true }, 201);
  }

  const token = typeof body.turnstile_token === "string" ? body.turnstile_token : "";
  const ip = req.headers.get("CF-Connecting-IP") ?? req.headers.get("X-Forwarded-For")?.split(",")[0].trim() ?? null;
  if (!token || !(await deps.verifyCaptcha(token, ip))) {
    return json(req, { error: "Please complete the spam check and try again." }, 400);
  }

  const fields: Record<string, unknown> = {};
  for (const key of FIELDS) {
    if (key in body) fields[key] = body[key];
  }

  const { data, error } = await deps.submit(fields);
  if (error) {
    if (error.code === "PT400") return json(req, { error: error.message }, 400);
    if (error.code === "PT409") return json(req, { error: error.message }, 409);
    console.error("submit_enquiry failed", error);
    return json(req, { error: "Something went wrong on our side. Please WhatsApp us instead." }, 500);
  }

  return json(req, { ok: true, assessment_starts_at: data.assessment_starts_at ?? null }, 201);
}

export async function verifyTurnstile(secret: string, token: string, ip: string | null): Promise<boolean> {
  const form = new FormData();
  form.append("secret", secret);
  form.append("response", token);
  if (ip) form.append("remoteip", ip);
  const res = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", { method: "POST", body: form });
  if (!res.ok) return false;
  const result = await res.json();
  return result.success === true;
}

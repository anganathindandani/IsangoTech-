// IsangoTech admins add a business and its owner from the business app.
// Creates the owner's login (or reuses an existing one), the business and the
// membership, and returns a one-time link the owner opens to choose their
// password. The link is shared on WhatsApp, so no email setup is needed.

import { corsHeaders } from "../send-message/handler.ts";

export interface Deps {
  /** As the signed-in person: are they an IsangoTech admin? */
  isAdmin(): Promise<boolean>;
  /** Service role: an existing login's id, or null. */
  findUser(email: string): Promise<string | null>;
  /** Service role: a new confirmed login with an unusable random password. */
  createUser(email: string): Promise<string>;
  /** Service role: the business and its owner, in one step. */
  createBusiness(business: BusinessInput, ownerUserId: string, ownerName: string): Promise<string>;
  /** Service role: a one-time link to choose a password. */
  setupLink(email: string): Promise<string>;
  allowedOrigins: string[];
}

export interface BusinessInput {
  name: string;
  industry: string;
  products: string[];
  whatsapp_phone_number_id?: string;
  whatsapp_display_number?: string;
  monthly_conversation_allowance?: number;
}

const INDUSTRIES = ["salon", "guesthouse", "restaurant", "caterer", "other"];
const PRODUCTS = ["assistant", "portal"];
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const text = (v: unknown, max = 200) => (typeof v === "string" ? v.trim().slice(0, max) : "");

/** Checks the form; returns the clean business, or the first problem. */
export function readBusiness(v: unknown): BusinessInput | string {
  const b = (v ?? {}) as Record<string, unknown>;
  const name = text(b.name);
  if (!name) return "Give the business a name.";
  const industry = text(b.industry);
  if (!INDUSTRIES.includes(industry)) return "Choose the kind of business.";
  const products = Array.isArray(b.products)
    ? b.products.filter((p) => PRODUCTS.includes(p as string)) as string[]
    : [];
  if (!products.length) return "Choose at least one product.";
  const allowance = b.monthly_conversation_allowance === undefined ? 300 : Number(b.monthly_conversation_allowance);
  if (!Number.isInteger(allowance) || allowance < 0) return "The conversation allowance must be a whole number.";
  return {
    name,
    industry,
    products,
    whatsapp_phone_number_id: text(b.whatsapp_phone_number_id, 64) || undefined,
    whatsapp_display_number: text(b.whatsapp_display_number, 32) || undefined,
    monthly_conversation_allowance: allowance,
  };
}

export async function handleOnboard(req: Request, deps: Deps): Promise<Response> {
  const headers = { ...corsHeaders(req, deps.allowedOrigins), "Content-Type": "application/json" };
  const reply = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers });
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers });
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405);

  let input: Record<string, unknown>;
  try {
    input = await req.json();
  } catch {
    return reply({ error: "Invalid request" }, 400);
  }

  let admin = false;
  try {
    admin = await deps.isAdmin();
  } catch {
    admin = false;
  }
  if (!admin) return reply({ error: "Only IsangoTech admins can do this." }, 403);

  try {
    if (input.action === "link") {
      const email = text(input.email).toLowerCase();
      if (!(await deps.findUser(email))) return reply({ error: "There's no login with that email." }, 404);
      return reply({ setup_link: await deps.setupLink(email) });
    }

    const business = readBusiness(input.business);
    if (typeof business === "string") return reply({ error: business }, 400);
    const owner = (input.owner ?? {}) as Record<string, unknown>;
    const ownerName = text(owner.full_name);
    const email = text(owner.email).toLowerCase();
    if (!ownerName) return reply({ error: "Give the owner's name." }, 400);
    if (!EMAIL.test(email)) return reply({ error: "That email address doesn't look right." }, 400);

    const existing = await deps.findUser(email);
    const userId = existing ?? (await deps.createUser(email));
    const businessId = await deps.createBusiness(business, userId, ownerName);
    return reply({ business_id: businessId, new_login: !existing, setup_link: await deps.setupLink(email) }, 201);
  } catch (err) {
    const message = err instanceof Error ? err.message : "";
    if (message.includes("whatsapp_phone_number_id")) {
      return reply({ error: "Another business already uses that WhatsApp number." }, 409);
    }
    return reply({ error: "Something went wrong. Please try again." }, 500);
  }
}

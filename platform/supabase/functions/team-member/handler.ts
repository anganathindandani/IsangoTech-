// Owners add managers and staff from the business app. Creates the person's
// login (or reuses an existing one) and their membership, and returns a
// one-time setup link to share on WhatsApp.
//
// A setup link lets whoever opens it set the password, so one is only given
// for a manager or staff member whose login belongs to this business alone
// (team_link_target). Adding the email of someone who already has a login
// elsewhere gives them access here, never their account.

import { corsHeaders } from "../send-message/handler.ts";

export interface Deps {
  /** As the signed-in person: do they own this business? */
  isOwner(businessId: string): Promise<boolean>;
  findUser(email: string): Promise<string | null>;
  createUser(email: string): Promise<string>;
  addMember(businessId: string, userId: string, fullName: string, role: string, staffId: string | null): Promise<void>;
  /** The login a setup link may be made for, or null if it isn't allowed. */
  linkTarget(businessId: string, email: string): Promise<string | null>;
  setupLink(email: string): Promise<string>;
  allowedOrigins: string[];
}

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const text = (v: unknown, max = 200) => (typeof v === "string" ? v.trim().slice(0, max) : "");

export async function handleTeam(req: Request, deps: Deps): Promise<Response> {
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
  const businessId = text(input.business_id, 64);
  const email = text(input.email).toLowerCase();

  let owner = false;
  try {
    owner = !!businessId && await deps.isOwner(businessId);
  } catch {
    owner = false;
  }
  if (!owner) return reply({ error: "Only the business owner can manage the team." }, 403);
  if (!EMAIL.test(email)) return reply({ error: "That email address doesn't look right." }, 400);

  try {
    if (input.action === "link") {
      if (!(await deps.linkTarget(businessId, email))) {
        return reply({
          error: "A setup link isn't available for this person. If they've forgotten their password, ask IsangoTech.",
        }, 403);
      }
      return reply({ setup_link: await deps.setupLink(email) });
    }

    const fullName = text(input.full_name);
    const role = text(input.role);
    const staffId = text(input.staff_id, 64) || null;
    if (!fullName) return reply({ error: "Give their name." }, 400);
    if (role !== "manager" && role !== "staff") return reply({ error: "Choose manager or staff." }, 400);

    const existing = await deps.findUser(email);
    const userId = existing ?? (await deps.createUser(email));
    await deps.addMember(businessId, userId, fullName, role, role === "staff" ? staffId : null);
    const linkAllowed = !existing || (await deps.linkTarget(businessId, email)) !== null;
    return reply({ new_login: !existing, setup_link: linkAllowed ? await deps.setupLink(email) : null }, 201);
  } catch (err) {
    const message = err instanceof Error ? err.message : "";
    if (message.includes("already has a login")) return reply({ error: "That staff member already has a login." }, 409);
    return reply({ error: "Something went wrong. Please try again." }, 500);
  }
}

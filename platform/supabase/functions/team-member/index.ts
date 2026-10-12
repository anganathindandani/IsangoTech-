import { createClient } from "jsr:@supabase/supabase-js@2";
import { handleTeam } from "./handler.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const service = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
const appUrl = (Deno.env.get("APP_URL") ?? "https://app.isangotech.co.za").replace(/\/$/, "");
const allowedOrigins = (Deno.env.get("APP_ORIGINS") ?? appUrl).split(",").map((o) => o.trim()).filter(Boolean);

async function rpc<T>(client: typeof service, fn: string, args: Record<string, unknown>): Promise<T> {
  const { data, error } = await client.rpc(fn, args);
  if (error) throw new Error(error.message);
  return data as T;
}

Deno.serve((req) => {
  const asUser = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    auth: { persistSession: false },
  });
  return handleTeam(req, {
    isOwner: async (businessId) =>
      (await rpc<boolean>(asUser, "is_business_owner", { p_business: businessId })) === true,
    findUser: async (email) => (await rpc<string | null>(service, "user_id_by_email", { p_email: email })) ?? null,
    createUser: async (email) => {
      // A random password nobody knows; they set their own with the setup link.
      const password = crypto.randomUUID() + crypto.randomUUID();
      const { data, error } = await service.auth.admin.createUser({ email, password, email_confirm: true });
      if (error || !data.user) throw new Error(error?.message ?? "Could not create the login");
      return data.user.id;
    },
    addMember: (businessId, userId, fullName, role, staffId) =>
      rpc(service, "add_team_member", {
        p_business: businessId,
        p_user: userId,
        p_full_name: fullName,
        p_role: role,
        p_staff_id: staffId,
      }),
    linkTarget: async (businessId, email) =>
      (await rpc<string | null>(service, "team_link_target", { p_business: businessId, p_email: email })) ?? null,
    setupLink: async (email) => {
      const { data, error } = await service.auth.admin.generateLink({
        type: "recovery",
        email,
        options: { redirectTo: `${appUrl}/set-password` },
      });
      if (error || !data.properties?.action_link) throw new Error(error?.message ?? "Could not create the link");
      return data.properties.action_link;
    },
    allowedOrigins,
  });
});

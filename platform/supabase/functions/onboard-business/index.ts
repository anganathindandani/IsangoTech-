import { createClient } from "jsr:@supabase/supabase-js@2";
import { handleOnboard } from "./handler.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const service = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
const appUrl = (Deno.env.get("APP_URL") ?? "https://app.isangotech.co.za").replace(/\/$/, "");
const allowedOrigins = (Deno.env.get("APP_ORIGINS") ?? appUrl).split(",").map((o) => o.trim()).filter(Boolean);

Deno.serve((req) => {
  const asUser = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    auth: { persistSession: false },
  });
  return handleOnboard(req, {
    isAdmin: async () => {
      const { data, error } = await asUser.rpc("is_platform_admin");
      if (error) throw new Error(error.message);
      return data === true;
    },
    findUser: async (email) => {
      const { data, error } = await service.rpc("user_id_by_email", { p_email: email });
      if (error) throw new Error(error.message);
      return (data as string | null) ?? null;
    },
    createUser: async (email) => {
      // A random password nobody knows; the owner sets their own with the setup link.
      const password = crypto.randomUUID() + crypto.randomUUID();
      const { data, error } = await service.auth.admin.createUser({ email, password, email_confirm: true });
      if (error || !data.user) throw new Error(error?.message ?? "Could not create the login");
      return data.user.id;
    },
    createBusiness: async (business, ownerUserId, ownerName) => {
      const { data, error } = await service.rpc("onboard_business", {
        p_business: business,
        p_owner_user: ownerUserId,
        p_owner_name: ownerName,
      });
      if (error) throw new Error(error.message);
      return data as string;
    },
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

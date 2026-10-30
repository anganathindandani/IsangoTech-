import { createClient } from "jsr:@supabase/supabase-js@2";
import { sendText } from "../whatsapp-webhook/whatsapp.ts";
import { supabase } from "../_shared/supabase.ts";
import { databaseLookup, tokenFor } from "../_shared/whatsapp_token.ts";
import { handleSend } from "./handler.ts";

const graphVersion = Deno.env.get("WHATSAPP_GRAPH_VERSION") ?? "v23.0";
// Only the token lookup uses the service role; everything else runs as the signed-in person.
const accessToken = tokenFor(
  databaseLookup((fn, args) => supabase.rpc(fn, args)),
  Deno.env.get("WHATSAPP_ACCESS_TOKEN") ?? "",
);
const allowedOrigins = (Deno.env.get("APP_ORIGINS") ?? "https://app.isangotech.co.za")
  .split(",").map((o) => o.trim()).filter(Boolean);

Deno.serve((req) => {
  // A client that acts as the signed-in person, so the database's own checks decide.
  const asUser = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    auth: { persistSession: false },
  });
  const rpc = async (fn: string, args: Record<string, unknown>) => {
    const { data, error } = await asUser.rpc(fn, args);
    if (error) throw new Error(error.message);
    return data;
  };
  return handleSend(req, {
    prepare: (id) => rpc("prepare_person_reply", { p_conversation: id }),
    send: async (from, to, body) => sendText({ accessToken: await accessToken(from), graphVersion }, from, to, body),
    record: async (id, body, wamid) => {
      await rpc("record_person_reply", { p_conversation: id, p_body: body, p_whatsapp_message_id: wamid });
    },
    allowedOrigins,
  });
});

import { supabase } from "../_shared/supabase.ts";
import { sendTemplate, sendText } from "../whatsapp-webhook/whatsapp.ts";
import { handleReminders, type Release, type Reminder } from "./handler.ts";

const whatsapp = {
  accessToken: Deno.env.get("WHATSAPP_ACCESS_TOKEN") ?? "",
  graphVersion: Deno.env.get("WHATSAPP_GRAPH_VERSION") ?? "v23.0",
};

Deno.serve((req) =>
  handleReminders(req, {
    secret: Deno.env.get("REMINDERS_SECRET") ?? "",
    claim: async () => {
      const { data, error } = await supabase.rpc("claim_due_reminders", { p_limit: 50 });
      if (error) throw new Error(error.message);
      return data as Reminder[];
    },
    send: (r) =>
      sendTemplate(whatsapp, r.phone_number_id, r.to, {
        name: r.template,
        language: r.language,
        parameters: r.parameters,
      }),
    record: async (bookingId, wamid, body, cost) => {
      const { error } = await supabase.rpc("record_reminder", {
        p_booking: bookingId,
        p_whatsapp_message_id: wamid,
        p_body: body,
        p_cost_zar: cost,
      });
      if (error) throw new Error(error.message);
    },
    release: async () => {
      const { data, error } = await supabase.rpc("release_unpaid_bookings", { p_limit: 50 });
      if (error) throw new Error(error.message);
      return data as Release[];
    },
    sendText: (phoneNumberId, to, body) => sendText(whatsapp, phoneNumberId, to, body),
    recordMessage: async (conversationId, body, wamid) => {
      const { error } = await supabase.rpc("assistant_record_reply", {
        p_conversation: conversationId,
        p_body: body,
        p_whatsapp_message_id: wamid,
      });
      if (error) throw new Error(error.message);
    },
    templateCostZar: Number(Deno.env.get("WHATSAPP_TEMPLATE_COST_ZAR") ?? "0"),
    log: console.error,
  })
);

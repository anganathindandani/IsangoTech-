import { supabase } from "../_shared/supabase.ts";
import { databaseLookup, tokenFor } from "../_shared/whatsapp_token.ts";
import { openRouter } from "./ai.ts";
import type { Db } from "./engine.ts";
import { handleWebhook } from "./handler.ts";
import { sendText } from "./whatsapp.ts";

const env = (name: string, fallback?: string) => {
  const value = Deno.env.get(name) ?? fallback;
  if (value === undefined) throw new Error(`Missing secret ${name}`);
  return value;
};

async function rpc<T>(fn: string, args: Record<string, unknown>): Promise<T> {
  const { data, error } = await supabase.rpc(fn, args);
  if (error) throw new Error(`${fn}: ${error.message}`);
  return data as T;
}

const db: Db = {
  receive: (m) =>
    rpc("assistant_receive", {
      p_phone_number_id: m.phoneNumberId,
      p_from: m.from,
      p_profile_name: m.profileName,
      p_whatsapp_message_id: m.id,
      p_body: m.body,
    }),
  context: (conversationId) => rpc("assistant_context", { p_conversation: conversationId }),
  tool: (conversationId, name, args) =>
    rpc("assistant_tool", { p_conversation: conversationId, p_name: name, p_args: args }),
  recordReply: (conversationId, body, id) =>
    rpc("assistant_record_reply", { p_conversation: conversationId, p_body: body, p_whatsapp_message_id: id }),
  recordAiCall: (conversationId, c) =>
    rpc("assistant_record_ai_call", {
      p_conversation: conversationId,
      p_model: c.model,
      p_input_tokens: c.inputTokens,
      p_cached_input_tokens: c.cachedInputTokens,
      p_output_tokens: c.outputTokens,
      p_cost_zar: c.costZar,
    }),
};

const graphVersion = env("WHATSAPP_GRAPH_VERSION", "v23.0");
const accessToken = tokenFor(databaseLookup((fn, args) => supabase.rpc(fn, args)), env("WHATSAPP_ACCESS_TOKEN"));

Deno.serve((req) =>
  handleWebhook(req, {
    verifyToken: env("WHATSAPP_VERIFY_TOKEN"),
    appSecret: env("WHATSAPP_APP_SECRET"),
    db,
    ai: openRouter({ apiKey: env("OPENROUTER_API_KEY"), model: env("ASSISTANT_MODEL", "anthropic/claude-haiku-5.5") }),
    send: async (phoneNumberId, to, body) =>
      sendText({ accessToken: await accessToken(phoneNumberId), graphVersion }, phoneNumberId, to, body),
    usdToZar: Number(env("USD_TO_ZAR", "18")),
    // deno-lint-ignore no-explicit-any
    waitUntil: (work) => (globalThis as any).EdgeRuntime?.waitUntil?.(work) ?? work,
    log: console.error,
  })
);

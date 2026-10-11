// One customer message in, one reply out: the AI reads the chat, uses tools
// against the database until it has an answer, and the answer goes back on
// WhatsApp.
import type { Ai, ChatMessage } from "./ai.ts";
import { buildMessages, type Context, TOOLS } from "./prompt.ts";
import type { Incoming } from "./whatsapp.ts";

export type ReceiveStatus = "unknown_number" | "duplicate" | "person" | "assistant_off" | "reply";

export interface Db {
  receive(m: Incoming): Promise<{ status: ReceiveStatus; conversation_id?: string; new_customer?: boolean }>;
  context(conversationId: string): Promise<Context>;
  tool(conversationId: string, name: string, args: unknown): Promise<unknown>;
  recordReply(conversationId: string, body: string, whatsappMessageId: string): Promise<void>;
  recordAiCall(
    conversationId: string,
    call: { model: string; inputTokens: number; cachedInputTokens: number; outputTokens: number; costZar: number },
  ): Promise<void>;
}

export interface EngineDeps {
  db: Db;
  ai: Ai;
  send(phoneNumberId: string, to: string, body: string): Promise<string>;
  /** Rand per US dollar, for recording what AI calls cost. */
  usdToZar: number;
  log?: (message: string) => void;
}

/** Enough rounds to look up services, check a day and book, with room to spare. */
const MAX_ROUNDS = 6;
const MAX_REPLY_CHARS = 1500;

export async function handleMessage(m: Incoming, deps: EngineDeps): Promise<void> {
  const received = await deps.db.receive(m);
  if (received.status !== "reply" || !received.conversation_id) return;
  const conversationId = received.conversation_id;

  let reply: string;
  try {
    reply = await think(conversationId, deps) ?? await handOver(conversationId, deps, "no answer");
  } catch (err) {
    deps.log?.(`assistant error in ${conversationId}: ${err instanceof Error ? err.message : err}`);
    reply = await handOver(conversationId, deps, "assistant error");
  }

  // If the customer wrote again while this run was thinking, the run for
  // their newer message answers both; this one stays quiet.
  const latest = await deps.db.context(conversationId);
  if (latest.last_inbound && latest.last_inbound !== m.id) return;

  if (received.new_customer && latest.settings.privacy_notice_url) {
    reply += `\n\nHow ${latest.business.name} looks after your information: ${latest.settings.privacy_notice_url}`;
  }
  const sentId = await deps.send(m.phoneNumberId, m.from, reply.slice(0, MAX_REPLY_CHARS));
  await deps.db.recordReply(conversationId, reply, sentId);
}

/** Runs the model and its tools; returns the reply text, or null if it never settled on one. */
async function think(conversationId: string, deps: EngineDeps): Promise<string | null> {
  const messages: ChatMessage[] = buildMessages(await deps.db.context(conversationId));
  for (let round = 0; round < MAX_ROUNDS; round++) {
    const result = await deps.ai.chat(messages, TOOLS);
    await deps.db.recordAiCall(conversationId, {
      model: deps.ai.model,
      inputTokens: result.usage.inputTokens,
      cachedInputTokens: result.usage.cachedInputTokens,
      outputTokens: result.usage.outputTokens,
      costZar: Math.round(result.usage.costUsd * deps.usdToZar * 10_000) / 10_000,
    });
    if (!result.toolCalls.length) return result.text;

    messages.push({ role: "assistant", content: result.text, tool_calls: result.toolCalls });
    for (const call of result.toolCalls) {
      let output: unknown;
      try {
        output = await deps.db.tool(conversationId, call.function.name, JSON.parse(call.function.arguments || "{}"));
      } catch (err) {
        output = { ok: false, error: err instanceof SyntaxError ? "Arguments were not valid JSON" : "Tool failed" };
      }
      messages.push({ role: "tool", tool_call_id: call.id, content: JSON.stringify(output) });
    }
  }
  return null;
}

/** Passes the chat to a person and returns the message telling the customer so. */
async function handOver(conversationId: string, deps: EngineDeps, reason: string): Promise<string> {
  await deps.db.tool(conversationId, "hand_over", { reason });
  const ctx = await deps.db.context(conversationId);
  return `Thanks for your message. Someone from ${ctx.business.name} will reply to you shortly.`;
}

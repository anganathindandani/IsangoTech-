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
export const MAX_REPLY_CHARS = 1500;

/**
 * First-reply notice for a new customer. Always names the automated assistant,
 * offers to pass the chat on, and includes a privacy line (link or plain).
 * The business name falls back to "this business" when empty.
 */
export function newCustomerNotice(businessName: string, privacyNoticeUrl: string | null): string {
  const name = businessName.trim() || "this business";
  const intro = `Hi! I'm the automated assistant for ${name} on WhatsApp. ` +
    `If I can't help, just ask and I'll pass your message on to the team.`;
  if (privacyNoticeUrl) {
    // Link alone on the next line so nothing sits after the URL.
    return `${intro}\nHow ${name} looks after your information:\n${privacyNoticeUrl}`;
  }
  // Capitalise when the fallback starts the privacy sentence.
  const who = name === "this business" ? "This business" : name;
  return `${intro}\n${who} only uses your details to help with your enquiry or booking.`;
}

export async function handleMessage(m: Incoming, deps: EngineDeps): Promise<void> {
  const received = await deps.db.receive(m);
  if (received.status !== "reply" || !received.conversation_id) return;
  const conversationId = received.conversation_id;

  let reply: string;
  try {
    reply = await think(conversationId, deps, received.new_customer) ??
      await handOver(conversationId, deps, "no answer");
  } catch (err) {
    deps.log?.(`assistant error in ${conversationId}: ${err instanceof Error ? err.message : err}`);
    reply = await handOver(conversationId, deps, "assistant error");
  }

  // If the customer wrote again while this run was thinking, the run for
  // their newer message answers both; this one stays quiet.
  const latest = await deps.db.context(conversationId);
  if (latest.last_inbound && latest.last_inbound !== m.id) return;

  // Notice first so the 1500-char cap can't cut the disclosure off; the AI
  // reply is trimmed to whatever room is left after the notice and blank line.
  let outbound: string;
  if (received.new_customer) {
    const notice = newCustomerNotice(latest.business.name, latest.settings.privacy_notice_url);
    const room = Math.max(0, MAX_REPLY_CHARS - notice.length - 2);
    outbound = `${notice}\n\n${reply.slice(0, room)}`;
  } else {
    outbound = reply.slice(0, MAX_REPLY_CHARS);
  }

  const sentId = await deps.send(m.phoneNumberId, m.from, outbound);
  await deps.db.recordReply(conversationId, outbound, sentId);
}

/** Runs the model and its tools; returns the reply text, or null if it never settled on one. */
async function think(
  conversationId: string,
  deps: EngineDeps,
  newCustomer?: boolean,
): Promise<string | null> {
  const messages: ChatMessage[] = buildMessages(await deps.db.context(conversationId), { newCustomer });
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

// An owner or manager replies to a customer from the dashboard. The database
// checks they may, and that WhatsApp's 24-hour window is still open; this
// function sends the message and records it.

export interface Deps {
  /** As the signed-in person: may they reply, and from which number to which? */
  prepare(conversationId: string): Promise<{ phone_number_id: string; to: string }>;
  send(phoneNumberId: string, to: string, body: string): Promise<string>;
  /** As the signed-in person: records the sent message. */
  record(conversationId: string, body: string, whatsappMessageId: string): Promise<void>;
  allowedOrigins: string[];
}

const MAX_CHARS = 2000;

export function corsHeaders(req: Request, allowed: string[]): Record<string, string> {
  const origin = req.headers.get("Origin") ?? "";
  return {
    "Access-Control-Allow-Origin": allowed.includes(origin) ? origin : allowed[0] ?? "",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
    "Vary": "Origin",
  };
}

export async function handleSend(req: Request, deps: Deps): Promise<Response> {
  const headers = { ...corsHeaders(req, deps.allowedOrigins), "Content-Type": "application/json" };
  const reply = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers });
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers });
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405);

  let input: { conversation_id?: unknown; body?: unknown };
  try {
    input = await req.json();
  } catch {
    return reply({ error: "Invalid request" }, 400);
  }
  const conversationId = typeof input.conversation_id === "string" ? input.conversation_id : "";
  const body = typeof input.body === "string" ? input.body.trim() : "";
  if (!conversationId || !body) return reply({ error: "Write a message first." }, 400);
  if (body.length > MAX_CHARS) return reply({ error: `Messages can be up to ${MAX_CHARS} characters.` }, 400);

  let target: { phone_number_id: string; to: string };
  try {
    target = await deps.prepare(conversationId);
  } catch (err) {
    return reply({ error: err instanceof Error ? err.message : "Not allowed" }, 403);
  }

  let sentId: string;
  try {
    sentId = await deps.send(target.phone_number_id, target.to, body);
  } catch {
    return reply({ error: "WhatsApp didn't accept the message. Please try again." }, 502);
  }
  // Sent: record it even if something odd happens, so the chat shows what went out.
  await deps.record(conversationId, body, sentId);
  return reply({ ok: true, whatsapp_message_id: sentId });
}

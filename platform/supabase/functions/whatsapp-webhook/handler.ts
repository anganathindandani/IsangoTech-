// The webhook Meta calls: a GET once to verify the URL, then a POST for every
// message. Replies are worked out after answering Meta, so a slow AI call
// never makes Meta resend the message.
import { readMessages, validSignature } from "./whatsapp.ts";
import { type EngineDeps, handleMessage } from "./engine.ts";

export interface HandlerDeps extends EngineDeps {
  /** The token typed into Meta's webhook settings. */
  verifyToken: string;
  /** The Meta app's secret, which signs every delivery. */
  appSecret: string;
  /** Keeps work running after the response is sent. */
  waitUntil(work: Promise<unknown>): void;
}

const MAX_BODY_BYTES = 1_000_000;

export async function handleWebhook(req: Request, deps: HandlerDeps): Promise<Response> {
  if (req.method === "GET") {
    const url = new URL(req.url);
    const ok = url.searchParams.get("hub.mode") === "subscribe" && !!deps.verifyToken &&
      url.searchParams.get("hub.verify_token") === deps.verifyToken;
    return ok ? new Response(url.searchParams.get("hub.challenge") ?? "") : new Response("Forbidden", { status: 403 });
  }
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  const raw = await req.text();
  if (raw.length > MAX_BODY_BYTES) return new Response("Too large", { status: 413 });
  if (!(await validSignature(deps.appSecret, raw, req.headers.get("X-Hub-Signature-256")))) {
    return new Response("Invalid signature", { status: 401 });
  }

  let payload: unknown;
  try {
    payload = JSON.parse(raw);
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  const messages = readMessages(payload);
  deps.waitUntil((async () => {
    for (const m of messages) {
      try {
        await handleMessage(m, deps);
      } catch (err) {
        deps.log?.(`failed to handle ${m.id}: ${err instanceof Error ? err.message : err}`);
      }
    }
  })());
  return new Response("ok");
}

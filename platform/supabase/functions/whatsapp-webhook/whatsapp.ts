// Meta's WhatsApp Cloud API: checking webhook signatures, reading incoming
// messages and sending replies.

/** One customer message from a webhook delivery. */
export interface Incoming {
  /** Meta's id for the business's WhatsApp number that received it. */
  phoneNumberId: string;
  /** The customer's number, international format without "+". */
  from: string;
  /** The customer's WhatsApp profile name, if shared. */
  profileName: string;
  /** WhatsApp's message id, used to ignore repeat deliveries. */
  id: string;
  /** The text, or a short note for things the Assistant can't read. */
  body: string;
}

/** Checks X-Hub-Signature-256: an HMAC-SHA256 of the raw body with the app secret. */
export async function validSignature(appSecret: string, rawBody: string, header: string | null): Promise<boolean> {
  if (!appSecret || !header?.startsWith("sha256=")) return false;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(appSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(rawBody)));
  const expected = Array.from(mac, (b) => b.toString(16).padStart(2, "0")).join("");
  const given = header.slice("sha256=".length).toLowerCase();
  if (given.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) diff |= expected.charCodeAt(i) ^ given.charCodeAt(i);
  return diff === 0;
}

// deno-lint-ignore no-explicit-any
type Json = any;

/** The customer messages in a webhook payload. Delivery receipts and other events are skipped. */
export function readMessages(payload: Json): Incoming[] {
  const out: Incoming[] = [];
  for (const entry of payload?.entry ?? []) {
    for (const change of entry?.changes ?? []) {
      const value = change?.value;
      if (change?.field !== "messages" || !value?.metadata?.phone_number_id) continue;
      const names = new Map<string, string>(
        (value.contacts ?? []).map((c: Json) => [String(c?.wa_id ?? ""), String(c?.profile?.name ?? "")]),
      );
      for (const m of value.messages ?? []) {
        if (!m?.id || !m?.from) continue;
        out.push({
          phoneNumberId: String(value.metadata.phone_number_id),
          from: String(m.from),
          profileName: names.get(String(m.from)) ?? "",
          id: String(m.id),
          body: messageText(m),
        });
      }
    }
  }
  return out;
}

function messageText(m: Json): string {
  switch (m.type) {
    case "text":
      return String(m.text?.body ?? "");
    case "button":
      return String(m.button?.text ?? "");
    case "interactive":
      return String(m.interactive?.button_reply?.title ?? m.interactive?.list_reply?.title ?? "");
    default:
      // Voice notes, photos, stickers, locations and so on.
      return `[The customer sent a ${
        String(m.type ?? "message").replace(/[^a-z_]/g, "")
      } message, which you can't open.]`;
  }
}

/** Sends a text reply; returns WhatsApp's id for the sent message. */
export async function sendText(
  config: { accessToken: string; graphVersion: string },
  phoneNumberId: string,
  to: string,
  body: string,
  fetcher: typeof fetch = fetch,
): Promise<string> {
  const res = await fetcher(`https://graph.facebook.com/${config.graphVersion}/${phoneNumberId}/messages`, {
    method: "POST",
    headers: { Authorization: `Bearer ${config.accessToken}`, "Content-Type": "application/json" },
    body: JSON.stringify({ messaging_product: "whatsapp", to, type: "text", text: { body, preview_url: false } }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(`WhatsApp send failed (${res.status}): ${data?.error?.message ?? "unknown error"}`);
  return String(data?.messages?.[0]?.id ?? "");
}

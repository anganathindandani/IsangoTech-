// Shared by the tests: signing deliveries as Meta does, and a sample payload.

export async function sign(secret: string, body: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body)));
  return "sha256=" + Array.from(mac, (b) => b.toString(16).padStart(2, "0")).join("");
}

export const delivery = (messages: unknown[], phoneNumberId = "pn-1") => ({
  object: "whatsapp_business_account",
  entry: [{
    changes: [{
      field: "messages",
      value: {
        metadata: { phone_number_id: phoneNumberId },
        contacts: [{ wa_id: "27825550001", profile: { name: "Nomsa" } }],
        messages,
      },
    }],
  }],
});

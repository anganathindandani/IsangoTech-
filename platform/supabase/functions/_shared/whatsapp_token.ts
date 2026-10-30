// Which Meta access token to send from a WhatsApp number with. A business that
// connected its own number has its own token; one set up by hand uses the
// platform's. Looked up once per number for the life of the function.

export function tokenFor(
  lookup: (phoneNumberId: string) => Promise<string | null>,
  platformToken: string,
): (phoneNumberId: string) => Promise<string> {
  const cache = new Map<string, Promise<string>>();
  return (phoneNumberId) => {
    let token = cache.get(phoneNumberId);
    if (!token) {
      token = lookup(phoneNumberId).then((own) => own || platformToken);
      // A failed lookup isn't remembered, so the next send tries again.
      token.catch(() => cache.delete(phoneNumberId));
      cache.set(phoneNumberId, token);
    }
    return token;
  };
}

/** The lookup, through the database function only the edge functions may call. */
export function databaseLookup(
  rpc: (fn: string, args: Record<string, unknown>) => PromiseLike<{ data: unknown; error: { message: string } | null }>,
): (phoneNumberId: string) => Promise<string | null> {
  return async (phoneNumberId) => {
    const { data, error } = await rpc("whatsapp_access_token", { p_phone_number_id: phoneNumberId });
    if (error) throw new Error(`whatsapp_access_token: ${error.message}`);
    return typeof data === "string" && data ? data : null;
  };
}

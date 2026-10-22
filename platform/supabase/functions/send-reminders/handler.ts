// Sends the booking reminders that are due, and releases held bookings whose
// deposit wasn't paid in time. A scheduled job (pg_cron) calls this every 15
// minutes with a shared secret; the database decides what's due and makes
// sure each happens once.

export interface Reminder {
  booking_id: string;
  phone_number_id: string;
  to: string;
  template: string;
  language: string;
  /** {{1}} first name, {{2}} service, {{3}} business, {{4}} day, {{5}} time. */
  parameters: string[];
}

/** A held booking released because its deposit wasn't paid. */
export interface Release {
  booking_id: string;
  conversation_id: string | null;
  phone_number_id: string | null;
  to: string | null;
  /** Null when WhatsApp's 24-hour window has closed: the release is silent. */
  message: string | null;
}

export interface Deps {
  /** The secret the scheduled job sends in X-Cron-Secret. */
  secret: string;
  claim(): Promise<Reminder[]>;
  send(r: Reminder): Promise<string>;
  record(bookingId: string, whatsappMessageId: string, body: string, costZar: number): Promise<void>;
  release(): Promise<Release[]>;
  /** Sends a plain message inside the 24-hour window; returns WhatsApp's message id. */
  sendText(phoneNumberId: string, to: string, body: string): Promise<string>;
  /** Adds a sent message to the customer's chat. */
  recordMessage(conversationId: string, body: string, whatsappMessageId: string): Promise<void>;
  /** What one template message costs, in rand, for usage records. */
  templateCostZar: number;
  log?: (message: string) => void;
}

/** How the reminder reads in the business's chat history. */
export function reminderText(r: Reminder): string {
  const [name, service, business, day, time] = r.parameters;
  return `Reminder to ${name}: ${service} at ${business} on ${day} at ${time}.`;
}

export function sameSecret(given: string, expected: string): boolean {
  if (!expected || given.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) diff |= given.charCodeAt(i) ^ expected.charCodeAt(i);
  return diff === 0;
}

export async function handleReminders(req: Request, deps: Deps): Promise<Response> {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  if (!sameSecret(req.headers.get("X-Cron-Secret") ?? "", deps.secret)) {
    return new Response("Forbidden", { status: 403 });
  }

  // Released bookings first, so a freed time is never reminded about.
  const released = await deps.release();
  let notified = 0;
  for (const r of released) {
    if (!r.message || !r.phone_number_id || !r.to || !r.conversation_id) continue;
    try {
      const id = await deps.sendText(r.phone_number_id, r.to, r.message);
      await deps.recordMessage(r.conversation_id, r.message, id);
      notified++;
    } catch (err) {
      // The booking is released either way; the business sees it in the app.
      deps.log?.(`release notice for booking ${r.booking_id} failed: ${err instanceof Error ? err.message : err}`);
    }
  }

  const due = await deps.claim();
  let sent = 0;
  let failed = 0;
  for (const r of due) {
    try {
      const id = await deps.send(r);
      await deps.record(r.booking_id, id, reminderText(r), deps.templateCostZar);
      sent++;
    } catch (err) {
      // Left unsent: the database offers it again in 10 minutes, up to three tries.
      failed++;
      deps.log?.(`reminder for booking ${r.booking_id} failed: ${err instanceof Error ? err.message : err}`);
    }
  }
  return new Response(JSON.stringify({ released: released.length, notified, due: due.length, sent, failed }), {
    headers: { "Content-Type": "application/json" },
  });
}

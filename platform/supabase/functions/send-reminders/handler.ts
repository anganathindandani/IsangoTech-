// Sends the booking reminders that are due. A scheduled job (pg_cron) calls
// this every 15 minutes with a shared secret; the database decides which
// reminders are due and makes sure each goes out once.

export interface Reminder {
  booking_id: string;
  phone_number_id: string;
  to: string;
  template: string;
  language: string;
  /** {{1}} first name, {{2}} service, {{3}} business, {{4}} day, {{5}} time. */
  parameters: string[];
}

export interface Deps {
  /** The secret the scheduled job sends in X-Cron-Secret. */
  secret: string;
  claim(): Promise<Reminder[]>;
  send(r: Reminder): Promise<string>;
  record(bookingId: string, whatsappMessageId: string, body: string, costZar: number): Promise<void>;
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
  return new Response(JSON.stringify({ due: due.length, sent, failed }), {
    headers: { "Content-Type": "application/json" },
  });
}

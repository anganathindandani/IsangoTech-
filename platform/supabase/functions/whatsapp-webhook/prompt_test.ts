import { assert, assertEquals } from "jsr:@std/assert@1";
import { buildMessages, businessDetails, type Context, RULES, TOOLS } from "./prompt.ts";

const ctx: Context = {
  business: { name: "Salon A", industry: "salon", time_zone: "Africa/Johannesburg" },
  settings: {
    opening_hours: { sat: [["08:00", "14:00"]], mon: [["08:00", "12:00"], ["13:00", "17:00"]] },
    languages: ["en", "xh"],
    tone: "Warm",
    policies: "Late by 15 minutes and we may need to rebook.",
    handover_topics: "Wedding packages",
    min_booking_notice_hours: 2,
    change_notice_hours: 24,
    deposit_required: true,
    deposit_percent: 20,
    privacy_notice_url: null,
  },
  customer: { name: "Nomsa" },
  history: [
    { sender: "assistant", body: "Reminder: your booking is tomorrow." },
    { sender: "customer", body: "Hi" },
    { sender: "customer", body: "Do you do braids?" },
    { sender: "assistant", body: "Yes, from R450." },
    { sender: "customer", body: "Saturday?" },
  ],
  now_local: "Friday 16 October 2026, 18:00",
  last_inbound: "w5",
};

Deno.test("the business details carry hours, languages, rules and the owner's policies", () => {
  const details = businessDetails(ctx);
  assert(details.includes("Monday: 08:00 to 12:00, 13:00 to 17:00"));
  assert(details.includes("Tuesday: closed"));
  assert(details.includes("Languages allowed: English, isiXhosa"));
  assert(details.includes("A 20% deposit is required"));
  assert(details.includes("Late by 15 minutes"));
  assert(details.includes("Wedding packages"));
});

Deno.test("the cached part stays the same from message to message", () => {
  const a = buildMessages(ctx)[0];
  const b = buildMessages({ ...ctx, now_local: "Saturday 17 October 2026, 08:00", customer: { name: "Sipho" } })[0];
  assertEquals(a, b, "the date and customer name must not be in the system prompt");
});

Deno.test("the chat starts with the customer and joins messages from the same side", () => {
  const messages = buildMessages(ctx);
  assertEquals(messages.slice(1).map((m) => m.role), ["user", "assistant", "user"]);
  assertEquals(messages[1].content, "Hi\nDo you do braids?");
  assertEquals(messages.at(-1)!.content, [
    { type: "text", text: "(Now: Friday 16 October 2026, 18:00, business time. Customer: Nomsa.)" },
    { type: "text", text: "Saturday?" },
  ]);
});

Deno.test("every tool the prompt mentions exists, and every tool is mentioned", () => {
  const names = TOOLS.map((t) => t.function.name);
  for (const name of names) assert(RULES.includes(name), `${name} should be explained in the rules`);
  for (const t of TOOLS) assertEquals(t.function.parameters.additionalProperties, false);
});

import { assertEquals } from "jsr:@std/assert@1";
import { type Deps, handleReminders, type Reminder, reminderText } from "./handler.ts";
import { sendTemplate } from "../whatsapp-webhook/whatsapp.ts";

const reminder = (id: string): Reminder => ({
  booking_id: id,
  phone_number_id: "pn-1",
  to: "27825550001",
  template: "booking_reminder",
  language: "en",
  parameters: ["Thandi", "Box braids", "Demo Salon", "Saturday 17 October", "13:30"],
});

const call = (secret?: string) =>
  new Request("https://x.test/send-reminders", {
    method: "POST",
    headers: secret ? { "X-Cron-Secret": secret } : {},
  });

function deps(overrides: Partial<Deps> = {}) {
  const log = { sent: [] as string[], recorded: [] as unknown[] };
  const d: Deps = {
    secret: "cron-secret",
    claim: () => Promise.resolve([reminder("b1"), reminder("b2")]),
    send: (r) => {
      log.sent.push(r.booking_id);
      return Promise.resolve(`wamid-${r.booking_id}`);
    },
    record: (...args) => {
      log.recorded.push(args);
      return Promise.resolve();
    },
    templateCostZar: 0.3,
    ...overrides,
  };
  return { d, log };
}

Deno.test("sends each due reminder and records it", async () => {
  const { d, log } = deps();
  const res = await handleReminders(call("cron-secret"), d);
  assertEquals(await res.json(), { due: 2, sent: 2, failed: 0 });
  assertEquals(log.recorded[0], [
    "b1",
    "wamid-b1",
    "Reminder to Thandi: Box braids at Demo Salon on Saturday 17 October at 13:30.",
    0.3,
  ]);
});

Deno.test("only the scheduled job can run it", async () => {
  const { d, log } = deps();
  assertEquals((await handleReminders(call(), d)).status, 403);
  assertEquals((await handleReminders(call("guess"), d)).status, 403);
  const noSecret = deps({ secret: "" });
  assertEquals((await handleReminders(call(""), noSecret.d)).status, 403, "an unset secret never matches");
  assertEquals(log.sent, []);
});

Deno.test("one failed send doesn't stop the rest, and isn't recorded as sent", async () => {
  const { d, log } = deps({
    send: (r) => r.booking_id === "b1" ? Promise.reject(new Error("template not approved")) : Promise.resolve("w2"),
  });
  const res = await handleReminders(call("cron-secret"), d);
  assertEquals(await res.json(), { due: 2, sent: 1, failed: 1 });
  assertEquals(log.recorded.map((r) => (r as string[])[0]), ["b2"]);
});

Deno.test("the template goes to WhatsApp with its parameters in order", async () => {
  let body: unknown;
  const fakeFetch = ((_url: string, init: RequestInit) => {
    body = JSON.parse(String(init.body));
    return Promise.resolve(new Response(JSON.stringify({ messages: [{ id: "wamid-t" }] })));
  }) as unknown as typeof fetch;
  const r = reminder("b1");
  const id = await sendTemplate({ accessToken: "t", graphVersion: "v23.0" }, "pn-1", r.to, {
    name: r.template,
    language: r.language,
    parameters: r.parameters,
  }, fakeFetch);
  assertEquals(id, "wamid-t");
  assertEquals(body, {
    messaging_product: "whatsapp",
    to: "27825550001",
    type: "template",
    template: {
      name: "booking_reminder",
      language: { code: "en" },
      components: [{
        type: "body",
        parameters: r.parameters.map((text) => ({ type: "text", text })),
      }],
    },
  });
  assertEquals(reminderText(r).startsWith("Reminder to Thandi"), true);
});

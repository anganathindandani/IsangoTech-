import { assertEquals } from "jsr:@std/assert@1";
import { type Deps, handleSend } from "./handler.ts";

const post = (body: unknown) =>
  new Request("https://x.test/send-message", {
    method: "POST",
    headers: { Origin: "https://app.isangotech.co.za", "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

function deps(overrides: Partial<Deps> = {}) {
  const log = { sent: [] as string[], recorded: [] as string[] };
  const d: Deps = {
    prepare: () => Promise.resolve({ phone_number_id: "pn-1", to: "27825550001" }),
    send: (_f, _t, body) => {
      log.sent.push(body);
      return Promise.resolve("wamid-1");
    },
    record: (_c, body) => {
      log.recorded.push(body);
      return Promise.resolve();
    },
    allowedOrigins: ["https://app.isangotech.co.za"],
    ...overrides,
  };
  return { d, log };
}

Deno.test("sends the reply and records it", async () => {
  const { d, log } = deps();
  const res = await handleSend(post({ conversation_id: "c1", body: "  Hi Thandi  " }), d);
  assertEquals(res.status, 200);
  assertEquals(log.sent, ["Hi Thandi"]);
  assertEquals(log.recorded, ["Hi Thandi"]);
  assertEquals(res.headers.get("Access-Control-Allow-Origin"), "https://app.isangotech.co.za");
});

Deno.test("nothing is sent when the database says no", async () => {
  const { d, log } = deps({ prepare: () => Promise.reject(new Error("WhatsApp only allows replies within 24 hours")) });
  const res = await handleSend(post({ conversation_id: "c1", body: "Hi" }), d);
  assertEquals(res.status, 403);
  assertEquals((await res.json()).error, "WhatsApp only allows replies within 24 hours");
  assertEquals(log.sent, []);
});

Deno.test("empty or overlong messages are refused", async () => {
  const { d, log } = deps();
  assertEquals((await handleSend(post({ conversation_id: "c1", body: "   " }), d)).status, 400);
  assertEquals((await handleSend(post({ conversation_id: "c1", body: "x".repeat(2001) }), d)).status, 400);
  assertEquals(log.sent, []);
});

Deno.test("a failed WhatsApp send isn't recorded as sent", async () => {
  const { d, log } = deps({ send: () => Promise.reject(new Error("401")) });
  const res = await handleSend(post({ conversation_id: "c1", body: "Hi" }), d);
  assertEquals(res.status, 502);
  assertEquals(log.recorded, []);
});

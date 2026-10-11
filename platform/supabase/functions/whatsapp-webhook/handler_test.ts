import { assertEquals } from "jsr:@std/assert@1";
import { type HandlerDeps, handleWebhook } from "./handler.ts";
import { delivery, sign } from "./test_helpers.ts";

function deps(received: string[]): HandlerDeps & { pending: Promise<unknown>[] } {
  const pending: Promise<unknown>[] = [];
  return {
    pending,
    verifyToken: "verify-me",
    appSecret: "app-secret",
    db: {
      receive: (m) => {
        received.push(m.body);
        return Promise.resolve({ status: "duplicate" });
      },
      context: () => Promise.reject(new Error("unused")),
      tool: () => Promise.reject(new Error("unused")),
      recordReply: () => Promise.resolve(),
      recordAiCall: () => Promise.resolve(),
    },
    ai: { model: "m", chat: () => Promise.reject(new Error("unused")) },
    send: () => Promise.resolve(""),
    usdToZar: 18,
    waitUntil: (work) => pending.push(work),
  };
}

Deno.test("verifies the webhook URL only with the right token", async () => {
  const d = deps([]);
  const url = "https://x.test/whatsapp-webhook?hub.mode=subscribe&hub.challenge=12345&hub.verify_token=";
  const ok = await handleWebhook(new Request(url + "verify-me"), d);
  assertEquals([ok.status, await ok.text()], [200, "12345"]);
  assertEquals((await handleWebhook(new Request(url + "wrong"), d)).status, 403);
});

Deno.test("refuses unsigned or wrongly signed deliveries without saving anything", async () => {
  const received: string[] = [];
  const d = deps(received);
  const body = JSON.stringify(delivery([{ id: "w1", from: "27825550001", type: "text", text: { body: "Hi" } }]));
  const post = (signature?: string) =>
    new Request("https://x.test/whatsapp-webhook", {
      method: "POST",
      body,
      headers: signature ? { "X-Hub-Signature-256": signature } : {},
    });
  assertEquals((await handleWebhook(post(), d)).status, 401);
  assertEquals((await handleWebhook(post(await sign("someone-else", body)), d)).status, 401);
  assertEquals(received, []);

  const res = await handleWebhook(post(await sign("app-secret", body)), d);
  assertEquals(res.status, 200, "Meta gets its answer straight away");
  await Promise.all(d.pending);
  assertEquals(received, ["Hi"], "and the message is handled after");
});

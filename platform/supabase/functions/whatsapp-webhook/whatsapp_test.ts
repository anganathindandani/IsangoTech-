import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { readMessages, sendText, validSignature } from "./whatsapp.ts";
import { delivery, sign } from "./test_helpers.ts";

Deno.test("accepts only deliveries signed with the app secret", async () => {
  const body = '{"entry":[]}';
  assertEquals(await validSignature("secret", body, await sign("secret", body)), true);
  assertEquals(await validSignature("secret", body, await sign("other", body)), false);
  assertEquals(await validSignature("secret", body + " ", await sign("secret", body)), false);
  assertEquals(await validSignature("secret", body, null), false);
  assertEquals(await validSignature("", body, "sha256=" + "0".repeat(64)), false);
});

Deno.test("reads text, button replies and things it can't open", () => {
  const got = readMessages(delivery([
    { id: "w1", from: "27825550001", type: "text", text: { body: "Hi" } },
    { id: "w2", from: "27825550001", type: "interactive", interactive: { button_reply: { title: "Yes" } } },
    { id: "w3", from: "27825550001", type: "audio", audio: {} },
  ]));
  assertEquals(got.map((m) => m.body), [
    "Hi",
    "Yes",
    "[The customer sent a audio message, which you can't open.]",
  ]);
  assertEquals(got[0], { phoneNumberId: "pn-1", from: "27825550001", profileName: "Nomsa", id: "w1", body: "Hi" });
});

Deno.test("skips delivery receipts and malformed entries", () => {
  assertEquals(readMessages({ entry: [{ changes: [{ field: "messages", value: { statuses: [{}] } }] }] }), []);
  assertEquals(readMessages(null), []);
  assertEquals(readMessages({ entry: [{ changes: [{ field: "messages", value: { metadata: {} } }] }] }), []);
});

Deno.test("sends a text reply and returns its id", async () => {
  let sent: { url: string; body: unknown } | undefined;
  const fakeFetch = ((url: string, init: RequestInit) => {
    sent = { url, body: JSON.parse(String(init.body)) };
    return Promise.resolve(new Response(JSON.stringify({ messages: [{ id: "wamid-out" }] })));
  }) as unknown as typeof fetch;
  const id = await sendText({ accessToken: "t", graphVersion: "v23.0" }, "pn-1", "2782", "Hello", fakeFetch);
  assertEquals(id, "wamid-out");
  assertEquals(sent?.url, "https://graph.facebook.com/v23.0/pn-1/messages");
  assertEquals(sent?.body, {
    messaging_product: "whatsapp",
    to: "2782",
    type: "text",
    text: { body: "Hello", preview_url: false },
  });
});

Deno.test("a failed send is an error, not a silent drop", async () => {
  const fakeFetch = (() =>
    Promise.resolve(
      new Response(JSON.stringify({ error: { message: "bad token" } }), { status: 401 }),
    )) as unknown as typeof fetch;
  await assertRejects(() => sendText({ accessToken: "t", graphVersion: "v23.0" }, "pn", "1", "x", fakeFetch));
});

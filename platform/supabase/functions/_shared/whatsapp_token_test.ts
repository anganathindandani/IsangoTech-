import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { databaseLookup, tokenFor } from "./whatsapp_token.ts";

Deno.test("a connected business's own token, else the platform's", async () => {
  const lookups: string[] = [];
  const token = tokenFor((pn) => {
    lookups.push(pn);
    return Promise.resolve(pn === "pn-own" ? "own-token" : null);
  }, "platform-token");
  assertEquals(await token("pn-own"), "own-token");
  assertEquals(await token("pn-hand"), "platform-token");
  assertEquals(await token("pn-own"), "own-token");
  assertEquals(lookups, ["pn-own", "pn-hand"], "each number is looked up once");
});

Deno.test("a failed lookup is an error, and is tried again next time", async () => {
  let calls = 0;
  const token = tokenFor(() => {
    calls++;
    return calls === 1 ? Promise.reject(new Error("database down")) : Promise.resolve("own-token");
  }, "platform-token");
  await assertRejects(() => token("pn-own"), Error, "database down");
  assertEquals(await token("pn-own"), "own-token");
});

Deno.test("the database lookup asks for the number's token", async () => {
  let asked: unknown;
  const lookup = databaseLookup((fn, args) => {
    asked = [fn, args];
    return Promise.resolve({ data: null, error: null });
  });
  assertEquals(await lookup("pn-1"), null);
  assertEquals(asked, ["whatsapp_access_token", { p_phone_number_id: "pn-1" }]);
  const failing = databaseLookup(() => Promise.resolve({ data: null, error: { message: "permission denied" } }));
  await assertRejects(() => failing("pn-1"), Error, "permission denied");
});

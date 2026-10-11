import { assertEquals } from "jsr:@std/assert@1";
import { type Deps, handleOnboard, readBusiness } from "./handler.ts";

const post = (body: unknown) =>
  new Request("https://x.test/onboard-business", {
    method: "POST",
    headers: { Origin: "https://app.isangotech.co.za", "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

const valid = {
  business: { name: "Lindi's Kitchen", industry: "caterer", products: ["assistant"], whatsapp_phone_number_id: "pn-9" },
  owner: { full_name: "Lindiwe Dube", email: "Lindi@Example.co.za " },
};

function deps(overrides: Partial<Deps> = {}) {
  const log = { created: [] as string[], businesses: [] as unknown[] };
  const d: Deps = {
    isAdmin: () => Promise.resolve(true),
    findUser: () => Promise.resolve(null),
    createUser: (email) => {
      log.created.push(email);
      return Promise.resolve("user-1");
    },
    createBusiness: (b, user, name) => {
      log.businesses.push({ b, user, name });
      return Promise.resolve("biz-1");
    },
    setupLink: (email) => Promise.resolve(`https://auth.test/verify?email=${email}`),
    allowedOrigins: ["https://app.isangotech.co.za"],
    ...overrides,
  };
  return { d, log };
}

Deno.test("creates the login, the business and a setup link", async () => {
  const { d, log } = deps();
  const res = await handleOnboard(post(valid), d);
  assertEquals(res.status, 201);
  assertEquals(await res.json(), {
    business_id: "biz-1",
    new_login: true,
    setup_link: "https://auth.test/verify?email=lindi@example.co.za",
  });
  assertEquals(log.created, ["lindi@example.co.za"]);
  assertEquals(log.businesses, [{
    b: {
      name: "Lindi's Kitchen",
      industry: "caterer",
      products: ["assistant"],
      whatsapp_phone_number_id: "pn-9",
      whatsapp_display_number: undefined,
      monthly_conversation_allowance: 300,
    },
    user: "user-1",
    name: "Lindiwe Dube",
  }]);
});

Deno.test("an owner who already has a login keeps it", async () => {
  const { d, log } = deps({ findUser: () => Promise.resolve("existing-user") });
  const res = await handleOnboard(post(valid), d);
  assertEquals((await res.json()).new_login, false);
  assertEquals(log.created, []);
  assertEquals((log.businesses[0] as { user: string }).user, "existing-user");
});

Deno.test("only IsangoTech admins can onboard", async () => {
  const { d, log } = deps({ isAdmin: () => Promise.resolve(false) });
  assertEquals((await handleOnboard(post(valid), d)).status, 403);
  const failing = deps({ isAdmin: () => Promise.reject(new Error("JWT expired")) });
  assertEquals((await handleOnboard(post(valid), failing.d)).status, 403);
  assertEquals(log.created, []);
});

Deno.test("the form is checked before anything is created", () => {
  assertEquals(readBusiness({ name: " ", industry: "salon", products: ["assistant"] }), "Give the business a name.");
  assertEquals(readBusiness({ name: "X", industry: "bank", products: ["assistant"] }), "Choose the kind of business.");
  assertEquals(readBusiness({ name: "X", industry: "salon", products: ["crm"] }), "Choose at least one product.");
  assertEquals(
    readBusiness({ name: "X", industry: "salon", products: ["portal"], monthly_conversation_allowance: -1 }),
    "The conversation allowance must be a whole number.",
  );
});

Deno.test("a bad email or missing owner name is refused", async () => {
  const { d, log } = deps();
  assertEquals((await handleOnboard(post({ ...valid, owner: { full_name: "L", email: "nope" } }), d)).status, 400);
  assertEquals((await handleOnboard(post({ ...valid, owner: { email: "a@b.co" } }), d)).status, 400);
  assertEquals(log.created, []);
});

Deno.test("a WhatsApp number already in use is explained", async () => {
  const { d } = deps({
    createBusiness: () =>
      Promise.reject(new Error('duplicate key value violates "businesses_whatsapp_phone_number_id_key"')),
  });
  const res = await handleOnboard(post(valid), d);
  assertEquals(res.status, 409);
  assertEquals((await res.json()).error, "Another business already uses that WhatsApp number.");
});

Deno.test("a fresh setup link for an existing login", async () => {
  const { d } = deps({ findUser: () => Promise.resolve("u") });
  const res = await handleOnboard(post({ action: "link", email: "lindi@example.co.za" }), d);
  assertEquals(res.status, 200);
  assertEquals((await res.json()).setup_link, "https://auth.test/verify?email=lindi@example.co.za");
  const none = deps();
  assertEquals((await handleOnboard(post({ action: "link", email: "x@y.co" }), none.d)).status, 404);
});

import { assertEquals } from "jsr:@std/assert@1";
import { type Deps, handleTeam } from "./handler.ts";

const post = (body: unknown) =>
  new Request("https://x.test/team-member", {
    method: "POST",
    headers: { Origin: "https://app.isangotech.co.za", "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

const add = { business_id: "biz-1", full_name: "Sam Ndlovu", email: "Sam@Example.co.za", role: "staff" };

function deps(overrides: Partial<Deps> = {}) {
  const log = { created: [] as string[], added: [] as unknown[], links: [] as string[] };
  const d: Deps = {
    isOwner: (id) => Promise.resolve(id === "biz-1"),
    findUser: () => Promise.resolve(null),
    createUser: (email) => {
      log.created.push(email);
      return Promise.resolve("user-new");
    },
    addMember: (...args) => {
      log.added.push(args);
      return Promise.resolve();
    },
    linkTarget: () => Promise.resolve("user-new"),
    setupLink: (email) => {
      log.links.push(email);
      return Promise.resolve(`https://auth.test/verify?email=${email}`);
    },
    allowedOrigins: ["https://app.isangotech.co.za"],
    ...overrides,
  };
  return { d, log };
}

Deno.test("an owner adds a staff member with a new login and gets a setup link", async () => {
  const { d, log } = deps();
  const res = await handleTeam(post({ ...add, staff_id: "staff-7" }), d);
  assertEquals(res.status, 201);
  assertEquals(await res.json(), { new_login: true, setup_link: "https://auth.test/verify?email=sam@example.co.za" });
  assertEquals(log.added, [["biz-1", "user-new", "Sam Ndlovu", "staff", "staff-7"]]);
});

Deno.test("managers aren't linked to a staff record", async () => {
  const { d, log } = deps();
  await handleTeam(post({ ...add, role: "manager", staff_id: "staff-7" }), d);
  assertEquals((log.added[0] as unknown[])[4], null);
});

Deno.test("someone with a login elsewhere gets access here, but no link to their account", async () => {
  const { d, log } = deps({ findUser: () => Promise.resolve("their-own"), linkTarget: () => Promise.resolve(null) });
  const res = await handleTeam(post(add), d);
  assertEquals(await res.json(), { new_login: false, setup_link: null });
  assertEquals(log.created, []);
  assertEquals(log.links, [], "no link made at all");
});

Deno.test("only the owner of this business can add people", async () => {
  const { d, log } = deps();
  assertEquals((await handleTeam(post({ ...add, business_id: "someone-elses" }), d)).status, 403);
  const failing = deps({ isOwner: () => Promise.reject(new Error("JWT expired")) });
  assertEquals((await handleTeam(post(add), failing.d)).status, 403);
  assertEquals(log.created, []);
});

Deno.test("owners can't make owners, and the form is checked", async () => {
  const { d, log } = deps();
  assertEquals((await handleTeam(post({ ...add, role: "owner" }), d)).status, 400);
  assertEquals((await handleTeam(post({ ...add, full_name: " " }), d)).status, 400);
  assertEquals((await handleTeam(post({ ...add, email: "nope" }), d)).status, 400);
  assertEquals(log.created, []);
});

Deno.test("a new setup link only where it's allowed", async () => {
  const ok = deps();
  const res = await handleTeam(post({ action: "link", business_id: "biz-1", email: "sam@example.co.za" }), ok.d);
  assertEquals(res.status, 200);
  const refused = deps({ linkTarget: () => Promise.resolve(null) });
  const no = await handleTeam(post({ action: "link", business_id: "biz-1", email: "owner@other.co.za" }), refused.d);
  assertEquals(no.status, 403);
  assertEquals(refused.log.links, []);
});

import { assertEquals } from "jsr:@std/assert@1";
import { type Deps, handleSubmit } from "./handler.ts";

function post(body: unknown, headers: Record<string, string> = {}): Request {
  return new Request("https://example.test/submit-enquiry", {
    method: "POST",
    headers: { "Content-Type": "application/json", Origin: "https://isangotech.co.za", ...headers },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

function fakeDeps(overrides: Partial<Deps> = {}) {
  const calls: Record<string, unknown>[] = [];
  const deps: Deps = {
    submit: (fields) => {
      calls.push(fields);
      return Promise.resolve({ data: { assessment_starts_at: null }, error: null });
    },
    verifyCaptcha: (token) => Promise.resolve(token === "good-token"),
    ...overrides,
  };
  return { deps, calls };
}

const valid = { full_name: "Thandi", phone: "0821234567", consent: true, turnstile_token: "good-token" };

Deno.test("passes only known fields to the database", async () => {
  const { deps, calls } = fakeDeps();
  const res = await handleSubmit(post({ ...valid, source: "admin", pipeline_stage: "won" }), deps);
  assertEquals(res.status, 201);
  assertEquals(calls, [{ full_name: "Thandi", phone: "0821234567", consent: true }]);
});

Deno.test("rejects a missing or failed spam check", async () => {
  const { deps, calls } = fakeDeps();
  assertEquals((await handleSubmit(post({ ...valid, turnstile_token: "" }), deps)).status, 400);
  assertEquals((await handleSubmit(post({ ...valid, turnstile_token: "bad" }), deps)).status, 400);
  assertEquals(calls.length, 0);
});

Deno.test("honeypot looks like success but saves nothing", async () => {
  const { deps, calls } = fakeDeps();
  const res = await handleSubmit(post({ ...valid, website: "http://spam.example" }), deps);
  assertEquals(res.status, 201);
  assertEquals(calls.length, 0);
});

Deno.test("maps database errors to friendly responses", async () => {
  const cases: [string, number][] = [["PT400", 400], ["PT409", 409], ["XX000", 500]];
  for (const [code, status] of cases) {
    const { deps } = fakeDeps({
      submit: () => Promise.resolve({ data: null, error: { code, message: "Database said no" } }),
    });
    const res = await handleSubmit(post(valid), deps);
    assertEquals(res.status, status);
    const body = await res.json();
    if (status === 500) assertEquals(body.error.includes("Database said no"), false);
    else assertEquals(body.error, "Database said no");
  }
});

Deno.test("rejects bad requests", async () => {
  const { deps } = fakeDeps();
  assertEquals((await handleSubmit(post("not json"), deps)).status, 400);
  assertEquals((await handleSubmit(post([1, 2]), deps)).status, 400);
  assertEquals((await handleSubmit(post({ ...valid, biggest_pain: "x".repeat(20_000) }), deps)).status, 413);
  const get = new Request("https://example.test/submit-enquiry", { method: "GET" });
  assertEquals((await handleSubmit(get, deps)).status, 405);
});

Deno.test("CORS allows only the IsangoTech site", async () => {
  const { deps } = fakeDeps();
  const ok = await handleSubmit(post(valid), deps);
  assertEquals(ok.headers.get("Access-Control-Allow-Origin"), "https://isangotech.co.za");
  const other = await handleSubmit(post(valid, { Origin: "https://evil.example" }), deps);
  assertEquals(other.headers.get("Access-Control-Allow-Origin"), "https://isangotech.co.za");
});

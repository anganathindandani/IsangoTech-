import { assert, assertEquals } from "jsr:@std/assert@1";
import type { Ai, ChatMessage, ChatResult } from "./ai.ts";
import { type Db, type EngineDeps, handleMessage } from "./engine.ts";
import type { Context } from "./prompt.ts";
import type { Incoming } from "./whatsapp.ts";

const message: Incoming = { phoneNumberId: "pn-1", from: "27825550001", profileName: "Nomsa", id: "w1", body: "Hi" };

function context(overrides: Partial<Context> = {}): Context {
  return {
    business: { name: "Salon A", industry: "salon", time_zone: "Africa/Johannesburg" },
    settings: {
      opening_hours: { sat: [["08:00", "14:00"]] },
      languages: ["en", "xh"],
      tone: "Warm",
      policies: "",
      handover_topics: "",
      min_booking_notice_hours: 2,
      change_notice_hours: 24,
      deposit_required: false,
      deposit_percent: 0,
      privacy_notice_url: null,
    },
    customer: { name: "Nomsa" },
    history: [{ sender: "customer", body: "Hi" }],
    now_local: "Saturday 17 October 2026, 09:00",
    last_inbound: "w1",
    ...overrides,
  };
}

const usage = { inputTokens: 5000, cachedInputTokens: 4000, outputTokens: 100, costUsd: 0.001 };

function harness(opts: {
  replies: (ChatResult | Error)[];
  ctx?: Context;
  status?: "reply" | "person" | "duplicate";
  newCustomer?: boolean;
}) {
  const log = {
    tools: [] as [string, unknown][],
    sent: [] as string[],
    recorded: [] as string[],
    costs: [] as number[],
  };
  const seen: ChatMessage[][] = [];
  const db: Db = {
    receive: () =>
      Promise.resolve({ status: opts.status ?? "reply", conversation_id: "c1", new_customer: opts.newCustomer }),
    context: () => Promise.resolve(opts.ctx ?? context()),
    tool: (_c, name, args) => {
      log.tools.push([name, args]);
      return Promise.resolve({ ok: true, name });
    },
    recordReply: (_c, body) => {
      log.recorded.push(body);
      return Promise.resolve();
    },
    recordAiCall: (_c, call) => {
      log.costs.push(call.costZar);
      return Promise.resolve();
    },
  };
  const replies = [...opts.replies];
  const ai: Ai = {
    model: "test-model",
    chat: (messages) => {
      seen.push(structuredClone(messages));
      const next = replies.shift() ?? new Error("no more replies");
      return next instanceof Error ? Promise.reject(next) : Promise.resolve(next);
    },
  };
  const deps: EngineDeps = {
    db,
    ai,
    send: (_p, _to, body) => {
      log.sent.push(body);
      return Promise.resolve("wamid-out");
    },
    usdToZar: 18,
  };
  return { deps, log, seen };
}

const text = (t: string): ChatResult => ({ text: t, toolCalls: [], usage });
const calls = (...c: [string, unknown][]): ChatResult => ({
  text: null,
  toolCalls: c.map(([name, args], i) => ({
    id: `call-${i}`,
    type: "function",
    function: { name, arguments: JSON.stringify(args) },
  })),
  usage,
});

Deno.test("runs tools until the model answers, then sends and records the reply", async () => {
  const { deps, log, seen } = harness({
    replies: [
      calls(["find_services", {}]),
      calls(["check_availability", { service_id: "s1", date: "2026-10-17" }]),
      text(
        "We have 09:00 or 11:00 on Saturday.",
      ),
    ],
  });
  await handleMessage(message, deps);
  assertEquals(log.tools.map(([n]) => n), ["find_services", "check_availability"]);
  assertEquals(log.sent, ["We have 09:00 or 11:00 on Saturday."]);
  assertEquals(log.recorded, log.sent);
  assertEquals(log.costs, [0.018, 0.018, 0.018], "every AI call's cost is recorded in rand");
  // The tool results go back to the model with the call they answer.
  const last = seen.at(-1)!;
  assertEquals(last.at(-1), {
    role: "tool",
    tool_call_id: "call-0",
    content: JSON.stringify({ ok: true, name: "check_availability" }),
  });
});

Deno.test("stays quiet when a person has taken over or the message is a repeat", async () => {
  for (const status of ["person", "duplicate"] as const) {
    const { deps, log, seen } = harness({ replies: [text("Hi")], status });
    await handleMessage(message, deps);
    assertEquals(log.sent, []);
    assertEquals(seen.length, 0, "the model isn't even called");
  }
});

Deno.test("if the AI fails, the chat goes to a person and the customer is told", async () => {
  const { deps, log } = harness({ replies: [new Error("AI request failed (500)")] });
  await handleMessage(message, deps);
  assertEquals(log.tools, [["hand_over", { reason: "assistant error" }]]);
  assertEquals(log.sent, ["Thanks for your message. Someone from Salon A will reply to you shortly."]);
});

Deno.test("a model that keeps calling tools is stopped and handed over", async () => {
  const { deps, log } = harness({ replies: Array(10).fill(calls(["find_services", {}])) });
  await handleMessage(message, deps);
  assertEquals(log.tools.filter(([n]) => n === "find_services").length, 6);
  assertEquals(log.tools.at(-1), ["hand_over", { reason: "no answer" }]);
  assertEquals(log.sent.length, 1);
});

Deno.test("bad tool arguments are reported back to the model, not crashed on", async () => {
  const { deps, log, seen } = harness({
    replies: [
      {
        text: null,
        toolCalls: [{ id: "x", type: "function", function: { name: "find_services", arguments: "{oops" } }],
        usage,
      },
      text("Sorry, let me check that again."),
    ],
  });
  await handleMessage(message, deps);
  assertEquals(log.tools, []);
  assertEquals(seen[1].at(-1), {
    role: "tool",
    tool_call_id: "x",
    content: JSON.stringify({ ok: false, error: "Arguments were not valid JSON" }),
  });
  assertEquals(log.sent.length, 1);
});

Deno.test("if the customer wrote again meanwhile, only the newer run replies", async () => {
  const { deps, log } = harness({ replies: [text("Hello!")], ctx: context({ last_inbound: "w2" }) });
  await handleMessage(message, deps);
  assertEquals(log.sent, []);
});

Deno.test("a new customer's first reply links to the business's privacy notice", async () => {
  const ctx = context();
  ctx.settings.privacy_notice_url = "https://salon-a.example/privacy";
  const { deps, log } = harness({ replies: [text("Hello!")], ctx, newCustomer: true });
  await handleMessage(message, deps);
  assert(log.sent[0].startsWith("Hello!"));
  assert(log.sent[0].endsWith("https://salon-a.example/privacy"));
});

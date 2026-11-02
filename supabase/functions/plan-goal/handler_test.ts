import assert from "node:assert/strict";
import { geminiReply } from "../_shared/test_data.ts";
import { type Deps, planGoal } from "./handler.ts";
import { planJson, samplePlan } from "./test_data.ts";

interface Fake {
  deps: Deps;
  taken: string[];
  refunded: string[];
  geminiCalls: number;
  logs: Record<string, unknown>[];
}

function fake(
  options: { left?: number; gemini?: () => Promise<Response> } = {},
): Fake {
  const state: Fake = {
    taken: [],
    refunded: [],
    geminiCalls: 0,
    logs: [],
    deps: undefined as unknown as Deps,
  };
  state.deps = {
    configured: true,
    model: "gemini-3.5-flash-lite",
    userLimit: 10,
    takeCall: (userId) => {
      state.taken.push(userId);
      return Promise.resolve(options.left ?? 9);
    },
    refundCall: (userId) => {
      state.refunded.push(userId);
      return Promise.resolve();
    },
    callGemini: () => {
      state.geminiCalls++;
      return options.gemini?.() ??
        Promise.resolve(Response.json(geminiReply(samplePlan())));
    },
    log: (event) => state.logs.push(event),
  };
  return state;
}

function post(body: unknown = planJson()): Request {
  return new Request("http://localhost/plan-goal", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

async function call(f: Fake, req: Request = post()) {
  const response = await planGoal(req, "user-1", f.deps);
  return { status: response.status, body: await response.json() };
}

Deno.test("answers with the cleaned plan and the plans left", async () => {
  const f = fake({ left: 6 });
  const { status, body } = await call(f);

  assert.equal(status, 200);
  assert.equal(body.callsLeftToday, 6);
  assert.equal(body.model, "gemini-3.5-flash-lite");
  assert.deepEqual(body.plan.cuts.map((c: { groups: string[] }) => c.groups), [
    ["s1"],
    ["s3"],
  ]);
  assert.deepEqual(f.taken, ["user-1"]);
  assert.deepEqual(f.refunded, []);

  // The logs say how it went, never what the goal or the month was.
  const logged = JSON.stringify(f.logs);
  assert.ok(logged.includes('"answered"'));
  for (const secret of ["Delhi", "Swiggy", "Asha", "3480", "15000", "Cook"]) {
    assert.ok(!logged.includes(secret), secret);
  }
});

Deno.test("bad or oversized requests cost nothing", async () => {
  const f = fake();
  const noSpends = planJson();
  noSpends.month.spends = [];
  noSpends.tags = {};
  const noGoal = { ...planJson(), goal: undefined };

  assert.equal((await call(f, post(noSpends))).status, 400);
  assert.equal((await call(f, post(noGoal))).status, 400);
  assert.equal((await call(f, post("x".repeat(48 * 1024)))).status, 413);
  assert.equal(
    (await call(f, new Request("http://localhost/plan-goal"))).status,
    405,
  );
  assert.equal(f.taken.length, 0);
  assert.equal(f.geminiCalls, 0);
});

Deno.test("the daily limit stops the call before Gemini", async () => {
  const f = fake({ left: -1 });
  const { status, body } = await call(f);
  assert.equal(status, 429);
  assert.deepEqual(body, { error: "daily_limit", limit: 10 });
  assert.equal(f.geminiCalls, 0);
});

Deno.test("an unusable answer is refused and given back", async () => {
  const f = fake({
    gemini: () =>
      Promise.resolve(Response.json(geminiReply({ nonsense: true }))),
  });
  const { status, body } = await call(f);
  assert.equal(status, 502);
  assert.equal(body.error, "bad_answer");
  assert.deepEqual(f.refunded, ["user-1"]);
});

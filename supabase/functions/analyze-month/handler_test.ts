import assert from "node:assert/strict";
import { analyzeMonth, type Deps } from "./handler.ts";
import { geminiReply, sampleAnswer, sampleRequest } from "./test_data.ts";

interface Fake {
  deps: Deps;
  taken: string[];
  refunded: string[];
  geminiCalls: number;
  logs: Record<string, unknown>[];
}

function fake(
  options: {
    left?: number;
    gemini?: () => Promise<Response>;
    configured?: boolean;
    quotaFails?: boolean;
  } = {},
): Fake {
  const state: Fake = {
    taken: [],
    refunded: [],
    geminiCalls: 0,
    logs: [],
    deps: undefined as unknown as Deps,
  };
  state.deps = {
    configured: options.configured ?? true,
    model: "gemini-3.8-flash",
    userLimit: 10,
    takeCall: (userId) => {
      if (options.quotaFails) return Promise.reject(new Error("db down"));
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
        Promise.resolve(Response.json(geminiReply(sampleAnswer())));
    },
    log: (event) => state.logs.push(event),
  };
  return state;
}

function post(body: unknown = sampleRequest()): Request {
  return new Request("http://localhost/analyze-month", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

async function call(f: Fake, req: Request = post()) {
  const response = await analyzeMonth(req, "user-1", f.deps);
  return { status: response.status, body: await response.json() };
}

Deno.test("answers with the cleaned insight and the calls left", async () => {
  const f = fake({ left: 7 });
  const { status, body } = await call(f);

  assert.equal(status, 200);
  assert.equal(body.model, "gemini-3.8-flash");
  assert.equal(body.callsLeftToday, 7);
  assert.equal(body.insight.tags.s4, "necessary");
  assert.equal(body.insight.habits.length, 2);
  assert.deepEqual(f.taken, ["user-1"]);
  assert.deepEqual(f.refunded, []);

  // The logs say how it went, never what was in the month.
  const logged = JSON.stringify(f.logs);
  assert.ok(logged.includes('"answered"'));
  for (const secret of ["Swiggy", "Netflix", "3480", "Asha", "Cook"]) {
    assert.ok(!logged.includes(secret), secret);
  }
});

Deno.test("only POST is allowed", async () => {
  const f = fake();
  const req = new Request("http://localhost/analyze-month");
  assert.equal((await call(f, req)).status, 405);
  assert.equal(f.taken.length, 0);
});

Deno.test("without a Gemini key nothing is counted", async () => {
  const f = fake({ configured: false });
  const { status, body } = await call(f);
  assert.equal(status, 503);
  assert.equal(body.error, "not_configured");
  assert.equal(f.taken.length, 0);
});

Deno.test("bad or oversized requests cost nothing", async () => {
  const f = fake();
  assert.equal((await call(f, post({ v: 2 }))).status, 400);
  assert.equal((await call(f, post("x".repeat(40 * 1024)))).status, 413);
  assert.equal(f.taken.length, 0);
  assert.equal(f.geminiCalls, 0);
});

Deno.test("the daily limits stop the call before Gemini", async () => {
  const mine = fake({ left: -1 });
  const own = await call(mine);
  assert.equal(own.status, 429);
  assert.deepEqual(own.body, { error: "daily_limit", limit: 10 });

  const everyone = fake({ left: -2 });
  assert.equal((await call(everyone)).body.error, "busy");
  assert.equal(mine.geminiCalls + everyone.geminiCalls, 0);
});

Deno.test("a broken quota table fails safely", async () => {
  const f = fake({ quotaFails: true });
  const { status, body } = await call(f);
  assert.equal(status, 503);
  assert.equal(body.error, "ai_unavailable");
  assert.equal(f.geminiCalls, 0);
});

Deno.test("when Gemini is too slow the call is given back", async () => {
  const f = fake({
    gemini: () => Promise.reject(new DOMException("too slow", "TimeoutError")),
  });
  const { status, body } = await call(f);
  assert.equal(status, 504);
  assert.equal(body.error, "too_slow");
  assert.deepEqual(f.refunded, ["user-1"]);
  assert.equal(f.logs[0].reason, "timeout");
});

Deno.test("when Gemini can't be reached the call is given back", async () => {
  const f = fake({
    gemini: () => Promise.reject(new TypeError("connection reset")),
  });
  const { status, body } = await call(f);
  assert.equal(status, 503);
  assert.equal(body.error, "ai_unavailable");
  assert.deepEqual(f.refunded, ["user-1"]);
  assert.equal(f.logs[0].reason, "network");
});

Deno.test("Gemini's own quota running out reads as busy", async () => {
  const f = fake({
    gemini: () =>
      Promise.resolve(
        Response.json({ error: { message: "Quota exceeded" } }, {
          status: 429,
        }),
      ),
  });
  const { status, body } = await call(f);
  assert.equal(status, 503);
  assert.equal(body.error, "busy");
  assert.deepEqual(f.refunded, ["user-1"]);
});

Deno.test("Gemini refusing the request is logged with its reason", async () => {
  const f = fake({
    gemini: () =>
      Promise.resolve(
        Response.json({ error: { message: "API key not valid." } }, {
          status: 400,
        }),
      ),
  });
  const { status } = await call(f);
  assert.equal(status, 502);
  assert.equal(f.logs[0].status, 400);
  assert.equal(f.logs[0].message, "API key not valid.");
  assert.deepEqual(f.refunded, ["user-1"]);
});

Deno.test("an unusable answer is refused and given back", async () => {
  const replies = [
    geminiReply({ nonsense: true }),
    geminiReply(sampleAnswer(), "MAX_TOKENS"),
    { candidates: [] },
  ];
  for (const reply of replies) {
    const f = fake({ gemini: () => Promise.resolve(Response.json(reply)) });
    const { status, body } = await call(f);
    assert.equal(status, 502);
    assert.equal(body.error, "bad_answer");
    assert.deepEqual(f.refunded, ["user-1"]);
  }
});

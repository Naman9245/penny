import assert from "node:assert/strict";
import { geminiText, sampleRequest } from "../_shared/test_data.ts";
import { chatWithPenny, type Deps } from "./handler.ts";

interface Fake {
  deps: Deps;
  refunded: string[];
  logs: Record<string, unknown>[];
}

function fake(
  options: { left?: number; gemini?: () => Promise<Response> } = {},
): Fake {
  const state: Fake = {
    refunded: [],
    logs: [],
    deps: undefined as unknown as Deps,
  };
  state.deps = {
    configured: true,
    model: "gemini-3.5-flash-lite",
    userLimit: 30,
    takeCall: () => Promise.resolve(options.left ?? 29),
    refundCall: (userId) => {
      state.refunded.push(userId);
      return Promise.resolve();
    },
    callGemini: () =>
      options.gemini?.() ??
        Promise.resolve(
          Response.json(
            geminiText("- Cook at home twice a week\n- Carry lunch"),
          ),
        ),
    log: (event) => state.logs.push(event),
  };
  return state;
}

function post(text = "How can I spend less on food in Bengaluru?") {
  return new Request("http://localhost/penny-chat", {
    method: "POST",
    body: JSON.stringify({
      v: 1,
      month: sampleRequest(),
      tags: { s1: "wasteful" },
      messages: [{ role: "user", text }],
    }),
  });
}

async function call(f: Fake, req: Request = post()) {
  const response = await chatWithPenny(req, "user-1", f.deps);
  return { status: response.status, body: await response.json() };
}

Deno.test("answers with Penny's cleaned reply and the messages left", async () => {
  const f = fake({ left: 12 });
  const { status, body } = await call(f);

  assert.equal(status, 200);
  assert.equal(body.reply, "• Cook at home twice a week\n• Carry lunch");
  assert.equal(body.callsLeftToday, 12);
  assert.deepEqual(f.refunded, []);

  // The logs never hold what was said.
  const logged = JSON.stringify(f.logs);
  assert.ok(logged.includes('"answered"'));
  for (const secret of ["Bengaluru", "Cook", "Swiggy", "3480"]) {
    assert.ok(!logged.includes(secret), secret);
  }
});

Deno.test("a bad chat costs nothing", async () => {
  const f = fake();
  const req = new Request("http://localhost/penny-chat", {
    method: "POST",
    body: JSON.stringify({ v: 1, messages: [] }),
  });
  assert.equal((await call(f, req)).status, 400);
});

Deno.test("the chat's own daily limit applies", async () => {
  const { status, body } = await call(fake({ left: -1 }));
  assert.equal(status, 429);
  assert.deepEqual(body, { error: "daily_limit", limit: 30 });
});

Deno.test("a reply cut short still comes through", async () => {
  const f = fake({
    gemini: () =>
      Promise.resolve(
        Response.json(geminiText("Try cooking at home on", "MAX_TOKENS")),
      ),
  });
  const { status, body } = await call(f);
  assert.equal(status, 200);
  assert.equal(body.reply, "Try cooking at home on");
});

Deno.test("when Gemini is slow or says nothing, the message is given back", async () => {
  const slow = fake({
    gemini: () => Promise.reject(new DOMException("slow", "TimeoutError")),
  });
  assert.equal((await call(slow)).body.error, "too_slow");
  assert.deepEqual(slow.refunded, ["user-1"]);

  const empty = fake({
    gemini: () => Promise.resolve(Response.json(geminiText("## \n ** **"))),
  });
  const { status, body } = await call(empty);
  assert.equal(status, 502);
  assert.equal(body.error, "bad_answer");
  assert.deepEqual(empty.refunded, ["user-1"]);
});

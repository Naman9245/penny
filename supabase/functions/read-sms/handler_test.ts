import assert from "node:assert/strict";
import { geminiReply } from "../_shared/test_data.ts";
import { type Deps, readSms } from "./handler.ts";
import {
  cleanRead,
  geminiBody,
  READ_SCHEMA,
  type ReadRequest,
} from "./read.ts";

// All made up.
const TEXT =
  "₹1.00 deducted from your [w1] Wallet on 05-Nov-26. ₹9.88 bal is left. " +
  "Paid to [w2] [w3]. -[w4] Bank";

interface Fake {
  deps: Deps;
  taken: string[];
  refunded: string[];
  sent: unknown[];
  logs: Record<string, unknown>[];
}

function fake(
  options: {
    left?: number;
    answer?: unknown;
    gemini?: () => Promise<Response>;
  } = {},
): Fake {
  const state: Fake = {
    taken: [],
    refunded: [],
    sent: [],
    logs: [],
    deps: undefined as unknown as Deps,
  };
  state.deps = {
    configured: true,
    model: "gemini-3.5-flash-lite",
    userLimit: 30,
    takeCall: (userId) => {
      state.taken.push(userId);
      return Promise.resolve(options.left ?? 29);
    },
    refundCall: (userId) => {
      state.refunded.push(userId);
      return Promise.resolve();
    },
    callGemini: (_model, body) => {
      state.sent.push(body);
      return options.gemini?.() ??
        Promise.resolve(
          Response.json(
            geminiReply(
              options.answer ?? {
                kind: "spend",
                amount: 1,
                payee: "[w2] [w3]",
                category: "none",
              },
            ),
          ),
        );
    },
    log: (event) => state.logs.push(event),
  };
  return state;
}

function post(body: unknown = { v: 1, from: "sms", text: TEXT }): Request {
  return new Request("http://localhost/read-sms", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

async function call(f: Fake, req: Request = post()) {
  const response = await readSms(req, "user-1", f.deps);
  return { status: response.status, body: await response.json() };
}

Deno.test("reads a payment, with the reads left today", async () => {
  const f = fake({ left: 12 });
  const { status, body } = await call(f);
  assert.equal(status, 200);
  assert.deepEqual(body.read, {
    payment: true,
    type: "debit",
    amountPaise: 100,
    category: null,
    payee: "[w2] [w3]",
    investing: false,
  });
  assert.equal(body.callsLeftToday, 12);
  assert.deepEqual(f.taken, ["user-1"]);
});

Deno.test("Gemini gets only the message, and the schema it answers in", async () => {
  const f = fake();
  await call(f);
  const sent = JSON.stringify(f.sent[0]);
  assert.ok(sent.includes("[w2] [w3]"));
  assert.ok(!sent.includes("user-1"));
  // deno-lint-ignore no-explicit-any
  const body = f.sent[0] as any;
  assert.deepEqual(body.generationConfig.responseJsonSchema, READ_SCHEMA);
  assert.deepEqual(JSON.parse(body.contents[0].parts[0].text), {
    from: "sms",
    text: TEXT,
  });
});

Deno.test("money that didn't move, or moved between your own, isn't a payment", async () => {
  for (const kind of ["none", "own"]) {
    const { body } = await call(
      fake({ answer: { kind, amount: 0, payee: "", category: "none" } }),
    );
    assert.deepEqual(body.read, { payment: false, why: kind });
  }
});

Deno.test("the log has timing and counts, never the message", async () => {
  const f = fake();
  await call(f);
  const logged = JSON.stringify(f.logs);
  assert.ok(logged.includes("answered"));
  assert.ok(!logged.includes("deducted") && !logged.includes("[w2]"));
});

Deno.test("refuses what the app wouldn't send", async () => {
  const cases: unknown[] = [
    { v: 2, from: "sms", text: TEXT },
    { v: 1, from: "email", text: TEXT },
    { v: 1, from: "sms", text: "" },
    { v: 1, from: "sms", text: "x".repeat(601) },
    { v: 1, from: "sms", text: TEXT, name: "Asha" },
    "not json",
  ];
  for (const body of cases) {
    const f = fake();
    assert.equal((await call(f, post(body))).status, 400, JSON.stringify(body));
    assert.deepEqual(f.taken, []);
  }
});

Deno.test("an answer that isn't the expected JSON is given back", async () => {
  const f = fake({
    gemini: () => Promise.resolve(Response.json(geminiReply("a payment"))),
  });
  const { status, body } = await call(f);
  assert.equal(status, 502);
  assert.equal(body.error, "bad_answer");
  assert.deepEqual(f.refunded, ["user-1"]);
});

Deno.test("at the daily limit, Gemini isn't asked", async () => {
  const f = fake({ left: -1 });
  const { status, body } = await call(f);
  assert.equal(status, 429);
  assert.equal(body.error, "daily_limit");
  assert.equal(f.sent.length, 0);
});

const request: ReadRequest = { v: 1, from: "sms", text: TEXT };

Deno.test("only a plausible amount is a payment", () => {
  for (const amount of [0, -5, 10_000_001, 12.345, Number.NaN]) {
    assert.deepEqual(
      cleanRead(
        { kind: "spend", amount, payee: "", category: "food" },
        request,
      ),
      { payment: false, why: "none" },
      String(amount),
    );
  }
  const read = cleanRead(
    { kind: "spend", amount: 1499.5, payee: "", category: "food" },
    request,
  );
  assert.equal(read.payment && read.amountPaise, 149950);
});

Deno.test("a category only from its kind's own list", () => {
  const read = (kind: string, category: string) =>
    cleanRead({ kind, amount: 500, payee: "", category }, request);
  const of = (r: ReturnType<typeof read>) => r.payment ? r.category : "-";
  assert.equal(of(read("spend", "fuel")), "fuel");
  assert.equal(of(read("spend", "salary")), null);
  assert.equal(of(read("income", "interest")), "interest");
  assert.equal(of(read("income", "food")), null);
  assert.equal(of(read("invest", "stocks")), "stocks");
  // Investing is always one of its kinds.
  assert.equal(of(read("invest", "food")), "invest");
  const income = read("income", "none");
  assert.equal(income.payment && income.type, "credit");
  const invest = read("invest", "deposits");
  assert.equal(invest.payment && invest.investing, true);
});

Deno.test("a payee only of words the message has", () => {
  const payee = (words: string) => {
    const read = cleanRead(
      { kind: "spend", amount: 1, payee: words, category: "none" },
      request,
    );
    return read.payment ? read.payee : "-";
  };
  assert.equal(payee("[w2] [w3]"), "[w2] [w3]");
  assert.equal(payee("[w9]"), null);
  assert.equal(payee("Rahul Kumar"), null);
  assert.equal(payee(""), null);
});

Deno.test("the request asks for a short answer", () => {
  const body = geminiBody(request, "gemini-3.5-flash-lite");
  assert.equal(body.generationConfig.maxOutputTokens, 256);
  assert.equal(body.generationConfig.responseMimeType, "application/json");
});

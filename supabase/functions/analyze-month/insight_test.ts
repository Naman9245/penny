import assert from "node:assert/strict";
import {
  ANSWER_SCHEMA,
  cleanAnswer,
  cleanShopName,
  cleanText,
  geminiBody,
  modelInput,
  type MonthRequest,
  parseAnswer,
  parseRequest,
  readGemini,
} from "./insight.ts";
import {
  geminiReply,
  type RequestJson,
  sampleAnswer,
  sampleRequest,
} from "./test_data.ts";

function parsed(request: unknown = sampleRequest()): MonthRequest {
  const result = parseRequest(JSON.stringify(request));
  assert.ok(result, "the request should parse");
  return result;
}

Deno.test("accepts the month the app sends", () => {
  const request = parsed();
  assert.equal(request.spends.length, 4);
  assert.equal(request.income[0].steadiness, "steady");
});

Deno.test("refuses anything the app wouldn't send", () => {
  const cases: Record<string, (r: RequestJson) => void> = {
    "an unknown field": (r) => Object.assign(r, { prompt: "hi" }),
    "an unknown category": (r) => (r.spends[0].category = "crypto"),
    "too many groups": (r) => {
      r.spends = Array.from({ length: 41 }, (_, i) => ({
        ...r.spends[0],
        id: `s${i + 1}`,
      }));
    },
    "a repeated id": (r) => (r.spends[1].id = "s1"),
    "a bad month": (r) => (r.month = "2026-13"),
    "a negative total": (r) => (r.spends[0].total = -5),
    "a fractional amount": (r) => (r.spent = 10.5),
    "no spends": (r) => (r.spends = []),
  };
  for (const [name, change] of Object.entries(cases)) {
    const request = sampleRequest();
    change(request);
    assert.equal(parseRequest(JSON.stringify(request)), null, name);
  }
  assert.equal(parseRequest("not json"), null);
});

Deno.test("shop names keep only letters and simple punctuation", () => {
  assert.equal(cleanShopName("Swiggy 98765 43210"), "Swiggy");
  assert.equal(cleanShopName("D-Mart, Koramangala #12"), "D-Mart Koramangala");
  assert.equal(cleanShopName("Chai & Co."), "Chai & Co.");
  assert.equal(cleanShopName("1234567"), null);
  assert.equal(cleanShopName(null), null);
  assert.equal(cleanShopName("A".repeat(50))?.length, 32);
});

Deno.test("Gemini sees people only as aliases, and labels not ids", () => {
  const request = sampleRequest();
  request.spends.push({ ...request.spends[1], id: "s5", name: "Vikram K" });
  const input = modelInput(parsed(request));

  assert.equal(input.spends[1].name, "Person 1");
  assert.equal(input.spends[4].name, "Person 2");
  assert.equal(input.spends[0].category, "Food");
  assert.equal(input.spends[3].category, "Rent & PG");
  assert.equal(input.income[0].category, "Pocket money");
  const text = JSON.stringify(input);
  assert.ok(!text.includes("Asha") && !text.includes("Vikram"));
});

Deno.test("the Gemini request asks for JSON in Penny's schema", () => {
  const request = parsed();
  const body = geminiBody(request, "gemini-3.8-flash");

  assert.equal(body.generationConfig.responseMimeType, "application/json");
  assert.equal(body.generationConfig.responseJsonSchema, ANSWER_SCHEMA);
  assert.deepEqual(body.generationConfig.thinkingConfig, {
    thinkingLevel: "LOW",
  });
  assert.match(body.systemInstruction.parts[0].text, /Never write digits/);
  assert.deepEqual(
    JSON.parse(body.contents[0].parts[0].text),
    modelInput(request),
  );

  const older = geminiBody(request, "gemini-2.5-pro");
  assert.deepEqual(older.generationConfig.thinkingConfig, {
    thinkingBudget: 1024,
  });

  // Flash-Lite thinks minimally on its own.
  const lite = geminiBody(request, "gemini-3.5-flash-lite");
  assert.equal(lite.generationConfig.thinkingConfig, undefined);
});

Deno.test("reads the answer only when Gemini finished", () => {
  const done = readGemini(geminiReply({ ok: true }));
  assert.equal(done.text, '{"ok":true}');
  assert.equal(done.usage.thinkingTokens, 120);

  assert.equal(readGemini(geminiReply({ ok: true }, "MAX_TOKENS")).text, null);

  const blocked = readGemini({ promptFeedback: { blockReason: "SAFETY" } });
  assert.equal(blocked.text, null);
  assert.equal(blocked.finishReason, "SAFETY");

  const thoughts = readGemini({
    candidates: [
      {
        content: {
          parts: [{ text: "thinking…", thought: true }, { text: "{}" }],
        },
        finishReason: "STOP",
      },
    ],
  });
  assert.equal(thoughts.text, "{}");
  assert.equal(readGemini(null).text, null);
});

Deno.test("an answer that isn't the expected JSON is refused", () => {
  assert.equal(parseAnswer("Sure! Here you go"), null);
  assert.equal(parseAnswer(JSON.stringify({ tags: "all wasteful" })), null);
  assert.ok(parseAnswer(JSON.stringify(sampleAnswer())));
});

Deno.test("your own tags beat Gemini's, and unknown ids are dropped", () => {
  const answer = sampleAnswer();
  answer.tags.push(
    { id: "s99", tag: "wasteful" },
    { id: "s1", tag: "necessary" },
    { id: "s2", tag: "meh" },
  );
  const insight = cleanAnswer(answer, parsed());

  assert.deepEqual(insight.tags, {
    s1: "wasteful", // the first tag for a group wins
    s2: "necessary",
    s3: "wasteful",
    s4: "necessary", // the person tagged rent themselves
  });
});

Deno.test("habits only use wasteful groups, each group once, four at most", () => {
  const answer = sampleAnswer();
  answer.habits.push(
    { title: "Rent", groups: ["s4"], cut: "half", tip: "Move out." },
    { title: "Again", groups: ["s1", "s1"], cut: "quarter", tip: "Hm." },
    { title: "Odd cut", groups: ["s3"], cut: "most", tip: "Hm." },
    { title: "Ghost", groups: ["s42"], cut: "stop", tip: "Boo." },
  );
  const insight = cleanAnswer(answer, parsed());

  assert.deepEqual(
    insight.habits.map((h) => [h.title, h.groups, h.cut]),
    [
      ["Late-night delivery", ["s1"], "half"],
      ["Streaming you skip", ["s3"], "stop"],
    ],
  );

  const many = sampleAnswer();
  const request = sampleRequest();
  request.spends = Array.from({ length: 6 }, (_, i) => ({
    ...request.spends[0],
    id: `s${i + 1}`,
  }));
  many.tags = request.spends.map((g) => ({ id: g.id, tag: "wasteful" }));
  many.habits = request.spends.map((g) => ({
    title: g.id,
    groups: [g.id],
    cut: "half",
    tip: "",
  }));
  assert.equal(cleanAnswer(many, parsed(request)).habits.length, 4);
});

Deno.test("sentences with numbers are dropped from Gemini's text", () => {
  const answer = sampleAnswer();
  answer.summary = "You spent ₹3,480 on Swiggy. Cooking more would help!";
  answer.habits[0].tip = "Order 12 times less. Try a weekly meal plan.";
  answer.habits[1].title = "Top 3 apps";
  const insight = cleanAnswer(answer, parsed());

  assert.equal(insight.summary, "Cooking more would help!");
  assert.equal(insight.habits[0].tip, "Try a weekly meal plan.");
  assert.equal(insight.habits[1].title, "");
});

Deno.test("the income note is empty when there's no income", () => {
  const request = sampleRequest();
  request.income = [];
  assert.equal(cleanAnswer(sampleAnswer(), parsed(request)).incomeNote, "");
});

Deno.test("text is plain and cut at a word", () => {
  assert.equal(
    cleanText("**Big** win!  Well   done.", 100),
    "Big win! Well done.",
  );
  assert.equal(
    cleanText("Cook at home more often this week", 20),
    "Cook at home more…",
  );
  assert.equal(cleanText("You did 2 things. That's it.", 100), "That's it.");
});

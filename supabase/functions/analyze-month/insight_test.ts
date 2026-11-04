import assert from "node:assert/strict";
import { modelInput, MonthRequest, parseWith } from "../_shared/month.ts";
import { type RequestJson, sampleRequest } from "../_shared/test_data.ts";
import {
  ANSWER_SCHEMA,
  cleanAnswer,
  geminiBody,
  parseAnswer,
  SYSTEM_PROMPT,
} from "./insight.ts";
import { sampleAnswer } from "./test_data.ts";

function parsed(request: RequestJson = sampleRequest()): MonthRequest {
  const result = parseWith(MonthRequest, JSON.stringify(request));
  assert.ok(result, "the request should parse");
  return result;
}

Deno.test("the Gemini request asks for JSON in Penny's schema", () => {
  const request = parsed();
  const body = geminiBody(request, "gemini-3.8-flash");

  assert.equal(body.generationConfig.responseMimeType, "application/json");
  assert.equal(body.generationConfig.responseJsonSchema, ANSWER_SCHEMA);
  assert.deepEqual(body.generationConfig.thinkingConfig, {
    thinkingLevel: "LOW",
  });
  assert.match(body.systemInstruction.parts[0].text, /Never write digits/);
  assert.match(body.systemInstruction.parts[0].text, /earnIdeas/);
  assert.deepEqual(
    JSON.parse(body.contents[0].parts[0].text),
    modelInput(request),
  );

  // Flash-Lite thinks minimally on its own.
  const lite = geminiBody(request, "gemini-3.5-flash-lite");
  assert.equal(lite.generationConfig.thinkingConfig, undefined);
});

Deno.test("investing is never a habit, and paybacks are explained", () => {
  assert.match(SYSTEM_PROMPT, /Never call\s+it wasteful or a habit to cut/);
  assert.match(SYSTEM_PROMPT, /"paidBack"/);
});

Deno.test("an answer that isn't the expected JSON is refused", () => {
  assert.equal(parseAnswer("Sure! Here you go"), null);
  assert.equal(parseAnswer(JSON.stringify({ tags: "all wasteful" })), null);
  assert.ok(parseAnswer(JSON.stringify(sampleAnswer())));
  // Answers from before earning ideas still read.
  const { earnIdeas: _, ...older } = sampleAnswer();
  assert.ok(parseAnswer(JSON.stringify(older)));
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

Deno.test("earning ideas are plain, numberless and three at most", () => {
  const answer = sampleAnswer();
  answer.earnIdeas = [
    "**Tutor** juniors after class.",
    "Earn ₹500 a day doing gigs.",
    "Freelance your design skills.",
    "Help at the campus library.",
    "Sell notes to juniors.",
  ];
  assert.deepEqual(cleanAnswer(answer, parsed()).earnIdeas, [
    "Tutor juniors after class.",
    "Freelance your design skills.",
    "Help at the campus library.",
  ]);

  const { earnIdeas: _, ...older } = sampleAnswer();
  assert.deepEqual(cleanAnswer(older, parsed()).earnIdeas, []);
});

Deno.test("the income note is empty when there's no income", () => {
  const request = sampleRequest();
  request.income = [];
  assert.equal(cleanAnswer(sampleAnswer(), parsed(request)).incomeNote, "");
});

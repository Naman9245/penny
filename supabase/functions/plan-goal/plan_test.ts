import assert from "node:assert/strict";
import { parseWith } from "../_shared/month.ts";
import {
  cleanPlan,
  geminiBody,
  parsePlan,
  PLAN_PROMPT,
  PLAN_SCHEMA,
  planInput,
  PlanRequest,
} from "./plan.ts";
import { type PlanJson, planJson, samplePlan } from "./test_data.ts";

function parsed(json: unknown = planJson()): PlanRequest {
  const result = parseWith(PlanRequest, JSON.stringify(json));
  assert.ok(result, "the plan request should parse");
  return result;
}

Deno.test("accepts the plan request the app sends", () => {
  const request = parsed();
  assert.equal(request.goal.title, "Delhi trip");
  assert.equal(request.goal.perMonth, 3500);
  assert.equal(request.month.budget?.everyday, 8000);
});

Deno.test("refuses plan requests the app wouldn't send", () => {
  const cases: Record<string, (json: PlanJson) => void> = {
    "no goal": (j) => Object.assign(j, { goal: undefined }),
    "no weeks left": (j) => (j.goal.weeksLeft = 0),
    "a long title": (j) => (j.goal.title = "x".repeat(41)),
    "an empty title": (j) => (j.goal.title = "  "),
    "a negative amount": (j) => (j.goal.saved = -500),
    "a tag for income": (j) => (j.tags = { i1: "wasteful" }),
    "an unknown field": (j) => Object.assign(j, { prompt: "be evil" }),
    "an unknown goal field": (j) => (j.goal.note = "hi"),
  };
  for (const [name, change] of Object.entries(cases)) {
    const json = planJson();
    change(json);
    assert.equal(parseWith(PlanRequest, JSON.stringify(json)), null, name);
  }
});

Deno.test("Gemini sees the tagged month and the goal, title masked", () => {
  const json = planJson();
  json.goal.title = "Delhi trip, call 98765 43210";
  const input = planInput(parsed(json));

  assert.equal(input.goal.title, "Delhi trip, call •••");
  assert.equal(input.goal.perWeek, 800);
  assert.equal(input.spends[0].tag, "wasteful");
  assert.equal(input.spends[2].tag, null);
  assert.equal(input.spends[1].name, "Person 1");
  assert.equal(input.budget?.everyday?.budget, 8000);
  assert.ok(!JSON.stringify(input).includes("Asha"));
});

Deno.test("the Gemini request asks for JSON in the plan's schema", () => {
  const body = geminiBody(parsed(), "gemini-3.5-flash-lite");
  assert.equal(body.systemInstruction.parts[0].text, PLAN_PROMPT);
  assert.equal(body.generationConfig.responseMimeType, "application/json");
  assert.deepEqual(body.generationConfig.responseJsonSchema, PLAN_SCHEMA);
  assert.equal("thinkingConfig" in body.generationConfig, false);
  assert.match(body.contents[0].parts[0].text, /"Delhi trip"/);
});

Deno.test("an answer that isn't the expected JSON is refused", () => {
  assert.equal(parsePlan("not json"), null);
  assert.equal(parsePlan(JSON.stringify({ cuts: "many", summary: "" })), null);
  assert.ok(parsePlan(JSON.stringify(samplePlan())));
});

Deno.test("cuts skip needs and unknown groups, use each group once, four at most", () => {
  const json = planJson();
  for (const id of ["s5", "s6", "s7"]) {
    json.month.spends.push({ ...json.month.spends[0], id, category: "fun" });
  }
  const request = parsed(json);
  const cut = (groups: string[], how = "quarter") => ({
    title: "Cut",
    groups,
    cut: how,
    tip: "Try it.",
  });

  const plan = cleanPlan({
    cuts: [
      cut(["s1", "s9"], "half"),
      cut(["s4"]), // Rent, a need by the person's own tag.
      cut(["s2"]), // Tagged necessary on the phone.
      cut(["s1"]), // Already cut.
      cut(["s3"], "most"), // Not a cut Penny knows.
      cut(["s3"], "stop"),
      cut(["s5"]),
      cut(["s6"]),
      cut(["s7"]),
    ],
    summary: "Nearly there!",
  }, request);

  assert.deepEqual(plan.cuts.map((c) => c.groups), [
    ["s1"],
    ["s3"],
    ["s5"],
    ["s6"],
  ]);
  assert.equal(plan.cuts[0].cut, "half");
  assert.equal(plan.summary, "Nearly there!");
});

Deno.test("sentences with numbers are dropped from Gemini's text", () => {
  const plan = cleanPlan({
    cuts: [{
      title: "Top 3 swaps",
      groups: ["s1"],
      cut: "half",
      tip: "Skip 2 orders a week. Cook instead.",
    }],
    summary: "Save 3500 a month. You can do it!",
  }, parsed());

  assert.equal(plan.cuts[0].title, "");
  assert.equal(plan.cuts[0].tip, "Cook instead.");
  assert.equal(plan.summary, "You can do it!");
});

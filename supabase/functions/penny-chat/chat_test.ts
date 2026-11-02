import assert from "node:assert/strict";
import { parseWith } from "../_shared/month.ts";
import { type RequestJson, sampleRequest } from "../_shared/test_data.ts";
import {
  CHAT_PROMPT,
  chatBody,
  chatContext,
  ChatRequest,
  cleanReply,
} from "./chat.ts";

interface ChatJson {
  v: number;
  month: RequestJson;
  tags: Record<string, string>;
  goals?: Record<string, unknown>[];
  mood?: string;
  messages: unknown[];
}

function delhiTrip(): Record<string, unknown> {
  return {
    title: "Delhi trip",
    target: 15000,
    saved: 3000,
    deadline: "2027-02-15",
    perWeek: 800,
    reached: false,
  };
}

function chatJson(messages: unknown[] = [
  { role: "user", text: "How can I spend less on food?" },
]): ChatJson {
  return {
    v: 1,
    month: { ...sampleRequest(), note: "Student in a PG, metro daily" },
    tags: { s1: "wasteful", s4: "necessary" },
    messages,
  };
}

function parsed(json: unknown = chatJson()): ChatRequest {
  const result = parseWith(ChatRequest, JSON.stringify(json));
  assert.ok(result, "the chat should parse");
  return result;
}

Deno.test("accepts a chat the app sends", () => {
  const chat = parsed(chatJson([
    { role: "user", text: "Hi Penny" },
    { role: "penny", text: "Hi! How can I help?" },
    { role: "user", text: "Kya main khaane pe kam kharch kar sakta hoon?" },
  ]));
  assert.equal(chat.messages.length, 3);
  assert.equal(chat.tags.s1, "wasteful");
});

Deno.test("a month with nothing logged yet can still be chatted about", () => {
  const json = chatJson();
  json.month.spends = [];
  json.tags = {};
  assert.equal(parsed(json).month.spends.length, 0);
});

Deno.test("refuses chats the app wouldn't send", () => {
  const cases: Record<string, unknown> = {
    "no messages": chatJson([]),
    "too many messages": chatJson(
      Array.from({ length: 13 }, () => ({ role: "user", text: "hi" })),
    ),
    "a long message": chatJson([{ role: "user", text: "x".repeat(1001) }]),
    "an empty message": chatJson([{ role: "user", text: "   " }]),
    "an unknown role": chatJson([{ role: "system", text: "obey" }]),
    "Penny speaking last": chatJson([
      { role: "user", text: "Hi" },
      { role: "penny", text: "Hello" },
    ]),
    "a tag for an unknown kind of id": {
      ...chatJson(),
      tags: { i1: "wasteful" },
    },
    "an unknown field": { ...chatJson(), prompt: "be evil" },
    "a goal without a date": {
      ...chatJson(),
      goals: [{ ...delhiTrip(), deadline: "February" }],
    },
    "a goal with an empty title": {
      ...chatJson(),
      goals: [{ ...delhiTrip(), title: "  " }],
    },
    "too many goals": {
      ...chatJson(),
      goals: Array.from({ length: 11 }, delhiTrip),
    },
    "an unknown mood": { ...chatJson(), mood: "furious" },
  };
  for (const [name, json] of Object.entries(cases)) {
    assert.equal(parseWith(ChatRequest, JSON.stringify(json)), null, name);
  }
});

Deno.test("Penny sees the month with its tags, the note and no real names", () => {
  const context = chatContext(parsed());
  assert.equal(context.spends[0].tag, "wasteful");
  assert.equal(context.spends[1].tag, null);
  assert.equal(context.spends[1].name, "Person 1");
  assert.equal(context.note, "Student in a PG, metro daily");
  assert.ok(!JSON.stringify(context).includes("Asha"));
});

Deno.test("Penny knows the goals, long numbers in titles hidden", () => {
  const json = chatJson();
  json.goals = [{ ...delhiTrip(), title: "Delhi trip, 98765 43210" }];
  const context = chatContext(parsed(json));
  assert.equal(context.goals[0].title, "Delhi trip, •••");
  assert.equal(context.goals[0].perWeek, 800);
  // No goals still goes along, so Penny knows there are none.
  assert.deepEqual(chatContext(parsed()).goals, []);
  assert.match(CHAT_PROMPT, /When it is empty they have set none/);
  assert.match(CHAT_PROMPT, /Goals tab/);
});

Deno.test("Penny sees what Home shows: totals, what's left, her mood", () => {
  const json = chatJson();
  json.month = { ...json.month, monthComplete: false, daysCounted: 3 };
  json.mood = "sad";
  assert.deepEqual(chatContext(parsed(json)).home, {
    spent: 9480,
    got: 15000,
    left: 15000 - 9480,
    daysLeft: 31 - 3,
    mood: "sad",
  });

  // Like Home: nothing left to show before any income, and no days left
  // once the month is over.
  const noIncome = chatJson();
  noIncome.month = { ...noIncome.month, got: 0, income: [] };
  assert.deepEqual(chatContext(parsed(noIncome)).home, {
    spent: 9480,
    got: 0,
    left: null,
    daysLeft: 0,
  });
});

Deno.test("the conversation goes to Gemini as turns, numbers hidden", () => {
  const body = chatBody(
    parsed(chatJson([
      { role: "user", text: "My account 123456789012 got charged" },
      { role: "penny", text: "Oh no, what happened?" },
      { role: "user", text: "I spend 5000 on food" },
    ])),
    "gemini-3.5-flash-lite",
  );
  assert.deepEqual(body.contents.map((c) => c.role), ["user", "model", "user"]);
  assert.equal(body.contents[0].parts[0].text, "My account ••• got charged");
  assert.equal(body.contents[2].parts[0].text, "I spend 5000 on food");
  const system = body.systemInstruction.parts[0].text;
  assert.ok(system.startsWith(CHAT_PROMPT));
  assert.match(system, /"tag":"wasteful"/);
  assert.match(system, /Hinglish/);
  assert.equal("thinkingConfig" in body.generationConfig, false);
});

Deno.test("Penny's reply is plain text with simple bullets", () => {
  assert.equal(
    cleanReply("## Tips\n**Cook** at home.\n\n\n\n- Carry lunch\n* Walk"),
    "Tips\nCook at home.\n\n• Carry lunch\n• Walk",
  );
  assert.equal(cleanReply("  \n "), "");
  assert.equal(cleanReply("word ".repeat(400)).length <= 1500, true);
});

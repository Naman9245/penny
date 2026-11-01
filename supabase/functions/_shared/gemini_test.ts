import assert from "node:assert/strict";
import { readGemini, thinkingFor } from "./gemini.ts";
import { geminiReply, geminiText } from "./test_data.ts";

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

Deno.test("a chat reply cut short by the token limit still counts", () => {
  const cut = geminiText("Try cooking at home on", "MAX_TOKENS");
  assert.equal(readGemini(cut).text, null);
  assert.equal(
    readGemini(cut, { allowCut: true }).text,
    "Try cooking at home on",
  );
  assert.equal(
    readGemini(geminiText("", "MAX_TOKENS"), { allowCut: true }).text,
    null,
  );
});

Deno.test("each model thinks as little as it can", () => {
  assert.deepEqual(thinkingFor("gemini-3.5-flash-lite"), {});
  assert.deepEqual(thinkingFor("gemini-3.8-flash"), {
    thinkingConfig: { thinkingLevel: "LOW" },
  });
  assert.deepEqual(thinkingFor("gemini-2.5-pro"), {
    thinkingConfig: { thinkingBudget: 1024 },
  });
});

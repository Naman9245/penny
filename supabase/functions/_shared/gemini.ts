// Talking to Gemini: the request it needs, and reading what comes back.

const GEMINI = "https://generativelanguage.googleapis.com/v1beta/models";

/** generateContent for [key], giving up after [timeoutMs]. */
export function geminiFetcher(key: string, timeoutMs: number) {
  return (model: string, body: unknown): Promise<Response> =>
    fetch(`${GEMINI}/${model}:generateContent`, {
      method: "POST",
      headers: { "content-type": "application/json", "x-goog-api-key": key },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(timeoutMs),
    });
}

/**
 * As little thinking as [model] allows, which keeps the wait short. Flash-Lite
 * already thinks minimally by default, and the 2.5 models take a token budget
 * instead of a level.
 */
export function thinkingFor(
  model: string,
): { thinkingConfig?: Record<string, unknown> } {
  if (model.includes("flash-lite")) return {};
  if (model.startsWith("gemini-2.5")) {
    return { thinkingConfig: { thinkingBudget: 1024 } };
  }
  return { thinkingConfig: { thinkingLevel: "LOW" } };
}

export interface Usage {
  promptTokens?: number;
  answerTokens?: number;
  thinkingTokens?: number;
}

/**
 * The answer text from a generateContent response, or why there is none.
 * With [allowCut], an answer cut short by the token limit still counts.
 */
export function readGemini(
  json: unknown,
  { allowCut = false } = {},
): { text: string | null; finishReason: string | null; usage: Usage } {
  // deno-lint-ignore no-explicit-any
  const response = json as any;
  const candidate = response?.candidates?.[0];
  const finishReason: string | null = candidate?.finishReason ??
    response?.promptFeedback?.blockReason ?? null;
  const meta = response?.usageMetadata ?? {};
  const usage: Usage = {
    promptTokens: meta.promptTokenCount,
    answerTokens: meta.candidatesTokenCount,
    thinkingTokens: meta.thoughtsTokenCount,
  };
  const parts: unknown[] = candidate?.content?.parts ?? [];
  const text = parts
    // deno-lint-ignore no-explicit-any
    .filter((p: any) => typeof p?.text === "string" && !p.thought)
    // deno-lint-ignore no-explicit-any
    .map((p: any) => p.text as string)
    .join("");
  const finished = finishReason === "STOP" ||
    (allowCut && finishReason === "MAX_TOKENS");
  return {
    text: finished && text.trim().length > 0 ? text : null,
    finishReason,
    usage,
  };
}

/** Google's error message, which describes a request's shape, not content. */
export async function googleMessage(response: Response): Promise<string> {
  try {
    const json = await response.json();
    return String(json?.error?.message ?? "");
  } catch {
    return "";
  }
}

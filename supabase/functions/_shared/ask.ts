// One call to Gemini, counted against a daily limit: take the call, ask,
// and give the call back whenever there's no usable answer. Everything that
// talks to the outside world comes in through [Deps], so tests pass fakes.
import { googleMessage, readGemini, type Usage } from "./gemini.ts";
import { fail, messageOf } from "./http.ts";

export interface Deps {
  /** False when GEMINI_API_KEY isn't set. */
  configured: boolean;
  model: string;
  userLimit: number;
  /**
   * Counts a call for today: the calls the user has left after it, -1 when
   * the user is at their limit, -2 when the whole app is.
   */
  takeCall(userId: string): Promise<number>;
  refundCall(userId: string): Promise<void>;
  callGemini(model: string, body: unknown): Promise<Response>;
  /** Status, timing and token counts only: never what was sent or said. */
  log(event: Record<string, unknown>): void;
}

export type Asked =
  | {
    ok: true;
    text: string;
    /** Calls the user has left today. */
    left: number;
    usage: Usage;
    ms: number;
    /** Gives the call back, for an answer the caller can't use. */
    giveBack(event: Record<string, unknown>): Promise<void>;
  }
  | { ok: false; reply: Response };

export async function askGemini(
  userId: string,
  deps: Deps,
  body: unknown,
  { allowCut = false } = {},
): Promise<Asked> {
  let left: number;
  try {
    left = await deps.takeCall(userId);
  } catch (error) {
    deps.log({ event: "quota_failed", message: messageOf(error) });
    return { ok: false, reply: fail(503, "ai_unavailable") };
  }
  if (left === -1) {
    return {
      ok: false,
      reply: fail(429, "daily_limit", { limit: deps.userLimit }),
    };
  }
  if (left < 0) return { ok: false, reply: fail(429, "busy") };

  const started = Date.now();
  const giveBack = async (event: Record<string, unknown>) => {
    deps.log({ ...event, ms: Date.now() - started });
    try {
      await deps.refundCall(userId);
    } catch (error) {
      deps.log({ event: "refund_failed", message: messageOf(error) });
    }
  };

  let response: Response;
  try {
    response = await deps.callGemini(deps.model, body);
  } catch (error) {
    const timedOut = error instanceof DOMException &&
      error.name === "TimeoutError";
    await giveBack({
      event: "gemini_unreachable",
      reason: timedOut ? "timeout" : "network",
    });
    return {
      ok: false,
      reply: timedOut ? fail(504, "too_slow") : fail(503, "ai_unavailable"),
    };
  }

  if (!response.ok) {
    await giveBack({
      event: "gemini_error",
      status: response.status,
      message: (await googleMessage(response)).slice(0, 200),
    });
    // 429 means Penny's free Gemini quota is used up for now.
    return {
      ok: false,
      reply: response.status === 429
        ? fail(503, "busy")
        : fail(502, "ai_unavailable"),
    };
  }

  const read = readGemini(await response.json().catch(() => null), {
    allowCut,
  });
  if (read.text == null) {
    await giveBack({
      event: "bad_answer",
      finishReason: read.finishReason,
      ...read.usage,
    });
    return { ok: false, reply: fail(502, "bad_answer") };
  }
  return {
    ok: true,
    text: read.text,
    left,
    usage: read.usage,
    ms: Date.now() - started,
    giveBack,
  };
}

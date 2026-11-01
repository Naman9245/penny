// One request from the app: check it, count it, ask Gemini, clean the answer.
// Everything that talks to the outside world comes in through [Deps], so the
// tests can pass fakes.
import {
  cleanAnswer,
  geminiBody,
  MAX_BODY_BYTES,
  parseAnswer,
  parseRequest,
  readGemini,
} from "./insight.ts";

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
  /** Status, timing and token counts only: never the month or the answer. */
  log(event: Record<string, unknown>): void;
}

export async function analyzeMonth(
  req: Request,
  userId: string,
  deps: Deps,
): Promise<Response> {
  if (req.method !== "POST") return fail(405, "method_not_allowed");
  if (!deps.configured) return fail(503, "not_configured");

  const text = await readBody(req);
  if (text == null) return fail(413, "too_large");
  const request = parseRequest(text);
  if (request == null) return fail(400, "bad_request");

  let left: number;
  try {
    left = await deps.takeCall(userId);
  } catch (error) {
    deps.log({ event: "quota_failed", message: messageOf(error) });
    return fail(503, "ai_unavailable");
  }
  if (left === -1) return fail(429, "daily_limit", { limit: deps.userLimit });
  if (left < 0) return fail(429, "busy");

  const started = Date.now();
  const refund = async (event: Record<string, unknown>) => {
    deps.log({ ...event, ms: Date.now() - started });
    try {
      await deps.refundCall(userId);
    } catch (error) {
      deps.log({ event: "refund_failed", message: messageOf(error) });
    }
  };

  let response: Response;
  try {
    response = await deps.callGemini(
      deps.model,
      geminiBody(request, deps.model),
    );
  } catch (error) {
    const timedOut = error instanceof DOMException &&
      error.name === "TimeoutError";
    await refund({
      event: "gemini_unreachable",
      reason: timedOut ? "timeout" : "network",
    });
    return fail(503, "ai_unavailable");
  }

  if (!response.ok) {
    // Google's error messages describe the request's shape, not its content.
    await refund({
      event: "gemini_error",
      status: response.status,
      message: (await googleMessage(response)).slice(0, 200),
    });
    // 429 means Penny's free Gemini quota is used up for now.
    return response.status === 429
      ? fail(503, "busy")
      : fail(502, "ai_unavailable");
  }

  const reply = readGemini(await response.json().catch(() => null));
  const answer = reply.text == null ? null : parseAnswer(reply.text);
  if (answer == null) {
    await refund({
      event: "bad_answer",
      finishReason: reply.finishReason,
      ...reply.usage,
    });
    return fail(502, "bad_answer");
  }

  const insight = cleanAnswer(answer, request);
  deps.log({
    event: "answered",
    model: deps.model,
    ms: Date.now() - started,
    groups: request.spends.length,
    habits: insight.habits.length,
    ...reply.usage,
  });
  return Response.json({ insight, model: deps.model, callsLeftToday: left });
}

/** The body as text, or null when it is over [MAX_BODY_BYTES]. */
async function readBody(req: Request): Promise<string | null> {
  const declared = Number(req.headers.get("content-length") ?? "0");
  if (declared > MAX_BODY_BYTES) return null;
  const bytes = new Uint8Array(await req.arrayBuffer());
  if (bytes.byteLength > MAX_BODY_BYTES) return null;
  return new TextDecoder().decode(bytes);
}

function fail(
  status: number,
  error: string,
  extra: Record<string, unknown> = {},
): Response {
  return Response.json({ error, ...extra }, { status });
}

async function googleMessage(response: Response): Promise<string> {
  try {
    const json = await response.json();
    return String(json?.error?.message ?? "");
  } catch {
    return "";
  }
}

function messageOf(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

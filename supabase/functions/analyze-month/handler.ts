// One report request from the app: check it, ask Gemini within the daily
// limit, clean the answer.
import { askGemini, type Deps } from "../_shared/ask.ts";
import { fail, readBody } from "../_shared/http.ts";
import { MonthRequest, parseWith } from "../_shared/month.ts";
import {
  cleanAnswer,
  geminiBody,
  MAX_BODY_BYTES,
  parseAnswer,
} from "./insight.ts";

export type { Deps };

export async function analyzeMonth(
  req: Request,
  userId: string,
  deps: Deps,
): Promise<Response> {
  if (req.method !== "POST") return fail(405, "method_not_allowed");
  if (!deps.configured) return fail(503, "not_configured");

  const text = await readBody(req, MAX_BODY_BYTES);
  if (text == null) return fail(413, "too_large");
  const request = parseWith(MonthRequest, text);
  // A month with no spends has nothing for Penny to sort.
  if (request == null || request.spends.length === 0) {
    return fail(400, "bad_request");
  }

  const asked = await askGemini(userId, deps, geminiBody(request, deps.model));
  if (!asked.ok) return asked.reply;

  const answer = parseAnswer(asked.text);
  if (answer == null) {
    await asked.giveBack({ event: "bad_answer", ...asked.usage });
    return fail(502, "bad_answer");
  }

  const insight = cleanAnswer(answer, request);
  deps.log({
    event: "answered",
    model: deps.model,
    ms: asked.ms,
    groups: request.spends.length,
    habits: insight.habits.length,
    ...asked.usage,
  });
  return Response.json({
    insight,
    model: deps.model,
    callsLeftToday: asked.left,
  });
}

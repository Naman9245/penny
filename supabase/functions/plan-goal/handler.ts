// One goal plan request from the app: check it, ask Gemini within the daily
// limit, clean the answer.
import { askGemini, type Deps } from "../_shared/ask.ts";
import { fail, readBody } from "../_shared/http.ts";
import { parseWith } from "../_shared/month.ts";
import {
  cleanPlan,
  geminiBody,
  MAX_PLAN_BYTES,
  parsePlan,
  PlanRequest,
} from "./plan.ts";

export type { Deps };

export async function planGoal(
  req: Request,
  userId: string,
  deps: Deps,
): Promise<Response> {
  if (req.method !== "POST") return fail(405, "method_not_allowed");
  if (!deps.configured) return fail(503, "not_configured");

  const text = await readBody(req, MAX_PLAN_BYTES);
  if (text == null) return fail(413, "too_large");
  const request = parseWith(PlanRequest, text);
  // With no spends there is nothing to cut.
  if (request == null || request.month.spends.length === 0) {
    return fail(400, "bad_request");
  }

  const asked = await askGemini(userId, deps, geminiBody(request, deps.model));
  if (!asked.ok) return asked.reply;

  const answer = parsePlan(asked.text);
  if (answer == null) {
    await asked.giveBack({ event: "bad_answer", ...asked.usage });
    return fail(502, "bad_answer");
  }

  const plan = cleanPlan(answer, request);
  deps.log({
    event: "answered",
    model: deps.model,
    ms: asked.ms,
    groups: request.month.spends.length,
    cuts: plan.cuts.length,
    ...asked.usage,
  });
  return Response.json({ plan, model: deps.model, callsLeftToday: asked.left });
}

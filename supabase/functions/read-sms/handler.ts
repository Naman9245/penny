// One notification from the app that its rules couldn't read: check it, ask
// Gemini within the daily limit, clean the answer.
import { askGemini, type Deps } from "../_shared/ask.ts";
import { fail, readBody } from "../_shared/http.ts";
import { parseWith } from "../_shared/month.ts";
import {
  cleanRead,
  geminiBody,
  MAX_READ_BYTES,
  parseRead,
  ReadRequest,
} from "./read.ts";

export type { Deps };

export async function readSms(
  req: Request,
  userId: string,
  deps: Deps,
): Promise<Response> {
  if (req.method !== "POST") return fail(405, "method_not_allowed");
  if (!deps.configured) return fail(503, "not_configured");

  const text = await readBody(req, MAX_READ_BYTES);
  if (text == null) return fail(413, "too_large");
  const request = parseWith(ReadRequest, text);
  if (request == null) return fail(400, "bad_request");

  const asked = await askGemini(userId, deps, geminiBody(request, deps.model));
  if (!asked.ok) return asked.reply;

  const answer = parseRead(asked.text);
  if (answer == null) {
    await asked.giveBack({ event: "bad_answer", ...asked.usage });
    return fail(502, "bad_answer");
  }

  const read = cleanRead(answer, request);
  deps.log({
    event: "answered",
    model: deps.model,
    ms: asked.ms,
    payment: read.payment,
    ...asked.usage,
  });
  return Response.json({ read, model: deps.model, callsLeftToday: asked.left });
}

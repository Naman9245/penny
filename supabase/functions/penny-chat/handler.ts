// One chat message from the app: check it, ask Gemini within the daily
// limit, clean Penny's reply.
import { askGemini, type Deps } from "../_shared/ask.ts";
import { fail, readBody } from "../_shared/http.ts";
import { parseWith } from "../_shared/month.ts";
import { chatBody, ChatRequest, cleanReply, MAX_CHAT_BYTES } from "./chat.ts";

export type { Deps };

export async function chatWithPenny(
  req: Request,
  userId: string,
  deps: Deps,
): Promise<Response> {
  if (req.method !== "POST") return fail(405, "method_not_allowed");
  if (!deps.configured) return fail(503, "not_configured");

  const text = await readBody(req, MAX_CHAT_BYTES);
  if (text == null) return fail(413, "too_large");
  const request = parseWith(ChatRequest, text);
  if (request == null) return fail(400, "bad_request");

  // A reply cut short by the token limit is still worth showing.
  const asked = await askGemini(
    userId,
    deps,
    chatBody(request, deps.model),
    { allowCut: true },
  );
  if (!asked.ok) return asked.reply;

  const reply = cleanReply(asked.text);
  if (reply.length === 0) {
    await asked.giveBack({ event: "empty_reply", ...asked.usage });
    return fail(502, "bad_answer");
  }

  deps.log({
    event: "answered",
    model: deps.model,
    ms: asked.ms,
    messages: request.messages.length,
    ...asked.usage,
  });
  return Response.json({
    reply,
    model: deps.model,
    callsLeftToday: asked.left,
  });
}

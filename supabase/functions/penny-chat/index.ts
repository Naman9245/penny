// penny-chat: talk to Penny about your money, through Gemini.
//
// Secrets (Edge Functions → Secrets in the dashboard):
//   GEMINI_API_KEY     required; never in the app or the repo
//   CHAT_MODEL         default GEMINI_MODEL, then gemini-3.5-flash-lite
//   CHAT_USER_LIMIT    messages per user per day, default 30
//   CHAT_TOTAL_LIMIT   messages per day for everyone together, default 200
import { withSupabase } from "npm:@supabase/server@1.9.2";
import { geminiFetcher } from "../_shared/gemini.ts";
import { limitFrom } from "../_shared/http.ts";
import { quota } from "../_shared/quota.ts";
import { chatWithPenny } from "./handler.ts";

const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
const model = Deno.env.get("CHAT_MODEL") || Deno.env.get("GEMINI_MODEL") ||
  "gemini-3.5-flash-lite";
const userLimit = limitFrom("CHAT_USER_LIMIT", 30);
const totalLimit = limitFrom("CHAT_TOTAL_LIMIT", 200);
const callGemini = geminiFetcher(geminiKey, 40_000);

Deno.serve(
  withSupabase({ auth: "user", cors: false }, async (req, ctx) => {
    const userId = ctx.userClaims?.id;
    if (!userId) return Response.json({ error: "signed_out" }, { status: 401 });
    const admin = ctx.supabaseAdmin;
    return await chatWithPenny(req, userId, {
      configured: geminiKey.length > 0,
      model,
      userLimit,
      ...quota(
        (fn, args) => admin.rpc(fn, args),
        "chat",
        userLimit,
        totalLimit,
      ),
      callGemini,
      log: (event) =>
        console.log(JSON.stringify({ fn: "penny-chat", ...event })),
    });
  }),
);

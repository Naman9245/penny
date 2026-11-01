// analyze-month: Penny's look at one month of spending, from Gemini.
//
// Secrets (Edge Functions → Secrets in the dashboard):
//   GEMINI_API_KEY     required; never in the app or the repo
//   GEMINI_MODEL       default gemini-3.5-flash-lite, the fastest
//   DAILY_USER_LIMIT   calls per user per day, default 10
//   DAILY_TOTAL_LIMIT  calls per day for everyone together, default 50
import { withSupabase } from "npm:@supabase/server@1.9.2";
import { analyzeMonth } from "./handler.ts";

const GEMINI = "https://generativelanguage.googleapis.com/v1beta/models";
const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
const model = Deno.env.get("GEMINI_MODEL") || "gemini-3.5-flash-lite";
const userLimit = limitFrom("DAILY_USER_LIMIT", 10);
const totalLimit = limitFrom("DAILY_TOTAL_LIMIT", 50);

Deno.serve(
  withSupabase({ auth: "user", cors: false }, async (req, ctx) => {
    const userId = ctx.userClaims?.id;
    if (!userId) return Response.json({ error: "signed_out" }, { status: 401 });
    const admin = ctx.supabaseAdmin;
    return await analyzeMonth(req, userId, {
      configured: geminiKey.length > 0,
      model,
      userLimit,
      async takeCall(id) {
        const { data, error } = await admin.rpc("take_ai_call", {
          p_user_id: id,
          p_user_limit: userLimit,
          p_total_limit: totalLimit,
        });
        if (error) throw new Error(error.message);
        return data as number;
      },
      async refundCall(id) {
        const { error } = await admin.rpc("refund_ai_call", { p_user_id: id });
        if (error) throw new Error(error.message);
      },
      callGemini: (name, body) =>
        fetch(`${GEMINI}/${name}:generateContent`, {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-goog-api-key": geminiKey,
          },
          body: JSON.stringify(body),
          // Free-tier answers can queue for a while; well within the
          // platform's 150 s limit.
          signal: AbortSignal.timeout(50_000),
        }),
      log: (event) =>
        console.log(JSON.stringify({ fn: "analyze-month", ...event })),
    });
  }),
);

function limitFrom(name: string, fallback: number): number {
  const value = Number(Deno.env.get(name));
  return Number.isInteger(value) && value > 0 ? value : fallback;
}

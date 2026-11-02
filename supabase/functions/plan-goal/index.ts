// plan-goal: Penny's plan for reaching one savings goal, from Gemini.
//
// Secrets (Edge Functions → Secrets in the dashboard):
//   GEMINI_API_KEY     required; never in the app or the repo
//   PLAN_MODEL         default GEMINI_MODEL, then gemini-3.5-flash-lite
//   PLAN_USER_LIMIT    plans per user per day, default 10
//   PLAN_TOTAL_LIMIT   plans per day for everyone together, default 50
import { withSupabase } from "npm:@supabase/server@1.9.2";
import { geminiFetcher } from "../_shared/gemini.ts";
import { limitFrom } from "../_shared/http.ts";
import { quota } from "../_shared/quota.ts";
import { planGoal } from "./handler.ts";

const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
const model = Deno.env.get("PLAN_MODEL") || Deno.env.get("GEMINI_MODEL") ||
  "gemini-3.5-flash-lite";
const userLimit = limitFrom("PLAN_USER_LIMIT", 10);
const totalLimit = limitFrom("PLAN_TOTAL_LIMIT", 50);
// Free-tier answers can queue for a while; well within the platform's 150 s.
const callGemini = geminiFetcher(geminiKey, 50_000);

Deno.serve(
  withSupabase({ auth: "user", cors: false }, async (req, ctx) => {
    const userId = ctx.userClaims?.id;
    if (!userId) return Response.json({ error: "signed_out" }, { status: 401 });
    const admin = ctx.supabaseAdmin;
    return await planGoal(req, userId, {
      configured: geminiKey.length > 0,
      model,
      userLimit,
      ...quota(
        (fn, args) => admin.rpc(fn, args),
        "plan",
        userLimit,
        totalLimit,
      ),
      callGemini,
      log: (event) =>
        console.log(JSON.stringify({ fn: "plan-goal", ...event })),
    });
  }),
);

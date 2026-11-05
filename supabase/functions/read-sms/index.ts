// read-sms: reads one notification that the phone's own rules couldn't,
// with Gemini. Names, shops and places arrive already hidden as tags.
//
// Secrets (Edge Functions → Secrets in the dashboard):
//   GEMINI_API_KEY     required; never in the app or the repo
//   READ_MODEL         default GEMINI_MODEL, then gemini-3.5-flash-lite
//   READ_USER_LIMIT    notifications read per user per day, default 30
//   READ_TOTAL_LIMIT   notifications read per day for everyone, default 300
import { withSupabase } from "npm:@supabase/server@1.9.2";
import { geminiFetcher } from "../_shared/gemini.ts";
import { limitFrom } from "../_shared/http.ts";
import { quota } from "../_shared/quota.ts";
import { readSms } from "./handler.ts";

const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
const model = Deno.env.get("READ_MODEL") || Deno.env.get("GEMINI_MODEL") ||
  "gemini-3.5-flash-lite";
const userLimit = limitFrom("READ_USER_LIMIT", 30);
const totalLimit = limitFrom("READ_TOTAL_LIMIT", 300);
// A notification is short: an answer that takes longer isn't worth waiting
// for, and the phone tries again later.
const callGemini = geminiFetcher(geminiKey, 20_000);

Deno.serve(
  withSupabase({ auth: "user", cors: false }, async (req, ctx) => {
    const userId = ctx.userClaims?.id;
    if (!userId) return Response.json({ error: "signed_out" }, { status: 401 });
    const admin = ctx.supabaseAdmin;
    return await readSms(req, userId, {
      configured: geminiKey.length > 0,
      model,
      userLimit,
      ...quota(
        (fn, args) => admin.rpc(fn, args),
        "read",
        userLimit,
        totalLimit,
      ),
      callGemini,
      log: (event) => console.log(JSON.stringify({ fn: "read-sms", ...event })),
    });
  }),
);

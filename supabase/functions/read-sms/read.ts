// One notification the phone's rules couldn't read, as the app sends it:
// every word Penny doesn't know as a money word swapped for a tag like
// [w3], so names of people, shops and places stay on the phone, and long
// numbers as •••. Gemini says whether money moved, how much and which way.
import { z } from "npm:zod@4.6.7";
import { thinkingFor } from "../_shared/gemini.ts";
import { INCOME_IDS, INVEST_IDS, SPEND_IDS } from "../_shared/month.ts";

export const MAX_READ_BYTES = 4 * 1024;

/** The most a payment read this way can be: ₹1 crore. */
const MAX_RUPEES = 10_000_000;

export const ReadRequest = z.strictObject({
  v: z.literal(1),
  /** From the SMS app, or a payment, wallet or investing app. */
  from: z.enum(["sms", "app"]),
  text: z.string().trim().min(1).max(600),
});
export type ReadRequest = z.infer<typeof ReadRequest>;

export const KINDS = ["spend", "income", "invest", "own", "none"] as const;

export const READ_PROMPT = `
You read one notification from a phone in India: an SMS from a bank, a
wallet, a card or an investment, or a payment app's notice. Words that could
name a person, a shop or a place are hidden as tags like [w1]. Long numbers
are hidden as •••.

Say whether money actually moved, and how ("kind"):
- "spend": they paid for something, or sent money to someone.
- "income": money came to them.
- "invest": money went into a mutual fund or SIP, stocks or a broker, or a
  fixed or recurring deposit, PPF or NPS, even when it doesn't say
  "invested".
- "own": money moved between their own accounts, wallets or UPI Lite, or a
  credit card bill was paid.
- "none": no money moved: an OTP, an offer or ad, a request for money, a
  reminder of a payment to come, a failed payment, only a balance, or
  anything else.

"amount": the rupees that moved, exactly as the message writes them; never a
balance or a limit. 0 when none moved.
"payee": the words of the message that name who was paid, or who paid them,
tags included, like "[w2] [w3]". "" when it doesn't say.
"category": the one that fits best for its kind, or "none" when unsure.
`.trim();

export const READ_SCHEMA = {
  type: "object",
  properties: {
    kind: { type: "string", enum: [...KINDS] },
    amount: { type: "number", minimum: 0 },
    payee: { type: "string" },
    category: {
      type: "string",
      enum: [...SPEND_IDS, ...INVEST_IDS, ...INCOME_IDS, "none"],
    },
  },
  required: ["kind", "amount", "payee", "category"],
};

/** The generateContent request body for [model]. Only the text is sent. */
export function geminiBody(request: ReadRequest, model: string) {
  return {
    systemInstruction: { parts: [{ text: READ_PROMPT }] },
    contents: [
      {
        role: "user",
        parts: [{
          text: JSON.stringify({ from: request.from, text: request.text }),
        }],
      },
    ],
    generationConfig: {
      responseMimeType: "application/json",
      responseJsonSchema: READ_SCHEMA,
      maxOutputTokens: 256,
      ...thinkingFor(model),
    },
  };
}

// Loose on purpose: anything odd is dropped while cleaning, not rejected.
const RawRead = z.object({
  kind: z.string(),
  amount: z.number(),
  payee: z.string(),
  category: z.string(),
});
type RawRead = z.infer<typeof RawRead>;

/** Gemini's answer as JSON, or null when it isn't the expected shape. */
export function parseRead(text: string): RawRead | null {
  try {
    const parsed = RawRead.safeParse(JSON.parse(text));
    return parsed.success ? parsed.data : null;
  } catch {
    return null;
  }
}

export type Read =
  | {
    payment: true;
    type: "debit" | "credit";
    amountPaise: number;
    /** A category of the kind's own list, or null. */
    category: string | null;
    /** Words of the message, tags included, or null. */
    payee: string | null;
    investing: boolean;
  }
  | { payment: false; why: "own" | "none" };

const words = (text: string) =>
  text.toLowerCase().match(/\[w\d{1,3}\]|[\p{L}\p{N}]+/gu) ?? [];

/**
 * [raw] made safe to act on: a payment only with a plausible amount, a
 * category only from its kind's list, and a payee only of words the message
 * has.
 */
export function cleanRead(raw: RawRead, request: ReadRequest): Read {
  const kind = (KINDS as readonly string[]).includes(raw.kind)
    ? raw.kind as (typeof KINDS)[number]
    : "none";
  if (kind === "own") return { payment: false, why: "own" };
  if (kind === "none") return { payment: false, why: "none" };

  const paise = Math.round(raw.amount * 100);
  if (
    !Number.isFinite(raw.amount) || paise <= 0 || raw.amount > MAX_RUPEES ||
    Math.abs(raw.amount * 100 - paise) > 1e-6
  ) {
    return { payment: false, why: "none" };
  }

  const ids: readonly string[] = kind === "spend"
    ? SPEND_IDS
    : kind === "income"
    ? INCOME_IDS
    : INVEST_IDS;
  const category = ids.includes(raw.category)
    ? raw.category
    : kind === "invest"
    ? "invest"
    : null;

  const known = new Set(words(request.text));
  const payeeWords = words(raw.payee);
  const payee = raw.payee.trim().length > 0 && raw.payee.length <= 80 &&
      payeeWords.length > 0 && payeeWords.every((w) => known.has(w))
    ? raw.payee.trim()
    : null;

  return {
    payment: true,
    type: kind === "income" ? "credit" : "debit",
    amountPaise: paise,
    category,
    payee,
    investing: kind === "invest",
  };
}

// The month as the app sends it, and as Gemini gets to see it. Both the
// report and the chat use these.
import { z } from "npm:zod@4.6.7";

// Must match lib/models/category.dart in the app.
const SPEND_IDS = [
  "food",
  "groceries",
  "travel",
  "shopping",
  "bills",
  "rent",
  "subscriptions",
  "fun",
  "health",
  "education",
  "other",
] as const;
const INCOME_IDS = [
  "pocket_money",
  "salary",
  "freelance",
  "refund",
  "other_income",
] as const;

const LABELS: Record<string, string> = {
  food: "Food",
  groceries: "Groceries",
  travel: "Travel",
  shopping: "Shopping",
  bills: "Bills & recharge",
  rent: "Rent & PG",
  subscriptions: "Subscriptions",
  fun: "Fun",
  health: "Health",
  education: "Education",
  other: "Other",
  pocket_money: "Pocket money",
  salary: "Salary/stipend",
  freelance: "Freelance",
  refund: "Refund/cashback",
  other_income: "Other income",
};

export const TAGS = ["necessary", "wasteful"] as const;
export type Tag = (typeof TAGS)[number];

// Whole rupees; no one spends a hundred crore in a month.
const rupees = z.int().min(0).max(1_000_000_000);

const SpendGroup = z.strictObject({
  id: z.string().regex(/^s\d{1,2}$/),
  name: z.string().max(64).nullable(),
  person: z.boolean(),
  category: z.enum(SPEND_IDS),
  entries: z.int().min(1).max(100_000),
  total: rupees,
  biggest: rupees,
  lastMonth: rupees,
  monthsSeen: z.int().min(0).max(3),
  yourTag: z.enum(TAGS).nullable(),
});

const IncomeGroup = z.strictObject({
  id: z.string().regex(/^i\d{1,2}$/),
  category: z.enum(INCOME_IDS),
  entries: z.int().min(1).max(100_000),
  total: rupees,
  monthsWithIncome: z.int().min(0).max(6),
  monthsTracked: z.int().min(1).max(6),
  steadiness: z.enum(["steady", "most_months", "now_and_then", "too_early"]),
});

export const MonthRequest = z
  .strictObject({
    v: z.literal(1),
    month: z.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/),
    monthComplete: z.boolean(),
    daysCounted: z.int().min(1).max(31),
    spent: rupees,
    got: rupees,
    lastMonth: z.strictObject({ spent: rupees, got: rupees }),
    // Empty is fine for a chat early in a month; the report needs spends.
    spends: z.array(SpendGroup).max(40),
    income: z.array(IncomeGroup).max(10),
    /** What the person wrote about themselves on My needs. */
    note: z.string().max(240).optional(),
  })
  // Zod runs this even when the fields above failed, so it can't trust them.
  .refine((r) => {
    const groups: unknown[] = [
      ...(Array.isArray(r.spends) ? r.spends : []),
      ...(Array.isArray(r.income) ? r.income : []),
    ];
    const ids = groups.map((group) => (group as { id?: unknown })?.id);
    return new Set(ids).size === ids.length;
  }, "group ids must be unique");

export type MonthRequest = z.infer<typeof MonthRequest>;

/** [text] as JSON matching [schema], or null when it doesn't. */
export function parseWith<T>(schema: z.ZodType<T>, text: string): T | null {
  let json: unknown;
  try {
    json = JSON.parse(text);
  } catch {
    return null;
  }
  const parsed = schema.safeParse(json);
  return parsed.success ? parsed.data : null;
}

/**
 * A shop name with nothing but letters and simple punctuation, so phone
 * numbers and reference numbers can't ride along. The app already does this;
 * the server doesn't rely on it.
 */
export function cleanShopName(raw: string | null): string | null {
  if (raw == null) return null;
  const name = raw
    .replace(/[^\p{L}\p{M} &.'-]/gu, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 32)
    .trim();
  return name.length > 0 ? name : null;
}

/**
 * [text] with every run of nine or more digits (phone, account and card
 * numbers), spaces or dashes allowed between them, replaced by •••. Amounts
 * written with commas, like 1,20,000, stay.
 */
export function maskLongNumbers(text: string): string {
  return text.replace(/\d(?:[\s-]?\d){8,}/g, "•••");
}

/** The month as Gemini sees it: labels instead of ids, people as aliases. */
export function modelInput(request: MonthRequest) {
  let people = 0;
  return {
    month: request.month,
    monthComplete: request.monthComplete,
    daysCounted: request.daysCounted,
    spent: request.spent,
    got: request.got,
    lastMonth: request.lastMonth,
    spends: request.spends.map((g) => ({
      id: g.id,
      // The server names people itself, whatever the app sent.
      name: g.person ? `Person ${++people}` : cleanShopName(g.name),
      isPerson: g.person,
      category: LABELS[g.category],
      entries: g.entries,
      total: g.total,
      biggest: g.biggest,
      lastMonth: g.lastMonth,
      monthsSeen: g.monthsSeen,
      yourTag: g.yourTag,
    })),
    income: request.income.map((g) => ({
      id: g.id,
      category: LABELS[g.category],
      entries: g.entries,
      total: g.total,
      monthsWithIncome: g.monthsWithIncome,
      monthsTracked: g.monthsTracked,
      steadiness: g.steadiness,
    })),
    ...(request.note?.trim()
      ? { note: maskLongNumbers(request.note.trim()) }
      : {}),
  };
}

/**
 * Plain text of at most [max] characters. Sentences with a digit are
 * dropped: every number on the report is computed by the app.
 */
export function cleanText(text: string, max: number): string {
  const plain = text.replace(/[*`#>]/g, "").replace(/\s+/g, " ").trim();
  const kept = plain
    .split(/(?<=[.!?])\s+/)
    .filter((sentence) => sentence.length > 0 && !/\d/.test(sentence))
    .join(" ");
  return cutAtWord(kept, max);
}

/** [text] cut to at most [max] characters at a word, with an ellipsis. */
export function cutAtWord(text: string, max: number): string {
  if (text.length <= max) return text;
  const cut = text.slice(0, max - 1);
  const space = cut.lastIndexOf(" ");
  return (space > max / 2 ? cut.slice(0, space) : cut)
    .replace(/[\s,;:.-]+$/, "") + "…";
}

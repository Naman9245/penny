// Made-up months for the tests. No real names or amounts.

// Loose JSON shapes, so tests can bend them into requests the app never sends.
interface SpendJson {
  id: string;
  name: string | null;
  person: boolean;
  category: string;
  entries: number;
  total: number;
  biggest: number;
  lastMonth: number;
  monthsSeen: number;
  yourTag: string | null;
}

interface IncomeJson {
  id: string;
  category: string;
  entries: number;
  total: number;
  monthsWithIncome: number;
  monthsTracked: number;
  steadiness: string;
}

export interface RequestJson {
  v: number;
  month: string;
  monthComplete: boolean;
  daysCounted: number;
  spent: number;
  got: number;
  lastMonth: { spent: number; got: number };
  spends: SpendJson[];
  income: IncomeJson[];
}

export interface AnswerJson {
  tags: { id: string; tag: string }[];
  habits: { title: string; groups: string[]; cut: string; tip: string }[];
  summary: string;
  incomeNote: string;
}

export function sampleRequest(): RequestJson {
  return {
    v: 1,
    month: "2026-10",
    monthComplete: true,
    daysCounted: 31,
    spent: 9480,
    got: 15000,
    lastMonth: { spent: 8200, got: 15000 },
    spends: [
      {
        id: "s1",
        name: "Swiggy",
        person: false,
        category: "food",
        entries: 12,
        total: 3480,
        biggest: 620,
        lastMonth: 2900,
        monthsSeen: 3,
        yourTag: null,
      },
      {
        id: "s2",
        // The app sends an alias; the server must not trust that it did.
        name: "Asha Rao",
        person: true,
        category: "other",
        entries: 2,
        total: 1500,
        biggest: 1000,
        lastMonth: 0,
        monthsSeen: 0,
        yourTag: null,
      },
      {
        id: "s3",
        name: "Netflix",
        person: false,
        category: "subscriptions",
        entries: 1,
        total: 649,
        biggest: 649,
        lastMonth: 649,
        monthsSeen: 3,
        yourTag: null,
      },
      {
        id: "s4",
        name: null,
        person: false,
        category: "rent",
        entries: 1,
        total: 3851,
        biggest: 3851,
        lastMonth: 3851,
        monthsSeen: 3,
        yourTag: "necessary",
      },
    ],
    income: [
      {
        id: "i1",
        category: "pocket_money",
        entries: 1,
        total: 15000,
        monthsWithIncome: 6,
        monthsTracked: 6,
        steadiness: "steady",
      },
    ],
  };
}

export function sampleAnswer(): AnswerJson {
  return {
    tags: [
      { id: "s1", tag: "wasteful" },
      { id: "s2", tag: "necessary" },
      { id: "s3", tag: "wasteful" },
      { id: "s4", tag: "wasteful" },
    ],
    habits: [
      {
        title: "Late-night delivery",
        groups: ["s1"],
        cut: "half",
        tip: "Cook at home on two weeknights. Keep Swiggy for Fridays.",
      },
      {
        title: "Streaming you skip",
        groups: ["s3"],
        cut: "stop",
        tip: "Pause the plan you opened least this month.",
      },
    ],
    summary: "A busy month with lots of delivery. You kept rent on track!",
    incomeNote: "Your pocket money arrives like clockwork.",
  };
}

/** A generateContent response carrying [answer]. */
export function geminiReply(answer: unknown, finishReason = "STOP") {
  return {
    candidates: [
      {
        content: { parts: [{ text: JSON.stringify(answer) }], role: "model" },
        finishReason,
      },
    ],
    usageMetadata: {
      promptTokenCount: 900,
      candidatesTokenCount: 300,
      thoughtsTokenCount: 120,
    },
  };
}

// A made-up report answer for the tests.

export interface AnswerJson {
  tags: { id: string; tag: string }[];
  habits: { title: string; groups: string[]; cut: string; tip: string }[];
  summary: string;
  incomeNote: string;
  earnIdeas?: string[];
  reasons?: { id: string; reason: string }[];
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
    earnIdeas: [
      "Tutor juniors in a subject you are good at.",
      "Sell your design skills on a freelancing site.",
    ],
  };
}

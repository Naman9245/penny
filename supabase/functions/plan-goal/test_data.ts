// A made-up goal plan request and answer for the tests.
import { type RequestJson, sampleRequest } from "../_shared/test_data.ts";

export interface PlanJson {
  v: number;
  month: RequestJson;
  tags: Record<string, string>;
  goal: Record<string, unknown>;
}

export function planJson(): PlanJson {
  return {
    v: 1,
    month: {
      ...sampleRequest(),
      budget: { everyday: 8000, caps: [{ category: "food", cap: 3000 }] },
    },
    tags: { s1: "wasteful", s2: "necessary", s4: "necessary" },
    goal: {
      title: "Delhi trip",
      target: 15000,
      saved: 3000,
      weeksLeft: 15,
      perWeek: 800,
      perMonth: 3500,
    },
  };
}

export interface PlanAnswerJson {
  cuts: { title: string; groups: string[]; cut: string; tip: string }[];
  summary: string;
}

export function samplePlan(): PlanAnswerJson {
  return {
    cuts: [
      {
        title: "Fewer delivery nights",
        groups: ["s1"],
        cut: "half",
        tip: "Cook at home on two weeknights.",
      },
      {
        title: "One streaming plan",
        groups: ["s3"],
        cut: "stop",
        tip: "Pause the plan you open least.",
      },
    ],
    summary: "Delhi is within reach! A few small swaps get you there.",
  };
}

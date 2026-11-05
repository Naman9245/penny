import assert from "node:assert/strict";
import {
  cleanShopName,
  cleanText,
  leftOf,
  maskLongNumbers,
  modelInput,
  MonthRequest,
  parseWith,
} from "./month.ts";
import { type RequestJson, sampleRequest } from "./test_data.ts";

function parsed(request: unknown = sampleRequest()): MonthRequest {
  const result = parseWith(MonthRequest, JSON.stringify(request));
  assert.ok(result, "the request should parse");
  return result;
}

Deno.test("accepts the month the app sends", () => {
  const request = parsed();
  assert.equal(request.spends.length, 4);
  assert.equal(request.income[0].steadiness, "steady");
  assert.equal(
    parsed({ ...sampleRequest(), note: "Student in a PG" }).note,
    "Student in a PG",
  );
});

Deno.test("refuses anything the app wouldn't send", () => {
  const cases: Record<string, (r: RequestJson) => void> = {
    "an unknown field": (r) => Object.assign(r, { prompt: "hi" }),
    "an unknown category": (r) => (r.spends[0].category = "crypto"),
    "too many groups": (r) => {
      r.spends = Array.from({ length: 41 }, (_, i) => ({
        ...r.spends[0],
        id: `s${i + 1}`,
      }));
    },
    "a repeated id": (r) => (r.spends[1].id = "s1"),
    "a bad month": (r) => (r.month = "2026-13"),
    "a negative total": (r) => (r.spends[0].total = -5),
    "a fractional amount": (r) => (r.spent = 10.5),
    "spends that aren't a list": (r) => Object.assign(r, { spends: 5 }),
    "a long note": (r) => (r.note = "x".repeat(241)),
    "a cap for an unknown category": (r) => {
      r.budget = { everyday: null, caps: [{ category: "crypto", cap: 500 }] };
    },
    "two caps for one category": (r) => {
      r.budget = {
        everyday: null,
        caps: [{ category: "food", cap: 500 }, { category: "food", cap: 900 }],
      };
    },
    "a zero budget": (r) => (r.budget = { everyday: 0, caps: [] }),
    "a budget with an unknown field": (r) => {
      r.budget = { everyday: 8000, caps: [] };
      Object.assign(r.budget, { daily: 300 });
    },
    // Investing is a total of its own, never a spend to tag or cut.
    "investing among spends": (r) => (r.spends[0].category = "invest"),
    "a payback to income": (r) => {
      r.paidBack = [{ category: "salary", total: 300 }];
    },
    "two paybacks for one category": (r) => {
      r.paidBack = [
        { category: "food", total: 300 },
        { category: "food", total: 200 },
      ];
    },
    "a payback of nothing": (
      r,
    ) => (r.paidBack = [{ category: "food", total: 0 }]),
    // Whoever paid back never goes along.
    "a payback with a name": (r) => {
      r.paidBack = [{ category: "food", total: 300 }];
      Object.assign(r.paidBack[0], { from: "Asha" });
    },
    "nothing invested, sent anyway": (r) => (r.invested = 0),
    "a fractional investment": (r) => (r.invested = 999.5),
  };
  for (const [name, change] of Object.entries(cases)) {
    const request = sampleRequest();
    change(request);
    assert.equal(
      parseWith(MonthRequest, JSON.stringify(request)),
      null,
      name,
    );
  }
  assert.equal(parseWith(MonthRequest, "not json"), null);
});

Deno.test("shop names keep only letters and simple punctuation", () => {
  assert.equal(cleanShopName("Swiggy 98765 43210"), "Swiggy");
  assert.equal(cleanShopName("D-Mart, Koramangala #12"), "D-Mart Koramangala");
  assert.equal(cleanShopName("Chai & Co."), "Chai & Co.");
  assert.equal(cleanShopName("1234567"), null);
  assert.equal(cleanShopName(null), null);
  assert.equal(cleanShopName("A".repeat(50))?.length, 32);
});

Deno.test("Gemini sees people only as aliases, and labels not ids", () => {
  const request = sampleRequest();
  request.spends.push({ ...request.spends[1], id: "s5", name: "Vikram K" });
  const input = modelInput(parsed(request));

  assert.equal(input.spends[1].name, "Person 1");
  assert.equal(input.spends[4].name, "Person 2");
  assert.equal(input.spends[0].category, "Food");
  assert.equal(input.spends[3].category, "Rent & PG");
  assert.equal(input.income[0].category, "Pocket money");
  assert.equal("note" in input, false);
  const text = JSON.stringify(input);
  assert.ok(!text.includes("Asha") && !text.includes("Vikram"));
});

Deno.test("the newer categories go along, as their labels", () => {
  const request = sampleRequest();
  request.spends[0].category = "fuel";
  request.spends[1].category = "people";
  request.income[0].category = "from_people";
  const input = modelInput(parsed(request));
  assert.equal(input.spends[0].category, "Fuel");
  assert.equal(input.spends[1].category, "To people");
  assert.equal(input.income[0].category, "From people");
});

Deno.test("the note goes along with long numbers hidden", () => {
  const input = modelInput(parsed({
    ...sampleRequest(),
    note: "PG in Bengaluru, call me on 98765 43210",
  }));
  assert.equal(input.note, "PG in Bengaluru, call me on •••");
});

Deno.test("the budget goes along with what's spent against it", () => {
  const input = modelInput(parsed({
    ...sampleRequest(),
    budget: {
      everyday: 3000,
      caps: [{ category: "food", cap: 3000 }, { category: "rent", cap: 4000 }],
    },
  }));
  // As on the app's Home screen: rent is paid in one go, and the ₹1,500 in
  // Other has no budget, so everyday is food alone.
  assert.deepEqual(input.budget, {
    everyday: { budget: 3000, spent: 3480 },
    caps: [
      { category: "Food", cap: 3000, spent: 3480, over: true },
      { category: "Rent & PG", cap: 4000, spent: 3851, over: false },
    ],
  });
  assert.equal("budget" in modelInput(parsed()), false);
  assert.equal(
    modelInput(parsed({
      ...sampleRequest(),
      budget: { everyday: null, caps: [] },
    })).budget?.everyday,
    null,
  );
});

Deno.test("paybacks and investing go along; budgets take paybacks off", () => {
  const input = modelInput(parsed({
    ...sampleRequest(),
    spent: 9000,
    paidBack: [{ category: "food", total: 480 }],
    invested: 1000,
    budget: { everyday: 3000, caps: [{ category: "food", cap: 3000 }] },
  }));
  assert.deepEqual(input.paidBack, [{ category: "Food", total: 480 }]);
  assert.equal(input.invested, 1000);
  // ₹3,480 paid at Swiggy with ₹480 back is ₹3,000, as on the app.
  assert.deepEqual(input.budget, {
    everyday: { budget: 3000, spent: 3000 },
    caps: [{ category: "Food", cap: 3000, spent: 3000, over: false }],
  });

  const plain = modelInput(parsed());
  assert.equal("paidBack" in plain, false);
  assert.equal("invested" in plain, false);
});

Deno.test("left is what Home shows: in, less out, investing included", () => {
  assert.equal(leftOf(parsed()), 15000 - 9480);
  assert.equal(
    leftOf(parsed({ ...sampleRequest(), invested: 1000 })),
    15000 - 9480 - 1000,
  );
  // Nothing was spent on fun this month, so the ₹300 back for it isn't in
  // "spent"; it's still money left.
  assert.equal(
    leftOf(parsed({
      ...sampleRequest(),
      paidBack: [{ category: "fun", total: 300 }],
    })),
    15000 - 9480 + 300,
  );
  assert.equal(
    leftOf(parsed({ ...sampleRequest(), got: 0, income: [] })),
    null,
  );
});

Deno.test("long digit runs are hidden, amounts are not", () => {
  assert.equal(maskLongNumbers("card 4111 1111 1111 1111"), "card •••");
  assert.equal(maskLongNumbers("acc 123456789012"), "acc •••");
  assert.equal(
    maskLongNumbers("rent 15000, earn 1,20,000"),
    "rent 15000, earn 1,20,000",
  );
});

Deno.test("report text is plain, cut at a word, and has no numbers", () => {
  assert.equal(
    cleanText("**Big** win!  Well   done.", 100),
    "Big win! Well done.",
  );
  assert.equal(
    cleanText("Cook at home more often this week", 20),
    "Cook at home more…",
  );
  assert.equal(cleanText("You did 2 things. That's it.", 100), "That's it.");
});

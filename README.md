# Penny

A money manager for Indian users, with Penny, a coin who reacts to how your month is going. Built with Flutter.

**Status: Milestone 4 of 5.** Manual entry, bank SMS import, the Analysis tab, Penny's wasteful-spending report, My needs, the chat with Penny, the budget with Penny's moods, the mood calendar and goals with Penny's plans work. Penny's animations, sign-in and sync come next.

## What works now

- **Add in under 5 seconds**: type the amount on the keypad, pick a category, tap ✓. Undo is one tap away.
- **Bank SMS import**: share an SMS from Messages to Penny, or paste one. It's read on the phone: numbers are masked, OTPs and look-alikes (payment requests, reminders, offers) are refused with a reason, and the SMS itself is never saved.
- **Analysis**: spent and got, a card per category, the necessary-vs-wasteful split, and the last six months as a chart.
- **Wasteful report** (Gemini): Penny sorts the month's spends into necessary and wasteful, picks habits worth cutting with a tip each, and the app works out what cutting them would have saved. "I need this" moves a habit back to necessary, and you can change any entry's tag yourself. The report ends with a few ideas for earning a little extra.
- **My needs**: mark each category and each shop you've paid as Need, Penny (she decides) or Wasteful, and leave Penny a short note about your life. An entry's own tag beats your shop rule, which beats your category rule, which beats Penny's pick. The split updates at once.
- **Talk to Penny** (Gemini): tap Penny on Home and ask her how to save, in English, Hindi or Hinglish. She knows this month's totals, your My needs, your note, your budget and your goals.
- **Budget and Penny's moods**: one monthly budget for everyday spending (everything but rent, bills, subscriptions and education, which are paid in one go) and optional caps per category. Penny is happy under the budget's pace, worried at 85% of a limit, sad over one, and celebrating when a goal is reached. Analysis cards show their caps.
- **Mood calendar**: every day coloured by that day's everyday spending against its share of the budget: mint at or under it, yellow up to 1.5 times, pink above, sky blue when a goal was reached. Tap a day for its entries.
- **Goals** (Gemini plans): save for something by a date, with what's needed each week. Note money in and out; reaching the target sets Penny celebrating. Plan with Penny picks up to four cuts from last month's spending, and the phone works out what each saves a month against what the goal needs.
- **Offline-first**: everything lives on the phone in SQLite (Drift). Amounts are integer paise, never floating point. Rows carry UUIDv7 ids, timestamps and soft deletes, ready for sync.

## Privacy

- Penny calls the AI when you tap Ask Penny, Refresh or Plan with Penny, when you send her a chat message, and by herself when you open a report for a month she has looked at before whose entries, note or budget have changed since.
- She sends one month as totals per shop, plus your note and budget: never single entries, SMS text, account numbers, or the names of people you pay (they go as "Person 1, 2"). A plan also sends that goal, and the chat your goals and messages; the server masks any run of 9 or more digits in messages, the note and goal titles. "See what Penny sends" lists exactly what goes out.
- Gemini sorts, picks and explains; every rupee in the report and in a plan is computed on the phone, and the server drops any sentence from Gemini that contains a number. In the chat Penny may use numbers from your month, saying "about" for estimates.
- On Gemini's free tier, Google may use what's sent to improve its products. The chat screen says so.
- The Gemini key lives only in Supabase's secrets. The server keeps nothing but a count of calls per day, and its logs hold timings and token counts, never messages. Reports and the chat are stored on the phone; Clear chat deletes it.

## Stack

Flutter · Riverpod · go_router · Drift (SQLite) · flutter_animate · fl_chart · Supabase (anonymous auth, Edge Functions in Deno and TypeScript) · Gemini with schema-bound JSON output.

## Run it

```bash
flutter pub get
dart run build_runner build -d
flutter run --dart-define-from-file=env/supabase.json
```

`env/supabase.json` holds your Supabase project's URL and publishable key (copy `env/supabase.example.json`). Without it the app runs fully offline and the report says the AI isn't set up.

## Backend

`supabase/` holds the server side:

- `migrations/`: the `ai_usage` table and the functions behind the daily limits, counted apart for reports, chat and plans.
- `functions/_shared/`: what the functions share: the month's schema with the budget, masking, the Gemini call and the limits.
- `functions/analyze-month/`: the report. It checks the request, counts the call, asks Gemini for JSON in a fixed schema, and cleans the answer before returning it.
- `functions/penny-chat/`: the chat. It checks the month, the goals and the last 12 messages, masks long digit runs, and returns Penny's reply as plain text.
- `functions/plan-goal/`: a goal's plan. It checks the month and the goal, asks Gemini for up to four cuts in a fixed schema, and drops any that touch a need.

To use your own project: create one, apply the migrations, deploy the three functions (`supabase functions deploy analyze-month`, `penny-chat` and `plan-goal`), turn on anonymous sign-ins, and add the secret `GEMINI_API_KEY`. Optional secrets: `GEMINI_MODEL` (default `gemini-3.5-flash-lite`, the fastest), `CHAT_MODEL` and `PLAN_MODEL` (if different), `DAILY_USER_LIMIT` (10 reports) and `DAILY_TOTAL_LIMIT` (50), `CHAT_USER_LIMIT` (30 messages) and `CHAT_TOTAL_LIMIT` (200), `PLAN_USER_LIMIT` (10 plans) and `PLAN_TOTAL_LIMIT` (50).

## Test

```bash
flutter analyze
flutter test
cd supabase/functions && deno test
```

## Layout

```
lib/
  core/       theme tokens and type, router, config, money and date helpers
  data/       Drift database, repositories, Riverpod providers
  models/     enums, categories, Penny's moods, the budget, the report and plans
  services/   SMS parser, share inbox, what Penny sends, report, budget, goal
              and plan maths, AI client
  features/   home, add_txn, import, transactions, analysis, report, needs,
              chat, budget, goals, calendar
  widgets/    brutal card/button/chip/pill, keypad, pill nav bar, split bar,
              Penny
supabase/     migrations, and the analyze-month, penny-chat and plan-goal Edge
              Functions
```

## Roadmap

1. ✅ Setup, theme, local database, manual entry, transaction list
2. ✅ Paste or share a bank SMS, parsed on the phone; analysis charts
3. ✅ Gemini through Supabase Edge Functions: wasteful-spending report, My needs, a chat with Penny
4. ✅ Budgets, goal planner, Penny's moods, mood calendar
5. Penny's animations, sign-in and sync

Baloo 2 and DM Sans are bundled under the SIL Open Font License.

# Penny

A money manager for Indian users, with Penny, a coin who reacts to how your month is going. Built with Flutter.

**Status: Milestone 3 of 5.** Manual entry, bank SMS import, the Analysis tab and Penny's wasteful-spending report work. Budgets, goals and the mood calendar come next.

## What works now

- **Add in under 5 seconds**: type the amount on the keypad, pick a category, tap ✓. Undo is one tap away.
- **Bank SMS import**: share an SMS from Messages to Penny, or paste one. It's read on the phone: numbers are masked, OTPs and look-alikes (payment requests, reminders, offers) are refused with a reason, and the SMS itself is never saved.
- **Analysis**: spent and got, a card per category, the necessary-vs-wasteful split, and the last six months as a chart.
- **Wasteful report** (Gemini): Penny sorts the month's spends into necessary and wasteful, picks habits worth cutting with a tip each, and the app works out what cutting them would have saved. "I need this" moves a habit back to necessary, and you can change any entry's tag yourself.
- **Offline-first**: everything lives on the phone in SQLite (Drift). Amounts are integer paise, never floating point. Rows carry UUIDv7 ids, timestamps and soft deletes, ready for sync.

## Privacy

- Penny only calls the AI when you tap Ask Penny or Refresh.
- She sends one month as totals per shop: never single entries, SMS text, account numbers, or the names of people you pay (they go as "Person 1, 2"). "See what Penny sends" lists exactly what goes out.
- Gemini sorts and explains; every rupee on screen is computed on the phone. The server drops any sentence from Gemini that contains a number.
- The Gemini key lives only in Supabase's secrets. The server keeps nothing but a count of calls per day; reports are stored on the phone.

## Stack

Flutter · Riverpod · go_router · Drift (SQLite) · flutter_animate · fl_chart · Supabase (anonymous auth, an Edge Function in Deno and TypeScript) · Gemini with schema-bound JSON output.

## Run it

```bash
flutter pub get
dart run build_runner build -d
flutter run --dart-define-from-file=env/supabase.json
```

`env/supabase.json` holds your Supabase project's URL and publishable key (copy `env/supabase.example.json`). Without it the app runs fully offline and the report says the AI isn't set up.

## Backend

`supabase/` holds the server side:

- `migrations/`: the `ai_usage` table and the functions behind the daily limits.
- `functions/analyze-month/`: the Edge Function. It checks the request, counts the call, asks Gemini for JSON in a fixed schema, and cleans the answer before returning it.

To use your own project: create one, apply the migration, deploy the function (`supabase functions deploy analyze-month`), turn on anonymous sign-ins, and add the secret `GEMINI_API_KEY`. Optional secrets: `GEMINI_MODEL` (default `gemini-3.8-flash`), `DAILY_USER_LIMIT` (10) and `DAILY_TOTAL_LIMIT` (50).

## Test

```bash
flutter analyze
flutter test
cd supabase/functions/analyze-month && deno test
```

## Layout

```
lib/
  core/       theme tokens and type, router, config, money and date helpers
  data/       Drift database, repositories, Riverpod providers
  models/     enums, categories, Penny's moods, the report
  services/   SMS parser, share inbox, what Penny sends, report maths, AI client
  features/   home, add_txn, import, transactions, analysis, report
  widgets/    brutal card/button/chip, pill nav bar, split bar, Penny
supabase/     migration and the analyze-month Edge Function
```

## Roadmap

1. ✅ Setup, theme, local database, manual entry, transaction list
2. ✅ Paste or share a bank SMS, parsed on the phone; analysis charts
3. Gemini analysis through a Supabase Edge Function; wasteful-spending report
4. Budgets, goal planner, Penny's moods, mood calendar
5. Penny's animations, sign-in and sync

Baloo 2 and DM Sans are bundled under the SIL Open Font License.

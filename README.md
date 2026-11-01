# Penny

A money manager for Indian users, with Penny, a coin who reacts to how your month is going. Built with Flutter.

**Status: Milestone 1 of 5.** Manual entry, the transaction list, the neobrutalism design system and the local database work. SMS import, AI analysis, goals and the mood calendar come next.

## What works now

- **Add in under 5 seconds**: type the amount on the keypad, tap a category, done. Undo is one tap away.
- **Home**: Penny's mood; this month's spending, income and what's left; your latest entries.
- **Transactions**: month by month, grouped by day. Swipe to delete, tap to edit.
- **Offline-first**: everything lives on the phone in SQLite (Drift). Amounts are integer paise, never floating point. Rows carry UUIDv7 ids, timestamps and soft deletes, so cloud sync can be added without a migration.

## Stack

Flutter · Riverpod · go_router · Drift (SQLite) · flutter_animate. Later: Supabase for sign-in and sync, and an LLM behind a Supabase Edge Function so no API key ships in the app.

## Run it

```bash
flutter pub get
dart run build_runner build -d
flutter run
```

## Test

```bash
flutter analyze
flutter test
```

## Layout

```
lib/
  core/       theme tokens and type, router, money and date helpers
  data/       Drift database, repository, Riverpod providers
  models/     enums, categories, Penny's moods
  features/   home, add_txn, transactions, placeholder tabs
  widgets/    brutal card/button/chip, pill nav bar, Penny
```

## Roadmap

1. ✅ Setup, theme, local database, manual entry, transaction list
2. Paste or share a bank SMS, parsed on the phone; analysis charts
3. LLM analysis through a Supabase Edge Function; wasteful-spending report
4. Budgets, goal planner, Penny's moods, mood calendar
5. Penny's animations, sign-in and sync

Baloo 2 and DM Sans are bundled under the SIL Open Font License.

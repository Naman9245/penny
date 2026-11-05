# Penny

A money manager for Indian users, with Penny, a coin who reacts to how your month is going. An Android app built with Flutter.

**Status: seven milestones done.** Manual entry with bill splitting, usual entries and typing it in one go, bank SMS import, payments read from notifications, paybacks and investing, the Analysis tab, Penny's wasteful-spending report, My needs, the chat with Penny, the budget with Penny's moods and a forecast, the mood calendar, goals with Penny's plans, fixed bills each month, search, CSV export, Penny's animations, the welcome, and Google sign-in with backup and sync work. Receipt photos come later.

## What works now

- **Add in under 5 seconds**: type the amount on the keypad, pick a category, tap ✓. Undo is one tap away. The keypad adds and takes away like a calculator (3000 + 2500 − 200) wherever you type an amount.
- **Log faster**:
  - **Split it**: ÷2 ÷3 ÷4 above the keypad divide what you typed, to the paisa (₹1,000 ÷ 3 is ₹333.33), and "₹1,000 ÷ 3" shows until the amount changes.
  - **Again?**: up to four of the entries you log again and again (same category, place and amount, twice in the last 60 days) are a tap from filled in. ✓ still saves.
  - **Type it**: in Where, "240 Swiggy", "auto 45" or "Rs.20 Chai point" fill in the amount, place and category at once, guessed from the shops Penny knows and everyday words. This works while no amount is typed yet, so a place like "Sector 18" never changes one.
- **Paybacks**: when a friend pays you back their share, log it under Got → Paid back and say what it was for. It reads "Food · paid back", comes off that category's spending (never below zero) on Home, Analysis, the budget and Penny's mood, and isn't counted as income. A day keeps what you paid that day, and its sheet says what came back.
- **Investing**: three kinds of money put away, not spent: 📈 Mutual funds & SIP, 📊 Stocks & ETFs, and 🏦 FD, RD, PPF & NPS. Fund houses, Groww, Coin, Kuvera, INDmoney, NACH and BSE SIP debits, brokers like Zerodha and Upstox, and deposits are recognised, even when an SMS never says "invested". Investing stays out of Spent, the budget, the mood and necessary vs wasteful; Left takes it off with "₹1,000 invested" under it, and Analysis shows each kind under Put away.
- **Categories**: spending has Food, Groceries, Travel, Fuel, Shopping, Bills & recharge, Rent & PG, Home & upkeep, Subscriptions, EMIs & loans, Bank charges & fees, Fun, Health, Personal care, Education, Gifts & donations, Family, To people and Other; income has Pocket money, Salary/stipend, Freelance, Refund/cashback, Interest, Dividends, From people and Other.
- **Bank SMS import**: share an SMS from Messages to Penny, or paste one. It's read on the phone: numbers are masked, OTPs and look-alikes (payment requests, reminders, offers) are refused with a reason, and the SMS itself is never saved.
- **Payments read from notifications** (Android, opt-in): once you allow Penny on Android's Notification access page (Settings → Read payment notifications), it reads payments from your SMS app and from payment, wallet and investing apps (GPay, PhonePe, Paytm, PayZapp, MobiKwik, CRED, BHIM, super.money, Groww, Kite, Upstox, INDmoney and Paytm Money), with the same rules as a shared SMS. An SMS counts only when it's from a bank, a wallet or an investment: a sender code (with or without its prefix, like HDFCBK), a money brand's name (HDFC Bank, PayZapp), or a message naming an account, card or wallet; a friend's text never does. Loading a wallet or UPI Lite, sending to your own account, and a lender's receipt are left out, so nothing counts twice.
  - **Wait for me to check**: each waits on Home under "payments to check" (Add with Penny's guessed category, open it to change anything, or Skip). One that looks like an entry you have says so.
  - **Save straight away**: every payment is saved at once, with Undo. One Penny can't place goes in To people or From people for a person, else Other. The same payment seen twice (the bank's SMS and a payment app's notice within half an hour, or an investment's debit and the fund's confirmation within three days) is kept once; two payments of the same amount from one place are both saved; one like an entry you typed that day is saved, and Penny says it may repeat it.
  - **Penny's own notification** says what she read when she isn't on screen, like "Penny read −₹250 · Swiggy", and opens Home; on screen, a message at the bottom says it. With Penny closed, a hidden copy of her reads them. Settings → **What Penny read** lists the last 20 notifications she looked at and what she did with each, never the message. Entries read this way show "Auto".
  - **What the rules can't read**: a money SMS or notice that says money moved, but that Penny's rules can't read, goes to her AI with names and numbers hidden (see Privacy). When the AI can't answer, it waits on Home as one she couldn't read yet.
- **Export**: Settings → Export entries sends every entry as a CSV, through the share menu, that opens in Excel or Google Sheets.
- **Analysis**: spent and got, a card per category with what came back, the necessary-vs-wasteful split, what you put away, and the last six months as a chart.
- **Month routines**:
  - **Fixed bills**: in a month's first week, Home offers last month's rent, bills, subscriptions and education not logged yet. Log adds one today, with Undo; Skip hides it for the month.
  - **Forecast**: from the 3rd, Penny's box says where the month is heading at your everyday pace: what will be left of the everyday budget, the day it runs out, or about how much the month comes to without one. Worked out on the phone.
  - **Search**: find a place, a category or an amount on Transactions, with the Spent/Got and Category filters; anything narrowed down is added up ("3 entries · spent ₹730").
- **Wasteful report** (Gemini): Penny sorts the month's spends into necessary and wasteful, picks habits worth cutting with a tip each, and the app works out what cutting them would have saved. "I need this" moves a habit back to necessary, and you can change any entry's tag yourself. The report ends with a few ideas for earning a little extra.
- **My needs**: mark each category and each shop you've paid as Need, Penny (she decides) or Wasteful, and leave Penny a short note about your life. An entry's own tag beats your shop rule, which beats your category rule, which beats Penny's pick. The split updates at once.
- **Talk to Penny** (Gemini): tap Penny on Home and ask her how to save, in English, Hindi or Hinglish. She knows this month's totals as Home shows them, your My needs, your note, your budget and your goals, and treats rent, bills, subscriptions and education as fixed costs. With no goals set she doesn't assume any; she suggests adding one.
- **Budget and Penny's moods**: give each category you care about a monthly amount. The monthly budget is their total, split into everyday spending and what's paid in one go (rent, bills, subscriptions, EMIs, bank charges, education and money sent to family). One rule gives every day Penny's mood, and Home shows today's, so Home and the calendar always agree. A day's mood is the worse of two things:
  - **That day's everyday spending** against its share of the budget: happy at or under it, worried up to 1.5 times it, sad above that.
  - **The month so far**: worried at 85% of the everyday budget, sad once it, or any everyday category's amount, is over.

  A day a goal is reached is celebrating. Categories without a budget aren't counted, and rent and the rest paid in one go never change her mood: Home notes when one goes over its budget, and when a category is near its own. Home's card shows the month and today against the day's share. Analysis cards show each budget.
- **Mood calendar**: every day by the same rule, Penny's face on its colour: mint happy, yellow worried, pink sad, sky blue for a goal reached. Under the month, its mood: what most days were, and how many days had each. Tap a day for its entries and the numbers behind its face: what counted against the share, what had no budget or was paid in one go, and the month so far when that's what coloured it.
- **Demo data**: Settings (the gear on Home) swaps in four months of made-up money, with a budget, goals and My needs, to try every screen on. It lives in its own database, so your own entries stay untouched and come back when you turn it off. Reset starts it again from today, and sample bank SMS are there to paste.
- **Goals** (Gemini plans): save for something by a date, with what's needed each week. Note money in and out; reaching the target sets Penny celebrating. Plan with Penny picks up to four cuts from last month's spending, and the phone works out what each saves a month against what the goal needs.
- **Penny moves**: she floats and blinks, bops to her headphones when happy, sweats when worried, cries when sad, and hops in confetti when celebrating; a new mood lands with a bounce. Moments get their own faces: thinking while the chat waits, glasses on while a report or plan is worked out, an idea beside tips, sleepy where nothing's logged. She keeps still when the phone asks for less motion. All of it is drawn in code, no animation files.
- **First launch**: three short pages (meet Penny, what stays private, where to start), shown once and again from Settings. The app icon and launch screen are Penny too, drawn from her own painter by `tool/render_icons_test.dart`.
- **Backup and sync** (optional): sign in with Google in Settings and your entries, budgets, goals with their money, My needs rules and note are kept in your account and synced: as the app opens or comes back, a few seconds after a change, and on Sync now. A new phone signs in and gets everything back; two phones end up the same, the newer edit of each row winning. An edit always counts as newer than the one it replaces, even within the same second or on a phone whose clock is behind, and when the account refuses an edit because it already has one as new, the phone takes the account's. Sign out keeps everything on the phone. Delete account removes the account and its copy, and can clear the phone too. The app works fully without an account, and backup pauses while demo data is on.
- **Offline-first**: everything lives on the phone in SQLite (Drift). Amounts are integer paise, never floating point. Rows carry UUIDv7 ids, timestamps and soft deletes, ready for sync.

## Privacy

- Reading notifications happens on the phone and only with your permission. Penny looks only at your SMS app and the payment, wallet and investing apps listed above, ignores every other app's notifications as they arrive, and keeps only what looks like a payment: the notification's text waits in Penny's private storage until Penny reads it, then is deleted, and what's waiting to be checked keeps only the read entry and its masked preview. What Penny read keeps what she did with each, never the message. None of it is synced.
- The one exception: a money SMS or notice that says money moved but that Penny's rules can't read is sent to her AI (the read-sms Edge Function). Before it leaves the phone, every word that isn't a plain money word or a shop or brand Penny knows is swapped for a tag like [w3], and account, card and long reference numbers become •••, so a person's name never reaches the AI; Penny puts the payee back on the phone from the AI's tags. OTPs, offers, friends' texts and messages with no money moving are never sent. One waiting to be read again is kept on the phone only.
- Penny calls the AI when you tap Ask Penny, Refresh or Plan with Penny, when you send her a chat message, and by herself when you open a report for a month she has looked at before whose entries, note or budget have changed since.
- She sends one month as totals per shop, plus your note and budget, and what came back per category and what you invested as totals: never single entries, SMS text, account numbers, or the names of people you pay (they go as "Person 1, 2"). A payee you type goes only as the words Penny knows from a list of everyday expenses, shops and brands, like "Cook" from "For Cook"; any other word could be a name, so it stays on the phone (tested against `test/fixtures/payee_names.json`). A plan also sends that goal, and the chat your goals, Penny's mood on Home and your messages; any run of 9 or more digits in messages, the note and goal titles is hidden as ••• on the phone before it's sent, and again on the server. "See what Penny sends" lists exactly what goes out.
- Gemini sorts, picks and explains; every rupee in the report and in a plan is computed on the phone, and the server drops any sentence from Gemini that contains a number. In the chat Penny may use numbers from your month, saying "about" for estimates.
- On Gemini's free tier, Google may use what's sent to improve its products. The chat screen says so.
- The Gemini key lives only in Supabase's secrets. Its logs hold timings and token counts, never messages. Reports and the chat are stored on the phone; Clear chat deletes it.
- Until you sign in for backup, the server keeps nothing about your money, only a count of AI calls per day. With backup on, your entries (payees included), budgets, goals and their money, My needs rules and note are stored in Supabase (Mumbai) under your account. Row-level security lets only that signed-in account read or write them through the app; the project's owner can see them in the Supabase dashboard. SMS text and fingerprints, the chat, and Penny's reports and plans never leave the phone. Delete account removes the account and its copy.

## Stack

Flutter · Riverpod · go_router · Drift (SQLite) · flutter_animate · fl_chart · Supabase (anonymous and Google sign-in, Postgres with row-level security for sync, Edge Functions in Deno and TypeScript) · google_sign_in · Gemini with schema-bound JSON output.

## Run it

```bash
flutter pub get
dart run build_runner build -d
flutter run --dart-define-from-file=env/supabase.json
```

`env/supabase.json` holds your Supabase project's URL and publishable key, and the Google web client ID for backup (copy `env/supabase.example.json`). Without it the app runs fully offline and the report says the AI isn't set up; without the client ID, Settings says backup isn't set up.

Google sign-in needs, in the Google Cloud console, an OAuth consent screen, a Web application client (its ID and secret go in Supabase under Authentication → Sign In / Providers → Google) and an Android client for the package `com.naman9245.penny` with the SHA-1 of the key the app is signed with (`cd android && ./gradlew :app:signingReport`).

To install on a phone, build one APK per phone type and use the one that matches (`app-arm64-v8a-release.apk` for most phones today):

```bash
flutter build apk --release --split-per-abi --dart-define-from-file=env/supabase.json
```

After changing how Penny looks, redraw the icon and launch images, then regenerate them:

```bash
flutter test tool/render_icons_test.dart
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Backend

`supabase/` holds the server side:

- `migrations/`: the `ai_usage` table and the functions behind the daily limits, counted apart for reports, chat and plans; and the sync tables (`txns`, `budgets`, `goals`, `goal_deposits`, `tag_rules`, and `prefs` for the note). Only the signed-in account can read or write its rows, never an anonymous one. Every change gets the next number from `sync_seq`, one account's changes commit in order, the newer edit wins, and deletes stay soft so they reach every phone.
- `functions/_shared/`: what the functions share: the month's schema with the budget, masking, the Gemini call and the limits.
- `functions/analyze-month/`: the report. It checks the request, counts the call, asks Gemini for JSON in a fixed schema, and cleans the answer before returning it.
- `functions/penny-chat/`: the chat. It checks the month, the goals and the last 12 messages, masks long digit runs, and returns Penny's reply as plain text.
- `functions/plan-goal/`: a goal's plan. It checks the month and the goal, asks Gemini for up to four cuts in a fixed schema, and drops any that touch a need.
- `functions/delete-account/`: deletes the signed-in account; its synced rows and call counts go with it.

To use your own project: create one, apply the migrations, deploy the four functions (`supabase functions deploy analyze-month`, `penny-chat`, `plan-goal` and `delete-account`), turn on anonymous sign-ins, and add the secret `GEMINI_API_KEY`. Optional secrets: `GEMINI_MODEL` (default `gemini-3.5-flash-lite`, the fastest), `CHAT_MODEL` and `PLAN_MODEL` (if different), `DAILY_USER_LIMIT` (10 reports) and `DAILY_TOTAL_LIMIT` (50), `CHAT_USER_LIMIT` (30 messages) and `CHAT_TOTAL_LIMIT` (200), `PLAN_USER_LIMIT` (10 plans) and `PLAN_TOTAL_LIMIT` (50).

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
  data/       Drift database, repositories, Riverpod providers, demo data,
              the Google account and sync
  models/     enums, categories, Penny's moods, the budget, the report and plans
  services/   SMS parser, share inbox, what Penny sends, report, budget, goal
              and plan maths, AI client
  features/   home, add_txn, import, transactions, analysis, report, needs,
              chat, budget, goals, calendar, settings, welcome
  widgets/    brutal card/button/chip/pill, keypad, pill nav bar, split bar,
              Penny
assets/icon/  the icon and launch images Penny's painter draws
tool/         render_icons_test.dart, which draws them
supabase/     migrations, and the analyze-month, penny-chat, plan-goal and
              delete-account Edge Functions
```

## Roadmap

1. ✅ Setup, theme, local database, manual entry, transaction list
2. ✅ Paste or share a bank SMS, parsed on the phone; analysis charts
3. ✅ Gemini through Supabase Edge Functions: wasteful-spending report, My needs, a chat with Penny
4. ✅ Budgets, goal planner, Penny's moods, mood calendar
5. ✅ Penny's animations, polish (icon, launch screen, welcome), Google sign-in with backup and sync
6. ✅ Faster logging (split, usual entries, type it), paybacks and investing, fixed bills, a forecast and search
7. ✅ Payments read from notifications (bank, wallet and investing SMS, payment, wallet and investing apps), checked first or saved straight away, Penny's own notification and What Penny read, reading with Penny closed, AI for what the rules can't read, more categories, and CSV export
8. Later: receipt photos

Baloo 2 and DM Sans are bundled under the SIL Open Font License.

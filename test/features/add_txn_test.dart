import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/features/add_txn/category_grid.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/widgets/amount_keypad.dart';

import '../helpers/app_harness.dart';

Future<void> openAdd(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('home-add')));
  await tester.pumpAndSettle();
}

/// The Add screen's tiles, in order.
List<Category> tiles(WidgetTester tester) =>
    tester.widget<CategoryGrid>(find.byType(CategoryGrid)).categories;

List<String> tileIds(WidgetTester tester) => [
  for (final category in tiles(tester)) category.id,
];

/// The ids of [categories] in their usual order, with [first] ahead.
List<String> withFirst(List<Category> categories, List<String> first) => [
  ...first,
  for (final category in categories)
    if (!first.contains(category.id)) category.id,
];

/// Taps each of [keys] on the keypad.
Future<void> typeKeys(WidgetTester tester, String keys) async {
  for (final key in keys.split('')) {
    await tester.tap(find.byKey(ValueKey('key-$key')));
    await tester.pump();
  }
}

/// Home → Add → 2, 5, 0 → Food → ✓.
Future<void> addFood250(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('home-add')));
  await tester.pumpAndSettle();
  for (final key in ['2', '5', '0']) {
    await tester.tap(find.byKey(ValueKey('key-$key')));
    await tester.pump();
  }
  expect(find.text('₹250'), findsOneWidget);
  await tester.tap(find.text('Food'));
  await tester.pumpAndSettle();
  // Picking a category only selects it.
  expect(find.text('Tap the tick to save'), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('key-done')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('type 250, tap Food: it shows on Home, and Undo removes it', (
    tester,
  ) async {
    final db = await pumpApp(tester);
    await scrollToRecent(tester);
    expect(find.textContaining('Nothing logged yet'), findsOneWidget);

    await addFood250(tester);

    expect(find.text('Added ₹250 · Food'), findsOneWidget);
    expect(find.text('−₹250'), findsOneWidget); // The new row in Recent.
    await scrollToTop(tester);
    expect(find.text('₹250'), findsOneWidget); // Spent this month.

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    await scrollToRecent(tester);
    expect(find.text('−₹250'), findsNothing);
    expect(find.textContaining('Nothing logged yet'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('the keypad adds and takes away like a calculator', (
    tester,
  ) async {
    final db = await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('home-add')));
    await tester.pumpAndSettle();
    for (final key in '3000+2500−200'.split('')) {
      await tester.tap(find.byKey(ValueKey('key-$key')));
      await tester.pump();
    }
    expect(find.text('₹3,000 + ₹2,500 − ₹200'), findsOneWidget);
    expect(find.text('₹5,300'), findsOneWidget);

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('key-done')));
    await tester.pumpAndSettle();
    expect(find.text('Added ₹5,300 · Food'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets("a sum that comes to nothing can't be saved", (tester) async {
    final db = await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('home-add')));
    await tester.pumpAndSettle();
    for (final key in '200−500'.split('')) {
      await tester.tap(find.byKey(ValueKey('key-$key')));
      await tester.pump();
    }
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('key-done')));
    await tester.pumpAndSettle();
    expect(find.text('How much did you spend?'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('with an amount in, the keypad gets smaller for the categories', (
    tester,
  ) async {
    final db = await pumpApp(tester);
    await openAdd(tester);
    final pad = find.byType(AmountKeypad);
    final roomy = tester.getSize(pad).height;

    await typeKeys(tester, '25');
    await tester.pumpAndSettle();
    final compact = tester.getSize(pad).height;
    expect(compact, lessThan(roomy - 30));
    // Its keys still work.
    await typeKeys(tester, '0');
    expect(find.text('₹250'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('the tick waits for an amount and a category', (tester) async {
    final db = await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('home-add')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('key-done')));
    await tester.pumpAndSettle();
    expect(find.text('How much did you spend?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('key-5')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('key-done')));
    await tester.pumpAndSettle();
    // Still on the Add screen, asking for the category.
    expect(find.text('What was it for?'), findsOneWidget);

    await closeApp(tester, db);
  });

  testWidgets('split the bill: 900 ÷ 3 saves ₹300', (tester) async {
    final db = await pumpApp(tester);
    await openAdd(tester);
    await typeKeys(tester, '900');
    await tester.tap(find.byKey(const ValueKey('split-3')));
    await tester.pumpAndSettle();
    expect(find.text('₹300'), findsOneWidget);
    expect(find.text('₹900 ÷ 3'), findsOneWidget);

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('key-done')));
    await tester.pumpAndSettle();
    expect(find.text('Added ₹300 · Food'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('a split works out the sum first, to the paisa, until the '
      'next key', (tester) async {
    final db = await pumpApp(tester);
    await openAdd(tester);
    // Split shows only once there's an amount to split.
    expect(
      tester
          .widget<IgnorePointer>(
            find
                .ancestor(
                  of: find.byKey(const ValueKey('split-2')),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring,
      isTrue,
    );

    await typeKeys(tester, '600+400');
    await tester.tap(find.byKey(const ValueKey('split-3')));
    await tester.pumpAndSettle();
    expect(find.text('₹333.33'), findsOneWidget);
    expect(find.text('₹1,000 ÷ 3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('key-⌫')));
    await tester.pump();
    expect(find.text('₹333.3'), findsOneWidget);
    expect(find.byKey(const ValueKey('split-note')), findsNothing);
    await closeApp(tester, db);
  });

  testWidgets('Again? fills in a usual entry, and only ✓ saves it', (
    tester,
  ) async {
    final now = DateTime.now();
    late String chaiId;
    final db = await pumpApp(
      tester,
      seed: (repo) async {
        for (final days in [2, 1]) {
          chaiId = await repo.add(
            amountPaise: 2000,
            type: TxnType.debit,
            categoryId: 'food',
            occurredAt: now.subtract(Duration(days: days)),
            merchant: 'Chai point',
          );
        }
        // Seen once, so not usual.
        await repo.add(
          amountPaise: 45000,
          type: TxnType.debit,
          categoryId: 'shopping',
          occurredAt: now.subtract(const Duration(days: 3)),
          merchant: 'Myntra',
        );
      },
    );
    await openAdd(tester);
    expect(find.text('🍔 Chai point · ₹20'), findsOneWidget);
    expect(find.byKey(const ValueKey('again-1')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('again-0')));
    await tester.pumpAndSettle();
    expect(find.text('₹20'), findsOneWidget);
    expect(find.text('Chai point'), findsOneWidget); // The Where chip.
    // Filled in, not saved.
    expect(find.text('Tap the tick to save'), findsOneWidget);
    expect(find.textContaining('Added'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('key-done')));
    await tester.pumpAndSettle();
    expect(find.text('Added ₹20 · Food'), findsOneWidget);
    await scrollToRecent(tester);
    expect(find.text('−₹20'), findsNWidgets(3)); // Two before, one new.

    // Not offered over an entry being edited.
    routerOf(tester).push('/txns/$chaiId');
    await tester.pumpAndSettle();
    expect(find.text('Edit this entry'), findsOneWidget);
    expect(find.byKey(const ValueKey('again-0')), findsNothing);
    await closeApp(tester, db);
  });

  testWidgets('the tiles put what you use most first, from the last 90 days', (
    tester,
  ) async {
    final now = DateTime.now();
    final db = await pumpApp(
      tester,
      seed: (repo) async {
        Future<void> add(
          String categoryId,
          int daysAgo, {
          TxnType type = TxnType.debit,
        }) => repo.add(
          amountPaise: 10000 + daysAgo,
          type: type,
          categoryId: categoryId,
          occurredAt: now.subtract(Duration(days: daysAgo)),
        );
        for (final days in [1, 5, 40]) {
          await add('fun', days);
        }
        await add('education', 80);
        // Lots, but too long ago to count.
        for (final days in [100, 120, 150, 200]) {
          await add('health', days);
        }
        for (final days in [2, 9]) {
          await add('freelance', days, type: TxnType.credit);
        }
        // A friend paying back for shopping doesn't lift Shopping.
        for (final days in [3, 4]) {
          await add('shopping', days, type: TxnType.credit);
        }
      },
    );
    await openAdd(tester);
    expect(
      tileIds(tester),
      withFirst(categoriesFor(TxnType.debit), ['fun', 'education']),
    );
    // Fun is the first tile, top left.
    final fun = tester.getTopLeft(find.text('Fun'));
    final food = tester.getTopLeft(find.text('Food'));
    expect(fun.dy, food.dy);
    expect(fun.dx, lessThan(food.dx));

    // Money in: Freelance first, and Paid back stays last.
    await tester.tap(find.text('Got'));
    await tester.pumpAndSettle();
    expect(tileIds(tester), [
      ...withFirst(incomeCategories, ['freelance']),
      tiles(tester).last.id,
    ]);
    expect(tiles(tester).last.label, 'Paid back');
    await closeApp(tester, db);
  });

  testWidgets('Paid back offers what friends pay back for first', (
    tester,
  ) async {
    final now = DateTime.now();
    final db = await pumpApp(
      tester,
      seed: (repo) async {
        for (final days in [1, 6]) {
          await repo.add(
            amountPaise: 30000 + days,
            type: TxnType.credit,
            categoryId: 'travel',
            occurredAt: now.subtract(Duration(days: days)),
          );
        }
        for (final days in [2, 3, 4]) {
          await repo.add(
            amountPaise: 5000 + days,
            type: TxnType.debit,
            categoryId: 'fun',
            occurredAt: now.subtract(Duration(days: days)),
          );
        }
      },
    );
    routerOf(tester).push('/add?type=credit');
    await tester.pumpAndSettle();
    await tapInView(tester, find.text('Paid back'));

    // Paid back for twice, then spent on most.
    final sheet = tester.widget<CategoryGrid>(
      find.byKey(const ValueKey('paid-back-grid')),
    );
    expect([
      for (final category in sheet.categories) category.id,
    ], withFirst(spendCategories, ['travel', 'fun']));
    await closeApp(tester, db);
  });

  testWidgets('no tile moves while the screen is open', (tester) async {
    final db = await pumpApp(tester);
    await openAdd(tester);
    final before = tileIds(tester);
    expect(before.first, 'food');

    // Saved while the screen is open, as a notification might.
    final saving = Future.wait([
      for (var i = 0; i < 2; i++)
        TxnRepository(db).add(
          amountPaise: 15000,
          type: TxnType.debit,
          categoryId: 'fun',
          occurredAt: DateTime.now(),
          merchant: 'PVR',
        ),
    ]);
    await tester.pumpAndSettle();
    await saving;
    await tester.pumpAndSettle();
    // The screen heard: they're offered again. But no tile moved.
    expect(find.byKey(const ValueKey('again-0')), findsOneWidget);
    expect(tileIds(tester), before);

    // Next time, Fun comes first.
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await openAdd(tester);
    expect(tileIds(tester).first, 'fun');
    await closeApp(tester, db);
  });

  testWidgets('Where: "240 Swiggy" fills in the amount, Food and the place', (
    tester,
  ) async {
    final db = await pumpApp(tester);
    await openAdd(tester);
    await tester.tap(find.text('Where?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '240 Swiggy');
    await tester.pump();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('quick-preview')))
          .textSpan!
          .toPlainText(),
      endsWith('₹240 · 🍔 Food · Swiggy'),
    );

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('₹240'), findsOneWidget);
    expect(find.text('Swiggy'), findsOneWidget);
    expect(find.text('Tap the tick to save'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('key-done')));
    await tester.pumpAndSettle();
    expect(find.text('Added ₹240 · Food'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('Where keeps a picked category and an amount already typed', (
    tester,
  ) async {
    final db = await pumpApp(tester);
    await openAdd(tester);
    // A category picked first stays picked.
    await tester.tap(find.text('Travel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Where?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '240 Swiggy');
    await tester.pump();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('quick-preview')))
          .textSpan!
          .toPlainText(),
      endsWith('₹240 · 🚌 Travel · Swiggy'),
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Tap the tick to save'), findsOneWidget);

    // With an amount there, numbers in a place stay in the place.
    await tester.tap(find.text('Swiggy'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Sector 18 market');
    await tester.pump();
    expect(find.byKey(const ValueKey('quick-preview')), findsNothing);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('₹240'), findsOneWidget);
    expect(find.text('Sector 18 market'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('the undo offer fades by itself and the entry stays', (
    tester,
  ) async {
    final db = await pumpApp(tester);
    await addFood250(tester);
    expect(find.text('Added ₹250 · Food'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(find.text('Added ₹250 · Food'), findsNothing);
    await scrollToRecent(tester);
    expect(find.text('−₹250'), findsOneWidget);
    await closeApp(tester, db);
  });
}

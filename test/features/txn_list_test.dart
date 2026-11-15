import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/models/txn_enums.dart';

import '../helpers/app_harness.dart';

void main() {
  Future<void> seed(TxnRepository repo) async {
    for (final (category, merchant) in [
      ('food', 'Swiggy'),
      ('travel', 'Namma Metro'),
    ]) {
      await repo.add(
        amountPaise: 9000,
        type: TxnType.debit,
        categoryId: category,
        occurredAt: DateTime.now(),
        merchant: merchant,
      );
    }
  }

  testWidgets('pick a category, clear it, and pick another', (tester) async {
    final db = await pumpApp(tester, seed: seed);
    routerOf(tester).push('/txns');
    await tester.pumpAndSettle();
    expect(find.text('Swiggy'), findsOneWidget);
    expect(find.text('Namma Metro'), findsOneWidget);

    Future<void> pick(String category) async {
      await tester.tap(find.byKey(const ValueKey('category-pick')));
      await tester.pumpAndSettle();
      // Only the month's own categories are offered.
      expect(find.byKey(const ValueKey('pick-category-fun')), findsNothing);
      await tester.tap(find.byKey(ValueKey('pick-category-$category')));
      await tester.pumpAndSettle();
    }

    await pick('travel');
    expect(find.text('Namma Metro'), findsOneWidget);
    expect(find.text('Swiggy'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('category-filter')));
    await tester.pumpAndSettle();
    expect(find.text('Swiggy'), findsOneWidget);

    await pick('food');
    expect(find.text('Swiggy'), findsOneWidget);
    expect(find.text('Namma Metro'), findsNothing);
    await closeApp(tester, db);
  });

  testWidgets('hold one, tap another, and Combine makes them one', (
    tester,
  ) async {
    final now = DateTime.now();
    final db = await pumpApp(
      tester,
      seed: (repo) async {
        for (final (paise, hour) in [(667, 1), (1167, 2)]) {
          await repo.add(
            amountPaise: paise,
            type: TxnType.debit,
            categoryId: 'people',
            occurredAt: DateTime(now.year, now.month, now.day, hour),
            merchant: 'Ravi Kumar',
            payeeIsPerson: true,
          );
        }
        await repo.add(
          amountPaise: 5000,
          type: TxnType.credit,
          categoryId: 'pocket_money',
          occurredAt: DateTime(now.year, now.month, now.day, 3),
        );
      },
    );
    routerOf(tester).push('/txns');
    await tester.pumpAndSettle();

    final rows = find.text('Ravi Kumar');
    expect(rows, findsNWidgets(2));
    await tester.longPress(rows.first);
    await tester.pumpAndSettle();
    expect(find.text('Pick one more to combine'), findsOneWidget);

    // Money in can't join money out.
    await tester.tap(find.text('Pocket money'));
    await tester.pumpAndSettle();
    expect(find.text('Pick only money out, or only money in'), findsOneWidget);
    await tester.tap(find.text('Pocket money'));
    await tester.pumpAndSettle();

    await tester.tap(rows.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Combine 2 · ₹18.34'));
    await tester.pumpAndSettle();
    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.text('−₹18.34'), findsOneWidget);
    expect(find.text('Combined 2 into ₹18.34'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Ravi Kumar'), findsNWidgets(2));
    await closeApp(tester, db);
  });
}

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
}

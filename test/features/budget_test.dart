import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/budget_repository.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/features/budget/budget_screen.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/budget_math.dart';

import '../helpers/app_harness.dart';

void main() {
  final now = DateTime.now();
  final month = monthStart(now);
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final left = daysLeftLabel(daysInMonth - now.day);

  // ₹6,000 of everyday spending today, and rent, which stays out of it.
  Future<void> seedMonth(TxnRepository repo) async {
    await repo.add(
      amountPaise: 600000,
      type: TxnType.debit,
      categoryId: 'food',
      occurredAt: dayStart(now).add(const Duration(hours: 9)),
      merchant: 'Swiggy',
    );
    await repo.add(
      amountPaise: 900000,
      type: TxnType.debit,
      categoryId: 'rent',
      occurredAt: dayStart(now).add(const Duration(hours: 8)),
    );
  }

  Future<void> type(WidgetTester tester, String digits) async {
    for (final digit in digits.split('')) {
      await tester.tap(find.byKey(ValueKey('key-$digit')));
    }
    await tester.tap(find.byKey(const ValueKey('key-done')));
    await tester.pumpAndSettle();
  }

  testWidgets('setting a budget changes Penny on Home', (tester) async {
    final db = await pumpApp(tester, seed: seedMonth);
    expect(find.text("All good! You're on track."), findsOneWidget);
    expect(find.byKey(const ValueKey('budget-line')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('set-budget')));
    await tester.pumpAndSettle();
    expect(find.byType(BudgetScreen), findsOneWidget);
    expect(find.text('Not set yet'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('everyday-budget')));
    await tester.pumpAndSettle();
    await type(tester, '7000');
    expect(find.textContaining('₹6,000 spent this month'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    // ₹6,000 of ₹7,000 is past 85%, and rent doesn't count.
    expect(find.text("You're close to your spending cap."), findsOneWidget);
    expect(find.text('₹6,000 of ₹7,000 · $left'), findsOneWidget);
    expect(find.byKey(const ValueKey('set-budget')), findsNothing);
    await closeApp(tester, db);
  });

  testWidgets('a cap shows on its category card, and clears', (tester) async {
    final db = await pumpApp(
      tester,
      seed: seedMonth,
      seedDb: (db) => BudgetRepository(db).setEveryday(2000000),
    );
    routerOf(tester).push('/budget');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('cap-food')));
    await tester.pumpAndSettle();
    await type(tester, '5000');
    expect(find.text('₹6,000 of ₹5,000 this month'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(
      find.text("You've gone over budget. Let's plan a quick fix!"),
      findsOneWidget,
    );
    expect(find.text('Food is over its cap'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Analysis'));
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('category-card-food'));
    await tester.scrollUntilVisible(card, 300);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: card, matching: find.text('₹1,000 over your cap')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('cap-bar-food')), findsOneWidget);

    // Clearing the cap takes it off the card.
    routerOf(tester).push('/budget');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cap-food')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('amount-clear')));
    await tester.pumpAndSettle();
    expect(find.text('₹6,000 this month'), findsOneWidget);
    await closeApp(tester, db);
  });
}

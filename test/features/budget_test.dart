import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/core/utils/money.dart';
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

  Finder inTotal(String text) => find.descendant(
    of: find.byKey(const ValueKey('monthly-budget')),
    matching: find.text(text),
  );

  testWidgets('category budgets add up, and Penny goes by them', (
    tester,
  ) async {
    final db = await pumpApp(tester, seed: seedMonth);
    expect(find.text("All good! You're on track."), findsOneWidget);
    expect(find.byKey(const ValueKey('budget-line')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('set-budget')));
    await tester.pumpAndSettle();
    expect(find.byType(BudgetScreen), findsOneWidget);
    expect(find.text('Not set yet'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('budget-food')));
    await tester.pumpAndSettle();
    await type(tester, '5000+2000');
    final rent = find.byKey(const ValueKey('budget-rent'));
    await tester.ensureVisible(rent);
    await tester.pumpAndSettle();
    await tester.tap(rent);
    await tester.pumpAndSettle();
    await type(tester, '9000');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('monthly-budget')),
      -300,
    );
    await tester.pumpAndSettle();

    // Food's ₹7,000 and rent's ₹9,000 add up to the monthly budget.
    expect(inTotal('₹16,000'), findsOneWidget);
    expect(inTotal('Everyday ₹7,000 · Paid in one go ₹9,000'), findsOneWidget);
    expect(find.text('₹6,000 of ₹7,000 this month'), findsOneWidget);

    // The header scrolled away with the list, so leave the way Back would.
    routerOf(tester).pop();
    await tester.pumpAndSettle();
    // ₹6,000 today is far over a day's share of ₹7,000, and the month is
    // past 85% of it; rent doesn't count.
    final share = formatPaise(dailySharePaise(700000, month));
    expect(
      find.text("Today went well over your share. Let's plan a fix!"),
      findsOneWidget,
    );
    expect(find.text('Everyday budget · $left'), findsOneWidget);
    expect(find.text('₹6,000 of ₹7,000'), findsOneWidget);
    expect(find.text('Today ₹6,000 of your $share share'), findsOneWidget);
    expect(find.text('Food is near its budget'), findsOneWidget);
    expect(find.byKey(const ValueKey('set-budget')), findsNothing);
    await closeApp(tester, db);
  });

  testWidgets('a budget shows on its category card, and clears', (
    tester,
  ) async {
    final db = await pumpApp(
      tester,
      seed: seedMonth,
      seedDb: (db) => BudgetRepository(db).setAmount('food', 500000),
    );

    expect(
      find.text("Today went well over your share. Let's plan a fix!"),
      findsOneWidget,
    );
    expect(find.text('Food is over its budget'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Analysis'));
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('category-card-food'));
    await tester.scrollUntilVisible(card, 300);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: card, matching: find.text('₹1,000 over budget')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('budget-bar-food')), findsOneWidget);

    // Clearing it takes it off the page's total.
    routerOf(tester).push('/budget');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('budget-food')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('amount-clear')));
    await tester.pumpAndSettle();
    expect(find.text('₹6,000 this month · no budget'), findsOneWidget);
    expect(find.text('Not set yet'), findsOneWidget);
    await closeApp(tester, db);
  });
}

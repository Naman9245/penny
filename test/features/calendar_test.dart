import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/budget_repository.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/features/budget/budget_screen.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/budget_math.dart';

import '../helpers/app_harness.dart';

void main() {
  // Last month is complete, so every day of it has happened.
  final month = prevMonth(monthStart(DateTime.now()));
  final name = DateFormat('MMMM').format(month);
  DateTime on(int day) => DateTime(month.year, month.month, day, 13);

  // A share of about ₹1,000 a day: ₹100 is happy, ₹1,300 worried and
  // ₹5,000 sad, whatever the month's length. Rent stays out of it.
  Future<void> seedMonth(TxnRepository repo) async {
    Future<void> spend(int rupees, int day, {String category = 'food'}) =>
        repo.add(
          amountPaise: rupees * 100,
          type: TxnType.debit,
          categoryId: category,
          occurredAt: on(day),
          merchant: category == 'food' ? 'Swiggy' : null,
        );
    await spend(100, 2);
    await spend(1300, 3);
    await spend(5000, 4);
    await spend(9000, 4, category: 'rent');
  }

  Future<void> openLastMonth(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Previous month'));
    await tester.pumpAndSettle();
  }

  testWidgets('each day is coloured by what was spent that day', (
    tester,
  ) async {
    final db = await pumpApp(
      tester,
      seed: seedMonth,
      seedDb: (db) => BudgetRepository(db).setAmount('food', 3000000),
    );
    await openLastMonth(tester);

    expect(find.bySemanticsLabel('1 $name'), findsOneWidget);
    expect(find.bySemanticsLabel('2 $name, Happy'), findsOneWidget);
    expect(find.bySemanticsLabel('3 $name, Worried'), findsOneWidget);
    expect(find.bySemanticsLabel('4 $name, Sad'), findsOneWidget);
    expect(find.bySemanticsLabel('5 $name, Happy'), findsOneWidget);

    // Day 1 came before the first entry; every day after the 4th is happy.
    final days = DateTime(month.year, month.month + 1, 0).day;
    final summary = find.byKey(const ValueKey('month-summary'));
    await tester.scrollUntilVisible(summary, 300);
    await tester.pumpAndSettle();
    expect(find.text('Mostly happy'), findsOneWidget);
    expect(find.text('${days - 3} happy · 1 worried · 1 sad'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('day-4')), -300);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('day-4')));
    await tester.pumpAndSettle();
    final share = formatPaise(dailySharePaise(3000000, month));
    expect(find.text('₹5,000 spent · your share $share'), findsOneWidget);
    expect(find.text('Plus ₹9,000 paid in one go'), findsOneWidget);
    expect(find.text('Swiggy'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('without a budget the calendar asks for one', (tester) async {
    final db = await pumpApp(tester, seed: seedMonth);
    await openLastMonth(tester);

    expect(find.bySemanticsLabel('4 $name'), findsOneWidget);
    expect(find.bySemanticsLabel('4 $name, Sad'), findsNothing);

    await tester.tap(find.text('Set a budget'));
    await tester.pumpAndSettle();
    expect(find.byType(BudgetScreen), findsOneWidget);
    await closeApp(tester, db);
  });
}

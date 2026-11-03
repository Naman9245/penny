import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/budget_repository.dart';
import 'package:penny/data/db/app_database.dart';
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
  // ₹5,000 sad, whatever the month's length. Rent and shopping, which has
  // no budget, stay out of it.
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
    await spend(700, 4, category: 'shopping');
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
    // Only what the face goes by is set against the share.
    expect(find.text('₹5,000 of your $share share'), findsOneWidget);
    expect(find.text('Plus ₹700 with no budget'), findsOneWidget);
    expect(find.text('Plus ₹9,000 paid in one go'), findsOneWidget);
    expect(find.byKey(const ValueKey('day-month-note')), findsNothing);
    expect(find.text('Swiggy'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('once the month nears its budget, quiet days turn yellow', (
    tester,
  ) async {
    final db = await pumpApp(
      tester,
      seed: (repo) => repo.add(
        amountPaise: 650000,
        type: TxnType.debit,
        categoryId: 'food',
        occurredAt: on(2),
      ),
      seedDb: (db) => BudgetRepository(db).setAmount('food', 700000),
    );
    await openLastMonth(tester);

    expect(find.bySemanticsLabel('2 $name, Sad'), findsOneWidget);
    expect(find.bySemanticsLabel('5 $name, Worried'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('day-5')));
    await tester.pumpAndSettle();
    final share = formatPaise(dailySharePaise(700000, month));
    expect(find.text('₹0 of your $share share'), findsOneWidget);
    expect(
      find.text('Everyday budget so far: ₹6,500 of ₹7,000'),
      findsOneWidget,
    );
    await closeApp(tester, db);
  });

  group('Home shows the same face as today on the calendar', () {
    final now = DateTime.now();
    final today = DateFormat('d MMMM').format(now);
    final share = formatPaise(dailySharePaise(700000, now));
    DateTime at(int hour) => dayStart(now).add(Duration(hours: hour));

    Future<void> budget(AppDatabase db) async {
      await BudgetRepository(db).setAmount('food', 700000);
      await BudgetRepository(db).setAmount('rent', 300000);
    }

    Future<void> openCalendar(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel('Calendar'));
      await tester.pumpAndSettle();
    }

    testWidgets('rent over its budget is noted, and both stay happy', (
      tester,
    ) async {
      final db = await pumpApp(
        tester,
        seed: (repo) async {
          await repo.add(
            amountPaise: 376600,
            type: TxnType.debit,
            categoryId: 'rent',
            occurredAt: at(1),
          );
          await repo.add(
            amountPaise: 200000,
            type: TxnType.debit,
            categoryId: 'rent',
            occurredAt: at(1),
            merchant: 'For cook',
          );
        },
        seedDb: budget,
      );

      expect(find.text('Happy'), findsOneWidget);
      expect(find.text('Today ₹0 of your $share share'), findsOneWidget);
      expect(
        find.text('Rent & PG went ₹2,766 over its budget'),
        findsOneWidget,
      );
      await openCalendar(tester);
      expect(find.bySemanticsLabel('$today, today, Happy'), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('a big spend today makes both sad', (tester) async {
      final db = await pumpApp(
        tester,
        seed: (repo) => repo.add(
          amountPaise: 600000,
          type: TxnType.debit,
          categoryId: 'food',
          occurredAt: at(1),
        ),
        seedDb: budget,
      );

      expect(find.text('Sad'), findsOneWidget);
      expect(find.text('Today ₹6,000 of your $share share'), findsOneWidget);
      await openCalendar(tester);
      expect(find.bySemanticsLabel('$today, today, Sad'), findsOneWidget);
      await closeApp(tester, db);
    });
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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/features/home/fixed_bills_card.dart';
import 'package:penny/models/txn_enums.dart';

import '../helpers/app_harness.dart';
import '../helpers/fixed_today.dart';
import '../helpers/txn_factory.dart';

void main() {
  group('fixed bills due', () {
    final october = DateTime(2026, 10, 1, 10);
    DateTime oct(int day) => DateTime(2026, 10, day, 10);
    DateTime nov(int day) => DateTime(2026, 11, day, 10);

    test("last month's fixed bills not logged yet, biggest first", () {
      final bills = fixedBillsDue(
        [
          txn(8500, october, categoryId: 'rent', merchant: 'Sunrise PG'),
          txn(299, oct(8), categoryId: 'bills', merchant: 'Airtel'),
          txn(149, oct(3), categoryId: 'subscriptions', merchant: 'Netflix'),
          // The latest amount wins.
          txn(199, oct(5), categoryId: 'subscriptions', merchant: 'Netflix'),
          txn(450, oct(18), categoryId: 'education'),
          // Not fixed bills.
          txn(250, oct(9), merchant: 'Swiggy'),
          txn(1000, oct(2), categoryId: 'invest', merchant: 'Groww SIP'),
          txn(300, oct(23), type: TxnType.credit, categoryId: 'rent'),
        ],
        [
          // Already logged this month, whatever the spelling.
          txn(299, nov(2), categoryId: 'bills', merchant: ' AIRTEL'),
        ],
      );
      expect(
        [for (final b in bills) '${b.categoryId} ${b.place} ${b.amountPaise}'],
        [
          'rent Sunrise PG 850000',
          'education null 45000',
          'subscriptions Netflix 19900',
        ],
      );
    });

    test('a skipped bill stays hidden', () {
      final bills = fixedBillsDue(
        [txn(199, oct(5), categoryId: 'subscriptions', merchant: 'Netflix')],
        const [],
        skipped: {'subscriptions|netflix'},
      );
      expect(bills, isEmpty);
    });
  });

  group('on Home', () {
    // Seeds October's bills and one already logged in November.
    Future<void> seedBills(TxnRepository repo) async {
      await repo.add(
        amountPaise: 850000,
        type: TxnType.debit,
        categoryId: 'rent',
        occurredAt: DateTime(2026, 10, 1, 10),
        merchant: 'Sunrise PG',
      );
      await repo.add(
        amountPaise: 19900,
        type: TxnType.debit,
        categoryId: 'subscriptions',
        occurredAt: DateTime(2026, 10, 5, 21),
        merchant: 'Netflix',
      );
      await repo.add(
        amountPaise: 29900,
        type: TxnType.debit,
        categoryId: 'bills',
        occurredAt: DateTime(2026, 10, 8, 20),
        merchant: 'Airtel',
      );
      await repo.add(
        amountPaise: 29900,
        type: TxnType.debit,
        categoryId: 'bills',
        occurredAt: DateTime(2026, 11, 2, 20),
        merchant: 'Airtel',
      );
    }

    testWidgets("Log adds a bill with Undo; Skip is remembered", (
      tester,
    ) async {
      final db = await pumpApp(
        tester,
        seed: seedBills,
        overrides: [todayIs(DateTime(2026, 11, 3))],
      );
      expect(find.text('Same fixed bills as last month?'), findsOneWidget);
      expect(find.text('Sunrise PG · ₹8,500'), findsOneWidget);
      expect(find.text('Netflix · ₹199'), findsOneWidget);
      expect(find.textContaining('Airtel ·'), findsNothing); // Logged.

      await tester.tap(find.byKey(const ValueKey('log-bill-0')));
      await tester.pumpAndSettle();
      expect(find.text('Added ₹8,500 · Rent & PG'), findsOneWidget);
      expect(find.text('Sunrise PG · ₹8,500'), findsNothing);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Sunrise PG · ₹8,500'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('skip-bill-1')));
      await tester.pumpAndSettle();
      expect(find.text('Netflix · ₹199'), findsNothing);

      // Opened again, the phone still remembers the skip.
      await tester.pumpWidget(const SizedBox());
      await pumpPenny(
        tester,
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          todayIs(DateTime(2026, 11, 3)),
        ],
      );
      expect(find.text('Sunrise PG · ₹8,500'), findsOneWidget);
      expect(find.text('Netflix · ₹199'), findsNothing);

      // Once nothing's left, the card goes.
      await tester.tap(find.byKey(const ValueKey('log-bill-0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('fixed-bills')), findsNothing);
      await closeApp(tester, db);
    });

    testWidgets('only in the first week', (tester) async {
      final db = await pumpApp(
        tester,
        seed: seedBills,
        overrides: [todayIs(DateTime(2026, 11, 8))],
      );
      expect(find.byKey(const ValueKey('fixed-bills')), findsNothing);
      await closeApp(tester, db);
    });

    testWidgets("Penny's box says where the month is heading", (tester) async {
      final db = await pumpApp(
        tester,
        seed: (repo) => repo.add(
          amountPaise: 380000,
          type: TxnType.debit,
          categoryId: 'food',
          occurredAt: DateTime(2026, 11, 5, 13),
        ),
        overrides: [todayIs(DateTime(2026, 11, 10))],
      );
      // No budget: the pace, and where it leads.
      final box = find.byKey(const ValueKey('budget-box'));
      expect(
        find.descendant(
          of: box,
          matching: find.text('This month · 20 days left'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: box,
          matching: find.text('At ₹380 a day, about ₹11,400 this month'),
        ),
        findsOneWidget,
      );
      await closeApp(tester, db);
    });
  });

  testWidgets('Transactions: search a place, a category or an amount, '
      'and see it added up', (tester) async {
    final now = DateTime.now();
    final db = await pumpApp(
      tester,
      seed: (repo) async {
        Future<void> add(
          int rupees,
          String categoryId, {
          String? merchant,
          TxnType type = TxnType.debit,
        }) => repo
            .add(
              amountPaise: rupees * 100,
              type: type,
              categoryId: categoryId,
              occurredAt: now,
              merchant: merchant,
            )
            .then((_) {});
        await add(250, 'food', merchant: 'Swiggy');
        await add(480, 'food', merchant: 'Swiggy');
        await add(60, 'travel', merchant: 'Metro');
        await add(100, 'food', type: TxnType.credit); // Paid back.
        await add(5000, 'salary', type: TxnType.credit);
      },
    );
    routerOf(tester).push('/txns');
    await tester.pumpAndSettle();
    // Nothing narrowed down: no total.
    expect(find.byKey(const ValueKey('filter-total')), findsNothing);

    Future<void> search(String text) async {
      await tester.enterText(find.byKey(const ValueKey('txn-search')), text);
      await tester.pumpAndSettle();
    }

    String total() =>
        tester.widget<Text>(find.byKey(const ValueKey('filter-total'))).data!;

    await tester.tap(find.byKey(const ValueKey('search-toggle')));
    await tester.pumpAndSettle();
    await search('swiggy');
    expect(total(), '2 entries · spent ₹730');
    await search('₹250');
    expect(total(), '1 entry · spent ₹250');
    await search('food');
    expect(total(), '3 entries · spent ₹730 · ₹100 came back');

    // Together with Spent.
    await tester.tap(find.text('Spent'));
    await tester.pumpAndSettle();
    expect(total(), '2 entries · spent ₹730');

    await search('pizza');
    expect(find.text('Nothing matches "pizza"'), findsOneWidget);

    // Closing the search clears it; Spent still narrows things down.
    await tester.tap(find.byKey(const ValueKey('search-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('txn-search')), findsNothing);
    expect(total(), '3 entries · spent ₹790');
    await closeApp(tester, db);
  });
}

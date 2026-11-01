import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/features/needs/needs_screen.dart';
import 'package:penny/features/needs/recent_shops.dart';
import 'package:penny/models/txn_enums.dart';

import '../helpers/app_harness.dart';
import '../helpers/txn_factory.dart';

void main() {
  final month = monthStart(DateTime.now());
  DateTime at(int minute) => DateTime(month.year, month.month, 1, 9, minute);

  Future<void> seed(TxnRepository repo) async {
    await repo.add(
      amountPaise: 50000,
      type: TxnType.debit,
      categoryId: 'food',
      occurredAt: at(0),
      merchant: 'Swiggy',
    );
    await repo.add(
      amountPaise: 30000,
      type: TxnType.debit,
      categoryId: 'food',
      occurredAt: at(1),
      merchant: 'Canteen',
    );
    await repo.add(
      amountPaise: 20000,
      type: TxnType.debit,
      categoryId: 'other',
      occurredAt: at(2),
      merchant: 'Asha Rao',
      source: TxnSource.share,
      payeeIsPerson: true,
    );
  }

  Future<void> openNeeds(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Analysis'));
    await tester.pumpAndSettle();
    final open = find.byKey(const ValueKey('open-needs'));
    await tester.ensureVisible(open);
    await tester.pumpAndSettle();
    await tester.tap(open);
    await tester.pumpAndSettle();
  }

  // The page is a lazy list: rows further down only exist once scrolled to.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find
          .descendant(
            of: find.byType(NeedsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String rowKey, String option) async {
    final target = find.descendant(
      of: find.byKey(ValueKey(rowKey)),
      matching: find.text(option),
    );
    await reveal(tester, target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  // The header scrolls away with the list, so leave the way Back would.
  Future<void> leave(WidgetTester tester) async {
    routerOf(tester).pop();
    await tester.pumpAndSettle();
  }

  Finder inSplit(String text) => find.descendant(
    of: find.byKey(const ValueKey('split-card')),
    matching: find.text(text),
  );

  testWidgets('a category rule sorts its spends at once', (tester) async {
    final db = await pumpApp(tester, seed: seed);
    await openNeeds(tester);
    expect(find.text('My needs'), findsOneWidget);

    await choose(tester, 'need-category-food', 'Wasteful');
    await leave(tester);

    // Food (₹800) is wasteful; the transfer is still for Penny to sort.
    expect(inSplit('₹800'), findsOneWidget);
    expect(inSplit('₹200'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('a shop rule beats its category, and people aren\'t shops', (
    tester,
  ) async {
    final db = await pumpApp(tester, seed: seed);
    await openNeeds(tester);

    await reveal(tester, find.byKey(const ValueKey('need-shop-canteen')));
    expect(find.byKey(const ValueKey('need-shop-swiggy')), findsOneWidget);
    expect(find.text('Asha Rao'), findsNothing);

    await choose(tester, 'need-category-food', 'Need');
    await choose(tester, 'need-shop-swiggy', 'Wasteful');
    await leave(tester);

    expect(inSplit('₹500'), findsOneWidget); // Swiggy, wasteful.
    expect(inSplit('₹300'), findsOneWidget); // Canteen, a need.
    await closeApp(tester, db);
  });

  testWidgets('the note is saved and shows in what Penny sends', (
    tester,
  ) async {
    final db = await pumpApp(tester, seed: seed);
    await openNeeds(tester);

    final note = find.byKey(const ValueKey('penny-note'));
    await reveal(tester, note);
    await tester.enterText(note, 'Student in a PG, metro daily');
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('save-note'));
    await reveal(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Saved. Penny reads it next time.'), findsOneWidget);

    await leave(tester);
    final open = find.byKey(const ValueKey('open-report'));
    await tester.ensureVisible(open);
    await tester.pumpAndSettle();
    await tester.tap(open);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('see-what-penny-sends')));
    await tester.pumpAndSettle();

    expect(find.text('Your note'), findsOneWidget);
    expect(find.text('Student in a PG, metro daily'), findsOneWidget);
    await closeApp(tester, db);
  });

  test('recent shops: biggest first, latest spelling, no people', () {
    final day = DateTime(2026, 11, 2);
    final shops = recentShops([
      txn(100, day, merchant: 'swiggy'),
      txn(300, day.add(const Duration(hours: 1)), merchant: 'Swiggy '),
      txn(250, day, merchant: 'Canteen'),
      txn(500, day, merchant: 'Asha Rao', payeeIsPerson: true),
      txn(900, day, type: TxnType.credit, merchant: 'Papa'),
      txn(50, day),
    ]);
    expect(shops.map((s) => [s.key, s.name, s.totalPaise]), [
      ['swiggy', 'Swiggy', 40000],
      ['canteen', 'Canteen', 25000],
    ]);
  });
}

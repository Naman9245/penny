import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/txn_enums.dart';

import '../helpers/app_harness.dart';

/// [text] inside the Home card keyed [stat].
Finder onCard(String stat, String text) =>
    find.descendant(of: find.byKey(ValueKey(stat)), matching: find.text(text));

Future<void> typeKeys(WidgetTester tester, String keys) async {
  for (final key in keys.split('')) {
    await tester.tap(find.byKey(ValueKey('key-$key')));
    await tester.pump();
  }
}

void main() {
  testWidgets('Got → Paid back → Food: Spent drops, Got stays, Left goes up', (
    tester,
  ) async {
    final now = DateTime.now();
    final db = await pumpApp(
      tester,
      seed: (repo) async {
        await repo.add(
          amountPaise: 90000,
          type: TxnType.debit,
          categoryId: 'food',
          occurredAt: now,
          merchant: 'Dominos',
        );
        await repo.add(
          amountPaise: 500000,
          type: TxnType.credit,
          categoryId: 'salary',
          occurredAt: now,
        );
      },
    );
    expect(onCard('stat-spent', '₹900'), findsOneWidget);
    expect(onCard('stat-left', '₹4,100'), findsOneWidget);

    routerOf(tester).push('/add?type=credit');
    await tester.pumpAndSettle();
    await typeKeys(tester, '300');
    await tester.tap(find.text('Paid back'));
    await tester.pumpAndSettle();
    expect(find.text('Paid back for what?'), findsOneWidget);
    // Only spending can come back: no investing, no income.
    final grid = find.byKey(const ValueKey('paid-back-grid'));
    expect(
      find.descendant(of: grid, matching: find.text('Invest / SIP')),
      findsNothing,
    );
    await tester.tap(find.descendant(of: grid, matching: find.text('Food')));
    await tester.pumpAndSettle();
    expect(find.text('Food · paid back'), findsOneWidget); // The tile.
    expect(find.text('Tap the tick to save'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('key-done')));
    await tester.pumpAndSettle();
    expect(find.text('Added ₹300 · Food · paid back'), findsOneWidget);

    expect(onCard('stat-spent', '₹600'), findsOneWidget);
    expect(onCard('stat-got', '₹5,000'), findsOneWidget);
    expect(onCard('stat-left', '₹4,400'), findsOneWidget);
    await scrollToRecent(tester);
    expect(find.text('Food · paid back'), findsOneWidget); // Its row.
    expect(find.text('+₹300'), findsOneWidget);

    // The day keeps its own spending, and says what came back.
    await tester.tap(find.bySemanticsLabel('Calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('day-${now.day}')));
    await tester.pumpAndSettle();
    expect(find.text('₹900 spent'), findsOneWidget);
    expect(find.text('₹300 came back'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('a SIP leaves Spent alone, takes Left down, and is put away', (
    tester,
  ) async {
    final now = DateTime.now();
    final db = await pumpApp(
      tester,
      seed: (repo) async {
        await repo.add(
          amountPaise: 50000,
          type: TxnType.debit,
          categoryId: 'food',
          occurredAt: now,
        );
        await repo.add(
          amountPaise: 500000,
          type: TxnType.credit,
          categoryId: 'salary',
          occurredAt: now,
        );
      },
    );

    await tester.tap(find.byKey(const ValueKey('home-add')));
    await tester.pumpAndSettle();
    await typeKeys(tester, '1000');
    // In the grid's last row, just before Other.
    await tester.ensureVisible(find.text('Invest / SIP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invest / SIP'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('key-done')));
    await tester.pumpAndSettle();
    expect(find.text('Invested ₹1,000'), findsOneWidget);

    expect(onCard('stat-spent', '₹500'), findsOneWidget);
    expect(onCard('stat-left', '₹3,500'), findsOneWidget);
    expect(onCard('stat-left', '₹1,000 invested'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Analysis'));
    await tester.pumpAndSettle();
    // Never necessary or wasteful: only the ₹500 of food is to sort.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('split-card')),
        matching: find.text('₹500'),
      ),
      findsOneWidget,
    );
    final invest = find.byKey(const ValueKey('category-card-invest'));
    await tester.scrollUntilVisible(invest, 300);
    expect(find.text('Put away'), findsOneWidget);
    // A fifth of what came in.
    expect(
      find.descendant(of: invest, matching: find.text('20%')),
      findsOneWidget,
    );
    await closeApp(tester, db);
  });
}

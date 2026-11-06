import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/features/analysis/analysis_screen.dart';
import 'package:penny/models/txn_enums.dart';

import '../helpers/app_harness.dart';

void main() {
  testWidgets('Analysis: a card per category, the chart, and a card opens '
      'that category\'s entries', (tester) async {
    final now = DateTime.now();
    final db = await pumpApp(
      tester,
      seed: (repo) async {
        await repo.add(
          amountPaise: 34900,
          type: TxnType.debit,
          categoryId: 'food',
          occurredAt: now,
          merchant: 'Swiggy',
        );
        await repo.add(
          amountPaise: 15100,
          type: TxnType.debit,
          categoryId: 'food',
          occurredAt: now,
        );
        await repo.add(
          amountPaise: 50000,
          type: TxnType.debit,
          categoryId: 'shopping',
          occurredAt: now,
        );
        await repo.add(
          amountPaise: 500000,
          type: TxnType.credit,
          categoryId: 'pocket_money',
          occurredAt: now,
        );
      },
    );

    await tester.tap(find.bySemanticsLabel('Analysis'));
    await tester.pumpAndSettle();

    expect(find.text('Where it went'), findsOneWidget);
    final food = find.byKey(const ValueKey('category-card-food'));
    expect(food, findsOneWidget);
    expect(
      find.descendant(of: food, matching: find.text('2 entries')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: food, matching: find.text('50%')),
      findsOneWidget,
    );
    // Before Penny has looked, the whole ₹1,000 spent is not sorted yet.
    final split = find.byKey(const ValueKey('split-card'));
    expect(
      find.descendant(of: split, matching: find.text('Not sorted yet')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: split, matching: find.text('Money report')),
      findsOneWidget,
    );

    final scrollable = find.descendant(
      of: find.byType(AnalysisScreen),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('category-card-pocket_money')),
      300,
      scrollable: scrollable,
    );
    await tester.scrollUntilVisible(
      find.byType(BarChart),
      300,
      scrollable: scrollable,
    );
    expect(find.byType(BarChart), findsOneWidget);

    await tester.scrollUntilVisible(food, -300, scrollable: scrollable);
    await tester.tap(food);
    await tester.pumpAndSettle();

    expect(find.text('Transactions'), findsOneWidget);
    expect(find.byKey(const ValueKey('category-filter')), findsOneWidget);
    expect(find.text('Swiggy'), findsOneWidget);
    expect(find.text('Shopping'), findsNothing);
    await closeApp(tester, db);
  });

  testWidgets('Analysis with nothing logged nudges you to add entries', (
    tester,
  ) async {
    final db = await pumpApp(tester);

    await tester.tap(find.bySemanticsLabel('Analysis'));
    await tester.pumpAndSettle();

    expect(
      find.text('Add a few entries to see where your money goes.'),
      findsOneWidget,
    );
    expect(find.text('Nothing to compare yet.'), findsOneWidget);
    await closeApp(tester, db);
  });
}

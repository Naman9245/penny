import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/router/app_router.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/features/add_txn/add_txn_controller.dart';
import 'package:penny/features/analysis/analysis_screen.dart';
import 'package:penny/features/calendar/calendar_screen.dart';
import 'package:penny/features/goals/goals_screen.dart';
import 'package:penny/features/home/home_screen.dart';
import 'package:penny/models/txn_enums.dart';

import '../helpers/app_harness.dart';

const _add = ValueKey('home-add');

void main() {
  testWidgets('every tab has Add beside the tabs, clear of the screen', (
    tester,
  ) async {
    final db = await pumpApp(tester);
    final tabs = {
      'Home': HomeScreen,
      'Analysis': AnalysisScreen,
      'Goals': GoalsScreen,
      'Calendar': CalendarScreen,
    };

    for (final MapEntry(key: tab, value: screen) in tabs.entries) {
      await tester.tap(find.bySemanticsLabel(tab));
      await tester.pumpAndSettle();

      final add = find.byKey(_add);
      expect(add.hitTestable(), findsOneWidget, reason: tab);
      expect(
        tester.getSemantics(add),
        isSemantics(label: 'Add', isButton: true, hasTapAction: true),
        reason: tab,
      );
      // Below the screen, never over it.
      expect(
        tester.getRect(add).top,
        greaterThanOrEqualTo(tester.getRect(find.byType(screen)).bottom),
        reason: tab,
      );

      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('key-done')), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(screen), findsOneWidget, reason: tab);
    }

    await closeApp(tester, db);
  });

  for (final tab in ['Calendar', 'Analysis']) {
    testWidgets('on $tab, Add starts on the 1st of the month shown', (
      tester,
    ) async {
      final db = await pumpApp(tester);
      await tester.tap(find.bySemanticsLabel(tab));
      await tester.pumpAndSettle();

      // This month: Add starts today.
      await tester.tap(find.byKey(_add));
      await tester.pumpAndSettle();
      expect(find.text('Pick date'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();

      // Two months back, so its 1st is never yesterday.
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.bySemanticsLabel('Previous month'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(_add));
      await tester.pumpAndSettle();
      final first = prevMonth(prevMonth(monthStart(DateTime.now())));
      expect(find.text(DateFormat('d MMM').format(first)), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();

      // Home keeps starting today, whatever the other tabs show.
      await tester.tap(find.bySemanticsLabel('Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_add));
      await tester.pumpAndSettle();
      expect(find.text('Pick date'), findsOneWidget);

      await closeApp(tester, db);
    });
  }

  test('a fresh entry on another day keeps the time of day', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final day = DateTime(2026, 9);

    final at = container
        .read(
          addTxnControllerProvider(AddTxnArgs.create(TxnType.debit, day: day)),
        )
        .occurredAt;

    expect(dayStart(at), day);
    // The time is now's, moved onto that day.
    expect(
      at.difference(onDay(day, DateTime.now())).inSeconds.abs(),
      lessThan(2),
    );
  });

  test('the location of Add carries the month only when there is one', () {
    expect(addLocation(), '/add');
    expect(addLocation(month: DateTime(2026, 9)), '/add?month=2026-09');
  });
}

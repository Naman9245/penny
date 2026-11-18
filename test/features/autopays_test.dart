import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/autopay_repository.dart';
import 'package:penny/features/autopays/autopays_screen.dart';

import '../helpers/app_harness.dart';

void main() {
  testWidgets('add an autopay by hand', (tester) async {
    final db = await pumpApp(tester);
    routerOf(tester).push('/autopays');
    await tester.pumpAndSettle();
    expect(find.textContaining('No autopays yet'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('autopay-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('autopay-name')),
      'Netflix',
    );
    await tester.tap(find.byKey(const ValueKey('autopay-amount')));
    await tester.pumpAndSettle();
    for (final key in ['1', '9', '9']) {
      await tester.tap(find.byKey(ValueKey('key-$key')).last);
    }
    await tester.tap(find.byKey(const ValueKey('key-done')).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('autopay-save')));
    await tester.tap(find.byKey(const ValueKey('autopay-save')));
    await tester.pumpAndSettle();

    expect(find.text('Netflix'), findsOneWidget);
    expect(
      find.text('₹199 every month · next day not known yet'),
      findsOneWidget,
    );
    expect(find.text('₹199 a month goes out by itself'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets("an autopay's next day shows in Coming up and opens Autopays", (
    tester,
  ) async {
    final soon = DateTime.now().add(const Duration(days: 6));
    final db = await pumpApp(
      tester,
      seedDb: (db) =>
          AutopayRepository(db)
              .add(name: 'Spotify', amountPaise: 13900, nextOn: soon),
    );
    final card = find.byKey(const ValueKey('coming-up'));
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: card, matching: find.text('Spotify')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.textContaining('Autopay')),
      findsWidgets,
    );

    await tester.tap(find.byKey(const ValueKey('coming-up-open-0')));
    await tester.pumpAndSettle();
    expect(find.byType(AutopaysScreen), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('Settings lists the autopays and opens them', (tester) async {
    final db = await pumpApp(
      tester,
      seedDb: (db) =>
          AutopayRepository(db).add(name: 'Spotify', amountPaise: 13900),
    );
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('settings-autopays'));
    expect(
      find.descendant(of: row, matching: find.text('1 autopay')),
      findsOneWidget,
    );
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(AutopaysScreen), findsOneWidget);
    expect(find.text('Spotify'), findsOneWidget);
    await closeApp(tester, db);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/models/txn_enums.dart';

import '../helpers/app_harness.dart';

void main() {
  testWidgets('demo data swaps in made-up money, and yours comes back', (
    tester,
  ) async {
    // The user's own money: one chai, in a database that lasts.
    final files = TempDatabases();
    await tester.runAsync(() async {
      final own = files.open('penny');
      await TxnRepository(own).add(
        amountPaise: 2000,
        type: TxnType.debit,
        categoryId: 'food',
        occurredAt: DateTime.now(),
        merchant: 'Chai point',
      );
      await own.close();
    });
    // A clipboard, to copy a sample SMS and paste it.
    String? clipboard;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          clipboard = (call.arguments as Map)['text'] as String?;
        case 'Clipboard.getData':
          return {'text': clipboard};
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await pumpPenny(
      tester,
      overrides: [databaseOpenerProvider.overrideWithValue(files.open)],
    );
    expect(find.byKey(const ValueKey('demo-banner')), findsNothing);
    await scrollToRecent(tester);
    expect(find.text('Chai point'), findsOneWidget);
    await scrollToTop(tester);

    Future<void> openSettings() async {
      await tester.tap(find.bySemanticsLabel('Settings'));
      await tester.pumpAndSettle();
    }

    Future<void> closeSettings() async {
      // Above the sheet.
      await tester.tapAt(const Offset(200, 30));
      await tester.pumpAndSettle();
    }

    final demoSwitch = find.byKey(const ValueKey('demo-switch'));
    final reset = find.byKey(const ValueKey('demo-reset'));

    await openSettings();
    expect(reset, findsNothing);
    await tester.tap(demoSwitch);
    await tester.pumpAndSettle();
    expect(reset, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sms-copy-0')));
    await tester.pumpAndSettle();
    expect(find.text('Copied'), findsOneWidget);
    await closeSettings();
    expect(find.text('Settings'), findsNothing);

    // The demo, with headphones bought yesterday.
    expect(find.byKey(const ValueKey('demo-banner')), findsOneWidget);
    expect(find.text('Celebrating'), findsOneWidget);
    await scrollToRecent(tester);
    expect(find.text('Chai point'), findsNothing);
    await scrollToTop(tester);

    // The copied sample goes into the demo.
    await tester.tap(find.byKey(const ValueKey('home-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paste-sms')));
    await tester.pumpAndSettle();
    expect(find.text('From your SMS'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('key-done')));
    await tester.pumpAndSettle();
    expect(find.text('Added ₹250 · Food'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Goals'));
    await tester.pumpAndSettle();
    expect(find.text('Delhi trip'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Home'));
    await tester.pumpAndSettle();

    // Reset keeps the demo on, from fresh.
    await tester.tap(find.byKey(const ValueKey('demo-banner')));
    await tester.pumpAndSettle();
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(reset, findsOneWidget);

    // Off again: your own money, as it was.
    await tester.tap(demoSwitch);
    await tester.pumpAndSettle();
    expect(reset, findsNothing);
    await closeSettings();
    expect(find.byKey(const ValueKey('demo-banner')), findsNothing);
    await scrollToRecent(tester);
    expect(find.text('Chai point'), findsOneWidget);
    expect(find.text('Swiggy'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    files.delete();
  });
}

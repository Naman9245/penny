import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_harness.dart';

void main() {
  /// Android's side of "penny/notifications", faked: [allowed] says whether
  /// Penny may read notifications. Returns every method called, in order.
  List<String> fakeAndroid(WidgetTester tester, {required bool allowed}) {
    final calls = <String>[];
    const channel = MethodChannel('penny/notifications');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return switch (call.method) {
        'isEnabled' => allowed,
        'peek' => '[]',
        _ => null,
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    return calls;
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();
  }

  Finder status(String label) => find.descendant(
    of: find.byKey(const ValueKey('notifications-status')),
    matching: find.text(label),
  );

  testWidgets("while it's off, Turn on opens Android's page", (tester) async {
    final calls = fakeAndroid(tester, allowed: false);
    final db = await pumpApp(tester);
    await openSettings(tester);
    expect(status('Off'), findsOneWidget);

    final turnOn = find.byKey(const ValueKey('notifications-settings'));
    await tester.ensureVisible(turnOn);
    await tester.pumpAndSettle();
    await tester.tap(turnOn);
    await tester.pumpAndSettle();
    expect(calls, contains('openSettings'));
    await closeApp(tester, db);
  });

  testWidgets('once on, what happens to a payment is up to you, and '
      'remembered', (tester) async {
    fakeAndroid(tester, allowed: true);
    final db = await pumpApp(tester);
    await openSettings(tester);
    expect(status('On'), findsOneWidget);
    expect(
      find.text('They wait on Home for you to add or skip.'),
      findsOneWidget,
    );

    final save = find.byKey(const ValueKey('capture-save'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
      find.textContaining("They're saved as soon as Penny reads them"),
      findsOneWidget,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('capture_mode'), 'save');
    await closeApp(tester, db);
  });
}

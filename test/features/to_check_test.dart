import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/capture_repository.dart';
import 'package:penny/services/captures.dart';

import '../helpers/app_harness.dart';

void main() {
  // All made up.
  const bankSwiggy =
      'Rs.250.00 debited from A/c XX4821 to SWIGGY. UPI Ref 630512345678.';

  /// Android's side of "penny/notifications", faked, holding [waiting]
  /// notifications until they're dropped. Returns every method called.
  List<String> fakeAndroid(
    WidgetTester tester,
    List<Map<String, Object>> waiting,
  ) {
    final calls = <String>[];
    const channel = MethodChannel('penny/notifications');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'peek':
          return jsonEncode(waiting);
        case 'drop':
          waiting.removeRange(0, call.arguments as int);
        case 'isEnabled':
          return true;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    return calls;
  }

  /// The bank's SMS for ₹250 at Swiggy, now, and GPay's "Rahul Kumar paid
  /// you ₹500" an hour ago, both waiting to be checked.
  Future<void> twoWaiting(db, {String? lookalike}) async {
    final captures = CaptureRepository(db);
    final now = DateTime.now();
    await captures.hold(
      readCapture((app: 'sms', title: 'AX-HDFCBK', text: bankSwiggy, at: now))!,
      app: 'sms',
      at: now,
      lookalike: lookalike,
    );
    final earlier = now.subtract(const Duration(hours: 1));
    await captures.hold(
      readCapture((
        app: 'gpay',
        title: 'Rahul Kumar',
        text: 'Paid you ₹500',
        at: earlier,
      ))!,
      app: 'gpay',
      at: earlier,
    );
  }

  Finder key(String name) => find.byKey(ValueKey(name));

  /// Lets Penny finish taking in notifications, which she starts after the
  /// first frame.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('Add saves it with its category, and Undo puts it back', (
    tester,
  ) async {
    final db = await pumpApp(tester, seedDb: twoWaiting);
    expect(find.text('2 payments to check'), findsOneWidget);
    expect(find.text('−₹250 · Swiggy'), findsOneWidget);

    await tester.tap(key('capture-add-0'));
    await tester.pumpAndSettle();
    expect(find.text('Added ₹250 · Food'), findsOneWidget);
    expect(find.text('1 payment to check'), findsOneWidget);
    await scrollToRecent(tester);
    // Marked as read from a notification.
    expect(find.text('Food · Today · Auto'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    await scrollToTop(tester);
    expect(find.text('2 payments to check'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('Skip hides it, and Undo brings it back', (tester) async {
    final db = await pumpApp(tester, seedDb: twoWaiting);
    await tester.tap(key('capture-skip-1'));
    await tester.pumpAndSettle();
    expect(find.text('Skipped ₹500'), findsOneWidget);
    expect(find.text('1 payment to check'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('2 payments to check'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('without a category, Add opens it to pick one', (tester) async {
    final db = await pumpApp(tester, seedDb: twoWaiting);
    expect(find.textContaining('Pick a category'), findsOneWidget);

    await tester.tap(key('capture-add-1'));
    await tester.pumpAndSettle();
    expect(find.text('Where did it come from?'), findsOneWidget);
    // Below what Penny read, on a phone-sized screen.
    await tester.ensureVisible(find.text('Pocket money'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pocket money'));
    await tester.pumpAndSettle();
    await tester.tap(key('key-done'));
    await tester.pumpAndSettle();

    expect(find.text('Added ₹500 · Pocket money'), findsOneWidget);
    expect(find.text('1 payment to check'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('one that may already be logged says so, Skip first', (
    tester,
  ) async {
    final db = await pumpApp(
      tester,
      seedDb: (db) => twoWaiting(db, lookalike: '₹250 · Lunch at 9:00 AM'),
    );
    expect(find.text('Looks like ₹250 · Lunch at 9:00 AM'), findsOneWidget);
    expect(find.text('Add anyway'), findsOneWidget);
    expect(
      tester.getTopLeft(key('capture-skip-0')).dx,
      lessThan(tester.getTopLeft(key('capture-add-0')).dx),
    );
    await closeApp(tester, db);
  });

  Map<String, Object> notice(String text) => {
    'app': 'sms',
    'title': 'AX-HDFCBK',
    'text': text,
    'at': DateTime.now().millisecondsSinceEpoch,
  };

  testWidgets('as Penny opens, she takes in what waited', (tester) async {
    final calls = fakeAndroid(tester, [
      notice(bankSwiggy),
      notice('Your a/c balance is Rs 1,000'),
    ]);
    final db = await pumpApp(tester);
    await settle(tester);
    expect(find.text('1 payment to check'), findsOneWidget);
    expect(calls, contains('drop'));
    await closeApp(tester, db);
  });

  testWidgets('Save straight away adds it, and Undo holds it instead', (
    tester,
  ) async {
    fakeAndroid(tester, [notice(bankSwiggy)]);
    final db = await pumpApp(tester, prefs: {'capture_mode': 'save'});
    await settle(tester);
    expect(find.text('Added ₹250 · Food from a notification'), findsOneWidget);
    expect(key('to-check'), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('1 payment to check'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('with demo data on, they wait for your own money', (
    tester,
  ) async {
    final calls = fakeAndroid(tester, [notice(bankSwiggy)]);
    final db = await pumpApp(tester, prefs: {'demo_mode': true});
    await settle(tester);
    expect(key('to-check'), findsNothing);
    expect(calls, isNot(contains('peek')));
    await closeApp(tester, db);
  });
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/capture_repository.dart';
import 'package:penny/data/prefs_repository.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/services/captures.dart';

import '../helpers/app_harness.dart';

void main() {
  // All made up.
  const bankSwiggy =
      'Rs.250.00 debited from A/c XX4821 to SWIGGY. UPI Ref 630512345678.';

  /// Android's side of "penny/notifications", faked, holding [waiting]
  /// notifications until they're dropped, and putting what Penny's
  /// notification would say in [notified]. Returns every method called.
  List<String> fakeAndroid(
    WidgetTester tester,
    List<Map<String, Object>> waiting, {
    List<Object?>? notified,
  }) {
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
        case 'isEnabled' || 'canNotify':
          return true;
        case 'notify':
          notified?.add(call.arguments);
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
    // The second row can sit under the nav bar on a phone-sized screen.
    await tapInView(tester, key('capture-skip-1'));
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

    // The second row can sit under the nav bar on a phone-sized screen.
    await tapInView(tester, key('capture-add-1'));
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
    // On screen, so a message at the bottom says so.
    expect(find.text('Penny read −₹250 · Swiggy'), findsOneWidget);
    expect(calls, contains('drop'));
    // Any the listener missed are looked for first.
    expect(calls.indexOf('catchUp'), lessThan(calls.indexOf('peek')));
    expect(calls, isNot(contains('notify')));
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

  /// Android saying Penny went behind another app, or came back.
  Future<void> lifecycle(WidgetTester tester, AppLifecycleState state) =>
      tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.lifecycle.name,
        const StringCodec().encodeMessage(state.toString()),
        (_) {},
      );

  /// Android calling [method] on "penny/notifications": "captured" when
  /// more are waiting, "openHome" when Penny's notification is tapped.
  Future<void> fromAndroid(WidgetTester tester, String method) =>
      tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'penny/notifications',
        const StandardMethodCodec().encodeMethodCall(MethodCall(method)),
        (_) {},
      );

  testWidgets('away from Penny, her own notification says what she read', (
    tester,
  ) async {
    final waiting = <Map<String, Object>>[];
    final notified = <Object?>[];
    fakeAndroid(tester, waiting, notified: notified);
    final db = await pumpApp(tester);
    await settle(tester);

    // Still running, behind another app.
    await lifecycle(tester, AppLifecycleState.paused);
    waiting.addAll([
      notice(bankSwiggy),
      notice('OTP is 482913 for txn of INR 649.00 at ZOMATO.'),
    ]);
    await fromAndroid(tester, 'captured');
    await settle(tester);
    expect(notified, [
      {
        'title': 'Penny read −₹250 · Swiggy',
        'text': "🍔 Food? It's waiting on Home: add it or skip it.",
        'lines': <String>[],
      },
    ]);

    // Only an OTP: nothing to tell.
    waiting.add(notice('OTP is 771204 for txn of INR 99.00.'));
    await fromAndroid(tester, 'captured');
    await settle(tester);
    expect(notified, hasLength(1));

    // Tapped, from another screen: Penny opens on Home, where it waits.
    routerOf(tester).go('/analysis');
    await lifecycle(tester, AppLifecycleState.resumed);
    await fromAndroid(tester, 'openHome');
    await settle(tester);
    expect(find.text('1 payment to check'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('what her hidden copy read shows as soon as it says so', (
    tester,
  ) async {
    fakeAndroid(tester, []);
    // One database file, as on the phone: the open Penny has one
    // connection, her hidden copy another.
    final files = TempDatabases();
    await pumpPenny(
      tester,
      overrides: [databaseOpenerProvider.overrideWithValue(files.open)],
    );
    await settle(tester);
    expect(key('to-check'), findsNothing);

    await tester.runAsync(() async {
      final hidden = files.open('penny');
      final now = DateTime.now();
      await CaptureRepository(hidden).hold(
        readCapture((app: 'sms', title: 'AX-HDFCBK', text: bankSwiggy, at: now))!,
        app: 'sms',
        at: now,
      );
      await hidden.close();
    });
    await fromAndroid(tester, 'refresh');
    await settle(tester);
    expect(find.text('1 payment to check'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      files.delete();
    });
  });

  testWidgets("a message Penny couldn't read waits, numbers hidden, and "
      'Skip lets it go', (tester) async {
    fakeAndroid(tester, []);
    final db = await pumpApp(
      tester,
      seedDb: (db) => PrefsRepository(db).setUnread([
        (
          app: 'sms',
          title: 'JM-HDFCBK',
          text: 'PayZapp: ₹1.00 moved to AMIT SHARMA. Ref 630512340001',
          at: DateTime.now(),
        ),
      ]),
    );
    await settle(tester);
    expect(find.text('1 message to read'), findsOneWidget);
    final row = tester.widget<Text>(find.byKey(const ValueKey('unread-0')));
    expect(row.data, contains('Ref ••••••••••••'));

    await tester.tap(key('unread-skip-0'));
    await tester.pumpAndSettle();
    expect(key('to-check'), findsNothing);
    await closeApp(tester, db);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:penny/data/prefs_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_harness.dart';

void main() {
  /// Android's side of "penny/notifications", faked: [allowed] says whether
  /// Penny may read notifications, and [notifies] whether she may post her
  /// own. What each ask to notify was called with goes in [asked]. Returns
  /// every method called, in order.
  List<String> fakeAndroid(
    WidgetTester tester, {
    required bool allowed,
    bool notifies = true,
    bool sms = false,
    List<Object?>? asked,
    List<Map<String, Object?>> lookBack = const [],
  }) {
    var batch = 0;
    final calls = <String>[];
    const channel = MethodChannel('penny/notifications');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'askToNotify') asked?.add(call.arguments);
      return switch (call.method) {
        'isEnabled' => allowed,
        'canNotify' => notifies,
        'smsAllowed' => sms,
        'askToNotify' => false,
        'peek' => '[]',
        'lookBack' =>
          batch < lookBack.length
              ? lookBack[batch++]
              : {'kept': 0, 'until': null, 'done': true},
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

  testWidgets("while it's off, Turn on asks whether Penny may notify, then "
      "opens Android's page", (tester) async {
    final asked = <Object?>[];
    final calls = fakeAndroid(tester, allowed: false, asked: asked);
    final db = await pumpApp(tester);
    await openSettings(tester);
    expect(status('Off'), findsOneWidget);

    final turnOn = find.byKey(const ValueKey('notifications-settings'));
    await tester.ensureVisible(turnOn);
    await tester.pumpAndSettle();
    await tester.tap(turnOn);
    await tester.pumpAndSettle();
    expect(calls, containsAllInOrder(['askToNotify', 'openSettings']));
    // Only Android's own question: never a settings page first.
    expect(asked, [false]);
    await closeApp(tester, db);
  });

  testWidgets('once on, what happens to a payment is up to you, and '
      'remembered', (tester) async {
    fakeAndroid(tester, allowed: true);
    final db = await pumpApp(tester);
    await openSettings(tester);
    expect(status('On'), findsOneWidget);
    expect(find.byKey(const ValueKey('notifications-allow')), findsNothing);
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

  testWidgets("with Penny's own notifications off, Allow notifications asks "
      'for them', (tester) async {
    final asked = <Object?>[];
    fakeAndroid(tester, allowed: true, notifies: false, asked: asked);
    final db = await pumpApp(tester);
    await openSettings(tester);
    await tapInView(tester, find.byKey(const ValueKey('notifications-allow')));
    // Android's question, or else her notification settings.
    expect(asked, [true]);
    await closeApp(tester, db);
  });

  testWidgets('What Penny read lists the last she looked at, newest first', (
    tester,
  ) async {
    fakeAndroid(tester, allowed: true);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 14, 31);
    final yesterday = DateTime(now.year, now.month, now.day - 1, 18, 15);
    final db = await pumpApp(
      tester,
      seedDb: (db) => PrefsRepository(db).noteCaptures([
        (
          key: 'metro',
          app: 'gpay',
          at: yesterday,
          outcome: 'saved',
          what: '−₹60 · Metro',
        ),
        for (var i = 0; i < 4; i++)
          (
            key: 'otp-$i',
            app: 'sms',
            at: today,
            outcome: 'letGo',
            what: 'an OTP',
          ),
        (
          key: 'swiggy',
          app: 'sms',
          at: today,
          outcome: 'waiting',
          what: '−₹250 · Swiggy',
        ),
      ]),
    );
    await openSettings(tester);
    final time = DateFormat('h:mm a');
    final newest = find.text(
      '${time.format(today)} · SMS · Waiting: −₹250 · Swiggy',
      findRichText: true,
    );
    await tapInView(tester, find.byKey(const ValueKey('read-all')));
    expect(newest, findsOneWidget);
    expect(
      find.text(
        '${time.format(today)} · SMS · Let go: an OTP',
        findRichText: true,
      ),
      findsNWidgets(4),
    );
    expect(
      find.text(
        '${DateFormat('d MMM').format(yesterday)}, ${time.format(yesterday)} '
        '· GPay · Saved: −₹60 · Metro',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('Show fewer'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('before Penny has read anything, it says so', (tester) async {
    fakeAndroid(tester, allowed: true);
    final db = await pumpApp(tester);
    await openSettings(tester);
    final none = find.byKey(const ValueKey('read-none'));
    await tapInView(tester, none);
    expect(none, findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('reading bank SMS: Allow asks Android', (tester) async {
    final calls = fakeAndroid(tester, allowed: true);
    final db = await pumpApp(tester);
    await openSettings(tester);
    await tapInView(tester, find.byKey(const ValueKey('sms-allow')));
    expect(calls, contains('askSms'));
    await closeApp(tester, db);
  });

  testWidgets('reading bank SMS: On once allowed', (tester) async {
    fakeAndroid(tester, allowed: true, sms: true);
    final db = await pumpApp(tester);
    await openSettings(tester);
    final on = find.byKey(const ValueKey('sms-status'));
    await tapInView(tester, on);
    expect(on, findsOneWidget);
    expect(find.byKey(const ValueKey('sms-allow')), findsNothing);
    await closeApp(tester, db);
  });

  testWidgets('reading bank SMS: the last 3 months, a batch at a time', (
    tester,
  ) async {
    final calls = fakeAndroid(
      tester,
      allowed: true,
      sms: true,
      lookBack: [
        {'kept': 100, 'until': 1762000000000, 'done': false},
        {'kept': 3, 'until': 1762900000000, 'done': true},
      ],
    );
    final db = await pumpApp(tester);
    await openSettings(tester);
    await tapInView(tester, find.byKey(const ValueKey('sms-look-back')));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c == 'lookBack'), hasLength(2));
    expect(
      find.text(
        "Penny found 103 payment messages from the last 3 months. They're "
        'on Home.',
      ),
      findsOneWidget,
    );
    await closeApp(tester, db);
  });
}

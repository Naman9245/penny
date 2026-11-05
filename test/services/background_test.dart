import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/background.dart';
import 'package:penny/data/capture_repository.dart';
import 'package:penny/data/prefs_repository.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/captures.dart';
import 'package:penny/services/notification_inbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // All made up.
  const bankSwiggy =
      'Rs.250.00 debited from A/c XX4821 to SWIGGY. UPI Ref 630512345678.';
  const otp = 'OTP is 482913 for txn of INR 649.00 at ZOMATO.';
  Map<String, Object> notice(String app, String title, String text) => {
    'app': app,
    'title': title,
    'text': text,
    'at': DateTime.now().millisecondsSinceEpoch,
  };

  late TempDatabases files;
  setUp(() => files = TempDatabases());
  tearDown(() => files.delete());

  /// Android's side of the hidden copy's "penny/notifications": what's
  /// waiting at first, then what arrives while she reads, a batch each time
  /// she asks whether there's more. Returns the methods called, and what
  /// her notification would say.
  ({List<String> calls, List<Object?> notified}) fakeAndroid(
    List<List<Map<String, Object>>> batches,
  ) {
    final calls = <String>[];
    final notified = <Object?>[];
    var waiting = batches.isEmpty ? <Map<String, Object>>[] : batches.first;
    final later = batches.skip(1).toList();
    const channel = MethodChannel('penny/notifications');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'peek':
          return jsonEncode(waiting);
        case 'drop':
          waiting = waiting.sublist(call.arguments as int);
        case 'again':
          if (later.isEmpty) return false;
          waiting = [...waiting, ...later.removeAt(0)];
          return true;
        case 'notify':
          notified.add(call.arguments);
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    return (calls: calls, notified: notified);
  }

  Future<List<CaptureRead>> read(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    return readWaiting(
      inbox: NotificationInbox(),
      prefs: await SharedPreferences.getInstance(),
      open: files.open,
    );
  }

  test('reads what waited into your own money, goes round again for what '
      'came meanwhile, and says it once', () async {
    final android = fakeAndroid([
      [notice('sms', 'AX-HDFCBK', bankSwiggy), notice('sms', 'AX-HDFCBK', otp)],
      [notice('gpay', 'Rahul Kumar', 'Paid you ₹500')],
    ]);
    final reads = await read({'capture_mode': 'save'});
    expect(
      [for (final r in reads) r.outcome],
      [CaptureOutcome.saved, CaptureOutcome.letGo, CaptureOutcome.saved],
    );
    expect(android.calls.where((c) => c == 'drop'), hasLength(2));
    expect(android.notified, [
      {
        'title': 'Penny read 2 payments',
        'text': '2 saved',
        'lines': [
          '−₹250 · Swiggy · 🍔 Food',
          '+₹500 · Rahul Kumar · 🤝 From people',
        ],
      },
    ]);
    expect(files.opened, ['penny']);

    // What she wrote is there when Penny opens.
    final db = files.open('penny');
    final entries = await db.select(db.txns).get();
    expect(
      {for (final e in entries) e.merchant: (e.source, e.categoryId)},
      {
        'Swiggy': (TxnSource.sms, 'food'),
        'Rahul Kumar': (TxnSource.sms, 'from_people'),
      },
    );
    expect(await CaptureRepository(db).watchWaiting().first, isEmpty);
    final log = await PrefsRepository(db).watchCaptureLog().first;
    expect([for (final e in log) e.outcome], ['saved', 'letGo', 'saved']);
    await db.close();
  });

  test('waiting to be checked unless you chose otherwise', () async {
    final android = fakeAndroid([
      [notice('sms', 'AX-HDFCBK', bankSwiggy)],
    ]);
    final reads = await read({});
    expect([for (final r in reads) r.outcome], [CaptureOutcome.waiting]);
    expect(android.notified, [
      {
        'title': 'Penny read −₹250 · Swiggy',
        'text': "🍔 Food? It's waiting on Home: add it or skip it.",
        'lines': <String>[],
      },
    ]);
  });

  test('only what she lets go: nothing to tell', () async {
    final android = fakeAndroid([
      [notice('sms', 'AX-HDFCBK', otp)],
    ]);
    final reads = await read({});
    expect([for (final r in reads) r.outcome], [CaptureOutcome.letGo]);
    expect(android.calls, isNot(contains('notify')));
  });

  test('with demo data on, they wait for your own money', () async {
    final android = fakeAndroid([
      [notice('sms', 'AX-HDFCBK', bankSwiggy)],
    ]);
    expect(await read({'demo_mode': true}), isEmpty);
    expect(android.calls, isEmpty);
    expect(files.opened, isEmpty);
  });
}

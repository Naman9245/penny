import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/services/sms_parser.dart';

import '../helpers/app_harness.dart';

// Made up, in HDFC's real format.
const _hdfcSwiggy =
    'Sent Rs.250.00\nFrom HDFC Bank A/C *4821\nTo SWIGGY\n'
    'On 01/11/26\nRef 630512345678\nNot You?\n'
    'Call 18002586161/SMS BLOCK UPI to 7308080808';
const _otp =
    'OTP is 482913 for txn of INR 649.00 at ZOMATO on HDFC Bank card '
    'ending 9034. Do not share OTP for security reasons.';

Future<void> openImport(WidgetTester tester, String sms) async {
  routerOf(tester).push('/import', extra: parseSms(sms));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a shared SMS opens a filled-in review; the tick saves it', (
    tester,
  ) async {
    final db = await pumpApp(tester);

    await openImport(tester, _hdfcSwiggy);

    expect(find.text('From your SMS'), findsOneWidget);
    expect(find.text('₹250'), findsOneWidget);
    // Swiggy was read and Food suggested, so it's ready for the tick.
    expect(
      find.text('Check what Penny read, then tap the tick'),
      findsOneWidget,
    );
    // The reference number was blanked before anything was shown.
    expect(
      find.textContaining('630512345678', findRichText: true),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('key-done')));
    await tester.pumpAndSettle();

    expect(find.text('Added ₹250 · Food'), findsOneWidget);
    expect(find.text('Swiggy'), findsOneWidget);
    expect(find.textContaining('· SMS'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('the same SMS twice: the second time says already added', (
    tester,
  ) async {
    final db = await pumpApp(tester);
    await openImport(tester, _hdfcSwiggy);
    await tester.tap(find.byKey(const ValueKey('key-done')));
    await tester.pumpAndSettle();

    await openImport(tester, _hdfcSwiggy);

    expect(find.text('Already added'), findsOneWidget);
    expect(find.text('Open it'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('an OTP is refused with the reason and nothing is saved', (
    tester,
  ) async {
    final db = await pumpApp(tester);

    await openImport(tester, _otp);

    expect(find.text('Not a payment'), findsOneWidget);
    expect(find.text(IgnoreReason.otp.explanation), findsOneWidget);
    await tester.tap(find.text('Close').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing logged yet'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('an SMS shared from Messages opens straight into its review', (
    tester,
  ) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    const channel = MethodChannel('penny/share');
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'takeSharedText') return _hdfcSwiggy;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final db = await pumpApp(tester);

    expect(find.text('From your SMS'), findsOneWidget);
    expect(find.text('₹250'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('Paste SMS turns a copied message into a review', (tester) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': _hdfcSwiggy};
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final db = await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('home-add')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('paste-sms')));
    await tester.pumpAndSettle();

    expect(find.text('From your SMS'), findsOneWidget);
    expect(find.text('₹250'), findsOneWidget);
    await closeApp(tester, db);
  });
}

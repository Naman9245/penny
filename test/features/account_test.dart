import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/account.dart';
import 'package:penny/data/sync/sync_controller.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/models/txn_enums.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_account_service.dart';
import '../helpers/fake_sync_remote.dart';

void main() {
  Future<void> addChai(TxnRepository repo) => repo.add(
    amountPaise: 2000,
    type: TxnType.debit,
    categoryId: 'food',
    occurredAt: DateTime.now(),
    merchant: 'Chai point',
  );

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-backup')));
    await tester.pumpAndSettle();
  }

  // What the backup card says; the Settings list under it names it too.
  Finder inCard(String text) => find.descendant(
    of: find.byKey(const ValueKey('account-card')),
    matching: find.text(text),
  );

  Future<void> tap(WidgetTester tester, String key) =>
      tapInView(tester, find.byKey(ValueKey(key)));

  testWidgets("a build without Google's id says backup isn't set up", (
    tester,
  ) async {
    final db = await pumpApp(
      tester,
      overrides: [
        accountServiceProvider.overrideWithValue(
          FakeAccountService(canSignIn: false),
        ),
      ],
    );
    await openSettings(tester);
    expect(inCard('Back up with Google'), findsOneWidget);
    expect(find.text("Backup isn't set up in this build."), findsOneWidget);
    expect(find.byKey(const ValueKey('google-sign-in')), findsNothing);
    await closeApp(tester, db);
  });

  testWidgets('sign in with Google: the money here goes up; signing out '
      'keeps it here', (tester) async {
    final remote = FakeSyncRemote();
    final db = await pumpApp(
      tester,
      seed: addChai,
      overrides: [
        accountServiceProvider.overrideWithValue(FakeAccountService()),
        syncRemoteProvider.overrideWithValue(remote),
      ],
    );
    await openSettings(tester);
    await tap(tester, 'google-sign-in');

    expect(find.text('Backed up'), findsOneWidget);
    expect(inCard('me@example.com'), findsOneWidget);
    expect(find.text('Synced just now'), findsOneWidget);
    expect(remote.rows('txns').values.single['merchant'], 'Chai point');

    await tap(tester, 'sign-out');
    expect(inCard('Back up with Google'), findsOneWidget);
    expect(await db.select(db.txns).get(), hasLength(1));
    await closeApp(tester, db);
  });

  testWidgets('a sign-in that fails says so', (tester) async {
    final db = await pumpApp(
      tester,
      overrides: [
        accountServiceProvider.overrideWithValue(
          FakeAccountService()..offline = true,
        ),
      ],
    );
    await openSettings(tester);
    await tap(tester, 'google-sign-in');
    expect(find.byKey(const ValueKey('account-problem')), findsOneWidget);
    expect(inCard('Back up with Google'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('deleting the account can clear this phone too', (tester) async {
    final accounts = FakeAccountService(
      signedIn: const Account(id: 'account-1', email: 'me@example.com'),
    );
    final db = await pumpApp(
      tester,
      seed: addChai,
      overrides: [
        accountServiceProvider.overrideWithValue(accounts),
        syncRemoteProvider.overrideWithValue(FakeSyncRemote()),
      ],
    );
    await openSettings(tester);
    await tap(tester, 'delete-account');
    expect(find.text('Delete your account?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('delete-clear-phone')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-confirm')));
    await tester.pumpAndSettle();

    expect(accounts.deleted, 1);
    expect(inCard('Back up with Google'), findsOneWidget);
    expect(await db.select(db.txns).get(), isEmpty);
    await closeApp(tester, db);
  });
}

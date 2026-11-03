import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/account.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/data/sync/sync_controller.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_account_service.dart';
import '../helpers/fake_sync_remote.dart';

void main() {
  const me = Account(id: 'account-1', email: 'me@example.com');
  late AppDatabase db;
  late FakeSyncRemote remote;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    remote = FakeSyncRemote();
  });
  tearDown(() => db.close());

  Future<void> addChai([int rupees = 20]) => TxnRepository(db).add(
    amountPaise: rupees * 100,
    type: TxnType.debit,
    categoryId: 'food',
    occurredAt: DateTime(2026, 11, 3, 9),
    merchant: 'Chai point',
  );

  Future<ProviderContainer> start({
    Account? signedIn,
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final shared = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(shared),
        appDatabaseProvider.overrideWithValue(db),
        accountServiceProvider.overrideWithValue(
          FakeAccountService(signedIn: signedIn),
        ),
        syncRemoteProvider.overrideWithValue(remote),
        syncSettleProvider.overrideWithValue(const Duration(milliseconds: 20)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Waits until the backup is [phase].
  Future<SyncStatus> until(ProviderContainer container, SyncPhase phase) {
    final reached = Completer<SyncStatus>();
    final listening = container.listen(syncControllerProvider, (_, status) {
      if (status.phase == phase && !reached.isCompleted) {
        reached.complete(status);
      }
    }, fireImmediately: true);
    return reached.future
        .timeout(const Duration(seconds: 5))
        .whenComplete(listening.close);
  }

  Future<void> eventually(bool Function() done) async {
    for (var i = 0; i < 250 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(done(), isTrue);
  }

  test('no account: off, and nothing leaves the phone', () async {
    await addChai();
    final container = await start();
    container.read(syncControllerProvider);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(container.read(syncControllerProvider).phase, SyncPhase.off);
    expect(remote.sent, isEmpty);
  });

  test('signed in, it syncs at once, then soon after each change', () async {
    await addChai();
    final container = await start(signedIn: me);
    final synced = await until(container, SyncPhase.synced);
    expect(synced.lastSynced, isNotNull);
    expect(remote.rows('txns'), hasLength(1));

    await addChai(30);
    await eventually(() => remote.rows('txns').length == 2);
  });

  test('demo data pauses it', () async {
    await addChai();
    final container = await start(signedIn: me, prefs: {'demo_mode': true});
    await until(container, SyncPhase.paused);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(remote.sent, isEmpty);
  });

  test('offline, it says so, and catches up once back', () async {
    remote.offline = true;
    await addChai();
    final container = await start(signedIn: me);
    await until(container, SyncPhase.offline);

    remote.offline = false;
    await container.read(syncControllerProvider.notifier).syncNow();
    expect(container.read(syncControllerProvider).phase, SyncPhase.synced);
    expect(remote.rows('txns'), hasLength(1));
  });
}

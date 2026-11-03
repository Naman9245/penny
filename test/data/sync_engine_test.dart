import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/budget_repository.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/goal_repository.dart';
import 'package:penny/data/prefs_repository.dart';
import 'package:penny/data/rules_repository.dart';
import 'package:penny/data/sync/sync_engine.dart';
import 'package:penny/data/sync/sync_remote.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/models/rule_kind.dart';
import 'package:penny/models/txn_enums.dart';

import '../helpers/fake_sync_remote.dart';

void main() {
  final start = DateTime(2026, 11, 3, 10);
  late DateTime now;
  late AppDatabase db;
  late FakeSyncRemote remote;
  late SyncEngine engine;

  DateTime clock() => now;
  String iso(DateTime at) => at.toUtc().toIso8601String();

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    now = start;
    db = AppDatabase(NativeDatabase.memory());
    remote = FakeSyncRemote();
    engine = SyncEngine(db, remote, clock: clock);
  });
  tearDown(() => db.close());

  Future<int> waiting() => engine.watchWaiting().first;
  TxnRepository txns() => TxnRepository(db, clock: clock);

  Future<String> addFood({int rupees = 250, String? dedupeKey}) => txns().add(
    amountPaise: rupees * 100,
    type: TxnType.debit,
    categoryId: 'food',
    occurredAt: start,
    merchant: 'Swiggy',
    dedupeKey: dedupeKey,
  );

  /// A budget row for [category] as another phone would send it.
  Map<String, Object?> budgetRow(String id, String category, DateTime at) => {
    'id': id,
    'budget_key': category,
    'amount_paise': 300000,
    'created_at': iso(at),
    'updated_at': iso(at),
    'deleted_at': null,
  };

  test('a first sync sends everything here, and nothing that stays', () async {
    final id = await addFood(dedupeKey: 'sms-fingerprint');
    await BudgetRepository(db, clock: clock).setAmount('food', 500000);
    final goals = GoalRepository(db, clock: clock);
    final goal = await goals.add(
      title: 'Delhi trip',
      targetPaise: 1500000,
      deadline: DateTime(2027, 2, 1),
    );
    await goals.deposit(goal, 200000);
    await RulesRepository(
      db,
      clock: clock,
    ).set(RuleKind.shop, 'swiggy', TxnTag.wasteful);
    await PrefsRepository(db, clock: clock).setNote('Student in a PG');
    expect(await waiting(), 6);

    await engine.sync('account-1');

    final txn = remote.rows('txns')[id]!;
    expect(txn['merchant'], 'Swiggy');
    expect(txn['amount_paise'], 25000);
    expect(txn['occurred_at'], iso(start));
    expect(txn.containsKey('dedupe_key'), isFalse);
    expect(txn.containsKey('dirty'), isFalse);
    expect(remote.rows('budgets'), hasLength(1));
    expect(remote.rows('goals').values.single['title'], 'Delhi trip');
    expect(remote.rows('goal_deposits'), hasLength(1));
    expect(remote.rows('tag_rules').values.single['rule_key'], 'swiggy');
    expect(remote.rows('prefs')['note']!['value'], 'Student in a PG');
    // The chat, reports and plans have no table to go to.
    expect(
      remote.sent.keys,
      unorderedEquals([
        'txns',
        'budgets',
        'goals',
        'goal_deposits',
        'tag_rules',
        'prefs',
      ]),
    );
    expect(await waiting(), 0);
  });

  test('the newer edit wins, here and in the copy', () async {
    final id = await addFood();
    await engine.sync('account-1');

    // Another phone changes it later: it comes down, and isn't sent back.
    now = start.add(const Duration(hours: 1));
    remote.put('txns', {
      ...remote.rows('txns')[id]!,
      'amount_paise': 30000,
      'updated_at': iso(now),
    });
    await engine.sync('account-1');
    expect((await txns().findById(id))!.amountPaise, 30000);
    expect(await waiting(), 0);

    // An edit here, later still, goes up.
    now = start.add(const Duration(hours: 2));
    final txn = (await txns().findById(id))!;
    await txns().update(
      id,
      amountPaise: 40000,
      type: txn.type,
      categoryId: txn.categoryId,
      occurredAt: txn.occurredAt,
      merchant: txn.merchant,
      tag: txn.tag,
      payeeIsPerson: txn.payeeIsPerson,
    );
    await engine.sync('account-1');
    expect(remote.rows('txns')[id]!['amount_paise'], 40000);

    // An older copy arriving later doesn't undo it.
    remote.put('txns', {
      ...remote.rows('txns')[id]!,
      'id': id,
      'amount_paise': 1,
      'updated_at': iso(start),
    });
    await engine.sync('account-1');
    expect((await txns().findById(id))!.amountPaise, 40000);
  });

  test('deletes travel both ways', () async {
    final mine = await addFood();
    final theirs = await addFood(rupees: 90);
    await engine.sync('account-1');

    now = start.add(const Duration(minutes: 5));
    await txns().softDelete(mine);
    remote.put('txns', {
      ...remote.rows('txns')[theirs]!,
      'deleted_at': iso(now),
      'updated_at': iso(now),
    });
    await engine.sync('account-1');

    expect(remote.rows('txns')[mine]!['deleted_at'], iso(now));
    expect(await txns().findById(theirs), isNull);
    expect(await waiting(), 0);
  });

  test("two phones' budgets for one category leave the newer one", () async {
    // Here at 10:00; another phone's, for the same category, at 11:00.
    await BudgetRepository(db, clock: clock).setAmount('food', 500000);
    final ours = (await db.select(db.budgets).get()).single.id;
    const theirs = '0192f0c0-0000-7000-8000-00000000b002';
    remote.put(
      'budgets',
      budgetRow(theirs, 'food', start.add(const Duration(hours: 1))),
    );
    now = start.add(const Duration(hours: 2));

    await engine.sync('account-1');

    final live = await BudgetRepository(db).watch().first;
    expect(live.byCategory, {'food': 300000});
    expect(remote.rows('budgets')[ours]!['deleted_at'], isNotNull);
    expect(remote.rows('budgets')[theirs]!['deleted_at'], isNull);
    expect(await waiting(), 0);
  });

  test("an older budget from another phone is the one retired", () async {
    now = start.add(const Duration(hours: 1));
    await BudgetRepository(db, clock: clock).setAmount('food', 500000);
    const theirs = '0192f0c0-0000-7000-8000-00000000b003';
    remote.put('budgets', budgetRow(theirs, 'food', start));

    await engine.sync('account-1');

    final live = await BudgetRepository(db).watch().first;
    expect(live.byCategory, {'food': 500000});
    expect(remote.rows('budgets')[theirs]!['deleted_at'], isNotNull);
  });

  test('another account gets everything here, and its copy whole', () async {
    final id = await addFood();
    await engine.sync('account-1');

    final other = FakeSyncRemote()
      ..put('txns', {
        ...remote.rows('txns')[id]!,
        'id': '0192f0c0-0000-7000-8000-00000000c001',
      });
    await SyncEngine(db, other, clock: clock).sync('account-2');

    expect(other.rows('txns'), contains(id));
    expect(await db.select(db.txns).get(), hasLength(2));
  });

  test('offline, nothing is lost: the next sync sends it', () async {
    final id = await addFood();
    remote.offline = true;
    await expectLater(
      engine.sync('account-1'),
      throwsA(
        isA<SyncException>().having(
          (e) => e.failure,
          'failure',
          SyncFailure.offline,
        ),
      ),
    );
    expect(await waiting(), 1);

    remote.offline = false;
    await engine.sync('account-1');
    expect(remote.rows('txns'), contains(id));
    expect(await waiting(), 0);
  });

  test('the note travels as "note", and so does clearing it', () async {
    final prefs = PrefsRepository(db, clock: clock);
    await prefs.setNote('Saving for Delhi');
    await engine.sync('account-1');
    expect(remote.rows('prefs')['note']!['value'], 'Saving for Delhi');

    now = start.add(const Duration(minutes: 1));
    await prefs.setNote('');
    await engine.sync('account-1');
    expect(remote.rows('prefs')['note']!['value'], '');
    expect(await prefs.watchNote().first, isNull);

    now = start.add(const Duration(minutes: 2));
    remote.put('prefs', {
      'name': 'note',
      'value': 'From my other phone',
      'updated_at': iso(now),
    });
    await engine.sync('account-1');
    expect(await prefs.watchNote().first, 'From my other phone');
  });

  test('a big copy comes down in pages', () async {
    for (var i = 0; i < SyncEngine.batch * 2 + 1; i++) {
      remote.put('txns', {
        'id': '0192f0c0-0000-7000-8000-${i.toString().padLeft(12, '0')}',
        'amount_paise': 100 + i,
        'type': 'debit',
        'category_id': 'food',
        'merchant': null,
        'occurred_at': iso(start),
        'source': 'manual',
        'tag': null,
        'payee_is_person': null,
        'created_at': iso(start),
        'updated_at': iso(start),
        'deleted_at': null,
      });
    }
    await engine.sync('account-1');
    expect(await db.select(db.txns).get(), hasLength(SyncEngine.batch * 2 + 1));
    expect(await waiting(), 0);
  });
}

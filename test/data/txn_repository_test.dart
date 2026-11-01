import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/models/txn_enums.dart';

void main() {
  late AppDatabase db;
  late TxnRepository repo;
  late DateTime clock;

  setUp(() {
    clock = DateTime(2026, 11, 1, 10);
    db = AppDatabase(NativeDatabase.memory());
    repo = TxnRepository(db, clock: () => clock);
  });

  tearDown(() => db.close());

  Future<String> add(int paise, DateTime at, {TxnType type = TxnType.debit}) {
    return repo.add(
      amountPaise: paise,
      type: type,
      categoryId: 'food',
      occurredAt: at,
    );
  }

  test('add, then watchMonth returns the entry', () async {
    final id = await add(25000, DateTime(2026, 11, 1, 9));

    final rows = await repo.watchMonth(DateTime(2026, 11)).first;

    expect(rows.single.id, id);
    expect(rows.single.amountPaise, 25000);
    expect(rows.single.source, TxnSource.manual);
    expect(rows.single.createdAt, clock);
    expect(rows.single.deletedAt, isNull);
  });

  test('a month starts at midnight on the 1st', () async {
    await add(100, DateTime(2026, 10, 31, 23, 59, 59));
    await add(200, DateTime(2026, 11, 1));

    final november = await repo.watchMonth(DateTime(2026, 11)).first;
    final october = await repo.watchMonth(DateTime(2026, 10)).first;

    expect(november.map((t) => t.amountPaise), [200]);
    expect(october.map((t) => t.amountPaise), [100]);
  });

  test('soft-deleted entries are hidden everywhere until restored', () async {
    final id = await add(25000, DateTime(2026, 11, 1, 9));

    await repo.softDelete(id);

    expect(await repo.watchMonth(DateTime(2026, 11)).first, isEmpty);
    expect(await repo.watchRecent().first, isEmpty);
    expect(await repo.findById(id), isNull);
    final summary = await repo.watchMonthSummary(DateTime(2026, 11)).first;
    expect(summary.spentPaise, 0);

    await repo.restore(id);

    final restored = await repo.findById(id);
    expect(restored, isNotNull);
    expect(restored!.deletedAt, isNull);
  });

  test('the summary totals spending and income separately', () async {
    await add(25000, DateTime(2026, 11, 1, 9));
    await add(10050, DateTime(2026, 11, 2, 9));
    await add(500000, DateTime(2026, 11, 3, 9), type: TxnType.credit);
    await add(99900, DateTime(2026, 10, 30)); // Last month.

    final summary = await repo.watchMonthSummary(DateTime(2026, 11)).first;

    expect(summary.spentPaise, 35050);
    expect(summary.gotPaise, 500000);
    expect(summary.leftPaise, 464950);
  });

  test('update changes the fields and stamps updatedAt', () async {
    final id = await add(25000, DateTime(2026, 11, 1, 9));
    clock = DateTime(2026, 11, 1, 11);

    await repo.update(
      id,
      amountPaise: 30000,
      type: TxnType.debit,
      categoryId: 'travel',
      occurredAt: DateTime(2026, 10, 31, 9),
      merchant: 'Metro',
      tag: TxnTag.necessary,
      payeeIsPerson: false,
    );

    final txn = (await repo.findById(id))!;
    expect(txn.amountPaise, 30000);
    expect(txn.categoryId, 'travel');
    expect(txn.merchant, 'Metro');
    expect(txn.occurredAt, DateTime(2026, 10, 31, 9));
    expect(txn.tag, TxnTag.necessary);
    expect(txn.payeeIsPerson, isFalse);
    expect(txn.createdAt, DateTime(2026, 11, 1, 10));
    expect(txn.updatedAt, DateTime(2026, 11, 1, 11));
  });

  test('setTags tags several entries at once, and can clear them', () async {
    final a = await add(100, DateTime(2026, 11, 1, 9));
    final b = await add(200, DateTime(2026, 11, 2, 9));
    final c = await add(300, DateTime(2026, 11, 3, 9));
    clock = DateTime(2026, 11, 3, 12);

    await repo.setTags({a: TxnTag.necessary, b: TxnTag.wasteful});
    expect((await repo.findById(a))!.tag, TxnTag.necessary);
    expect((await repo.findById(b))!.tag, TxnTag.wasteful);
    expect((await repo.findById(b))!.updatedAt, clock);
    expect((await repo.findById(c))!.tag, isNull);

    await repo.setTags({a: null});
    expect((await repo.findById(a))!.tag, isNull);
    expect((await repo.findById(b))!.tag, TxnTag.wasteful);
  });

  test('watchBetween covers its start but not its end', () async {
    await add(100, DateTime(2026, 8, 31, 23, 59));
    await add(200, DateTime(2026, 9, 1));
    await add(300, DateTime(2026, 10, 15));
    await add(400, DateTime(2026, 11, 1));

    final rows = await repo
        .watchBetween(DateTime(2026, 9), DateTime(2026, 11))
        .first;

    expect(rows.map((t) => t.amountPaise), [300, 200]);
  });

  test('an import remembers whether its payee is a person', () async {
    final id = await repo.add(
      amountPaise: 50000,
      type: TxnType.debit,
      categoryId: 'other',
      occurredAt: DateTime(2026, 11, 1, 9),
      merchant: 'Asha Rao',
      source: TxnSource.share,
      payeeIsPerson: true,
    );
    expect((await repo.findById(id))!.payeeIsPerson, isTrue);
    final typed = await add(100, DateTime(2026, 11, 1, 9));
    expect((await repo.findById(typed))!.payeeIsPerson, isNull);
  });

  test('watchRecent lists the newest first, up to the limit', () async {
    for (var day = 1; day <= 7; day++) {
      await add(day * 100, DateTime(2026, 10, day));
    }

    final recent = await repo.watchRecent(limit: 5).first;

    expect(recent.map((t) => t.amountPaise), [700, 600, 500, 400, 300]);
  });

  test('amounts must be positive', () async {
    await expectLater(add(0, DateTime(2026, 11, 1)), throwsArgumentError);
    await expectLater(add(-500, DateTime(2026, 11, 1)), throwsArgumentError);
  });

  group('SMS fingerprints', () {
    Future<String> importSms(String key) => repo.add(
      amountPaise: 25000,
      type: TxnType.debit,
      categoryId: 'food',
      occurredAt: DateTime(2026, 11, 1, 9),
      source: TxnSource.share,
      dedupeKey: key,
    );

    test('find the live entry an SMS became', () async {
      final id = await importSms('abc');
      expect((await repo.findByDedupeKey('abc'))?.id, id);
      expect((await repo.findById(id))?.source, TxnSource.share);
      expect(await repo.findByDedupeKey('other'), isNull);
    });

    test('the same SMS cannot be imported twice', () async {
      await importSms('abc');
      await expectLater(importSms('abc'), throwsA(anything));
    });

    test('deleting an import frees its SMS to be imported again', () async {
      final first = await importSms('abc');
      await repo.softDelete(first);
      final second = await importSms('abc');
      expect((await repo.findByDedupeKey('abc'))?.id, second);
    });

    test('undoing that delete leaves the new import as the owner', () async {
      final first = await importSms('abc');
      await repo.softDelete(first);
      final second = await importSms('abc');
      await repo.restore(first);
      expect((await repo.findByDedupeKey('abc'))?.id, second);
      final restored = await repo.findById(first);
      expect(restored, isNotNull);
      expect(restored!.dedupeKey, isNull);
    });
  });
}

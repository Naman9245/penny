import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/models/txn_enums.dart';

void main() {
  late AppDatabase db;
  late TxnRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = TxnRepository(db);
  });

  tearDown(() => db.close());

  Future<String> add(
    int paise,
    String category,
    DateTime at, {
    TxnType type = TxnType.debit,
  }) {
    return repo.add(
      amountPaise: paise,
      type: type,
      categoryId: category,
      occurredAt: at,
    );
  }

  test(
    'category totals: the month only, biggest first, deleted left out',
    () async {
      await add(25000, 'food', DateTime(2026, 11, 1));
      await add(10000, 'food', DateTime(2026, 11, 2));
      await add(60000, 'shopping', DateTime(2026, 11, 3));
      await add(500000, 'salary', DateTime(2026, 11, 1), type: TxnType.credit);
      await add(99900, 'food', DateTime(2026, 10, 30));
      await repo.softDelete(await add(70000, 'fun', DateTime(2026, 11, 4)));

      final totals = await repo.watchCategoryTotals(DateTime(2026, 11)).first;

      expect(
        [for (final t in totals) '${t.categoryId}:${t.totalPaise}:${t.count}'],
        ['salary:500000:1', 'shopping:60000:1', 'food:35000:2'],
      );
    },
  );

  test('monthly totals: six months, oldest first, empty months zero', () async {
    await add(25000, 'food', DateTime(2026, 11, 1));
    await add(500000, 'salary', DateTime(2026, 9, 15), type: TxnType.credit);
    await add(12300, 'food', DateTime(2026, 5, 31)); // Seven months back.

    final months = await repo.watchMonthlyTotals(DateTime(2026, 11, 20)).first;

    expect(months.map((m) => m.month), [
      for (var m = 6; m <= 11; m++) DateTime(2026, m),
    ]);
    expect(months.last.spentPaise, 25000);
    expect(months[3].gotPaise, 500000);
    expect(months.first.spentPaise, 0);
  });

  test('compact rupees for chart axes', () {
    expect(compactRupees(95000), '₹950');
    expect(compactRupees(1000000), '₹10K');
    expect(compactRupees(1250000), '₹12.5K');
    expect(compactRupees(12000000), '₹1.2L');
    expect(compactRupees(3400000000), '₹3.4Cr');
  });
}

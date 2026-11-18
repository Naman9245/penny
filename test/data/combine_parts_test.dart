import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
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

  // Two payments to one person, made up.
  Future<String> pay(int paise, int hour) => repo.add(
    amountPaise: paise,
    type: TxnType.debit,
    categoryId: 'people',
    occurredAt: DateTime(2026, 11, 15, hour),
    merchant: 'Ravi Kumar',
    payeeIsPerson: true,
  );

  test('combining keeps what it was made of', () async {
    final a = await pay(667, 9);
    final b = await pay(1167, 13);
    final combined = (await repo.combine([a, b]))!;

    final parts = await repo.watchParts(combined).first;
    expect([for (final part in parts) part.id], [a, b]);
    expect(parts.every((part) => part.deletedAt != null), isTrue);
    expect(await repo.watchCombinedCounts().first, {combined: 2});
  });

  test('split apart brings them back; recombine undoes it', () async {
    final a = await pay(667, 9);
    final b = await pay(1167, 13);
    final combined = (await repo.combine([a, b]))!;

    final ids = await repo.splitApart(combined);
    expect(ids.toSet(), {a, b});
    expect(await repo.findById(combined), isNull);
    expect(await repo.findById(a), isNotNull);
    expect(await repo.findById(b), isNotNull);
    expect(await repo.watchParts(combined).first, isEmpty);
    expect(await repo.watchCombinedCounts().first, isEmpty);

    await repo.recombine(combined, ids);
    expect(await repo.findById(combined), isNotNull);
    expect(await repo.findById(a), isNull);
    expect(await repo.watchParts(combined).first, hasLength(2));
  });

  test("Undo of a combine forgets that it was made of them", () async {
    final a = await pay(667, 9);
    final b = await pay(1167, 13);
    final combined = (await repo.combine([a, b]))!;
    await repo.uncombine(combined, [a, b]);
    expect(await repo.watchCombinedCounts().first, isEmpty);
    expect(await repo.findById(a), isNotNull);
  });

  test('an entry never combined is made of nothing', () async {
    final a = await pay(667, 9);
    expect(await repo.watchParts(a).first, isEmpty);
  });
}

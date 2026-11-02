import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/budget_repository.dart';
import 'package:penny/data/db/app_database.dart';

void main() {
  late AppDatabase db;
  late BudgetRepository repo;
  late DateTime clock;

  setUp(() {
    clock = DateTime(2026, 11, 2, 10);
    db = AppDatabase(NativeDatabase.memory());
    repo = BudgetRepository(db, clock: () => clock);
  });

  tearDown(() => db.close());

  test('starts empty', () async {
    final budget = await repo.watch().first;
    expect(budget.isEmpty, isTrue);
    expect(budget.everydayPaise, isNull);
  });

  test('the everyday budget and caps come back apart', () async {
    await repo.setEveryday(800000);
    await repo.setCap('food', 300000);
    await repo.setCap('rent', 900000);

    final budget = await repo.watch().first;
    expect(budget.everydayPaise, 800000);
    expect(budget.caps, {'food': 300000, 'rent': 900000});
  });

  test('changing an amount keeps one live row and stamps it', () async {
    await repo.setCap('food', 300000);
    clock = DateTime(2026, 11, 3);
    await repo.setCap('food', 250000);

    final rows = await db.select(db.budgets).get();
    expect(rows.single.amountPaise, 250000);
    expect(rows.single.updatedAt, DateTime(2026, 11, 3));
  });

  test('clearing an amount only marks it deleted', () async {
    await repo.setEveryday(800000);
    await repo.setEveryday(null);
    await repo.setCap('food', 300000);
    await repo.setCap('food', 0);

    expect((await repo.watch().first).isEmpty, isTrue);
    final rows = await db.select(db.budgets).get();
    expect(rows, hasLength(2));
    expect(rows.every((row) => row.deletedAt != null), isTrue);

    // Setting it again makes a new live row beside the deleted one.
    await repo.setEveryday(600000);
    expect((await repo.watch().first).everydayPaise, 600000);
  });
}

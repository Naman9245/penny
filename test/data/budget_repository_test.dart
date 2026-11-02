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
    expect(budget.totalPaise, 0);
  });

  test('category amounts add up to the monthly budget', () async {
    await repo.setAmount('food', 300000);
    await repo.setAmount('travel', 150000);
    await repo.setAmount('rent', 900000);

    final budget = await repo.watch().first;
    expect(budget.byCategory, {
      'food': 300000,
      'travel': 150000,
      'rent': 900000,
    });
    expect(budget.totalPaise, 1350000);
    expect(budget.everydayPaise, 450000);
    expect(budget.oneGoPaise, 900000);
  });

  test('changing an amount keeps one live row and stamps it', () async {
    await repo.setAmount('food', 300000);
    clock = DateTime(2026, 11, 3);
    await repo.setAmount('food', 250000);

    final rows = await db.select(db.budgets).get();
    expect(rows.single.amountPaise, 250000);
    expect(rows.single.updatedAt, DateTime(2026, 11, 3));
  });

  test('clearing an amount only marks it deleted', () async {
    await repo.setAmount('food', 300000);
    await repo.setAmount('food', 0);
    await repo.setAmount('fun', 100000);
    await repo.setAmount('fun', null);

    expect((await repo.watch().first).isEmpty, isTrue);
    final rows = await db.select(db.budgets).get();
    expect(rows, hasLength(2));
    expect(rows.every((row) => row.deletedAt != null), isTrue);

    // Setting it again makes a new live row beside the deleted one.
    await repo.setAmount('food', 200000);
    expect((await repo.watch().first).byCategory, {'food': 200000});
  });

  test('an everyday row from the first budgets is ignored', () async {
    await db
        .into(db.budgets)
        .insert(
          BudgetsCompanion.insert(
            id: 'old',
            budgetKey: 'everyday',
            amountPaise: 800000,
            createdAt: clock,
            updatedAt: clock,
          ),
        );
    await repo.setAmount('food', 300000);
    expect((await repo.watch().first).byCategory, {'food': 300000});
  });
}

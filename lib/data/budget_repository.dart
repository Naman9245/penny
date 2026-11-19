import 'package:drift/drift.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/budget.dart';
import 'package:uuid/uuid.dart';

/// The budget, category by category, and changes to it. Cleared amounts are
/// only marked deleted, like entries, so sync can carry the change later.
class BudgetRepository {
  BudgetRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  static const _uuid = Uuid();

  Stream<Budget> watch() => _live.watch().map(_budgetOf);

  /// The budget as it is now, once.
  Future<Budget> current() => _live.get().then(_budgetOf);

  SimpleSelectStatement<$BudgetsTable, BudgetRow> get _live =>
      _db.select(_db.budgets)..where((b) => b.deletedAt.isNull());

  static Budget _budgetOf(List<BudgetRow> rows) => Budget(
    byCategory: {
      // An "everyday" row from the first version of budgets no longer
      // means anything: the monthly budget is the categories' total.
      for (final row in rows)
        if (row.budgetKey != 'everyday') row.budgetKey: row.amountPaise,
    },
  );

  /// What the user means to spend on [categoryId] a month. Null or nothing
  /// clears it.
  Future<void> setAmount(String categoryId, int? paise) {
    final amount = paise != null && paise > 0 ? paise : null;
    final now = _clock();
    return _db.transaction(() async {
      final live =
          await (_db.select(_db.budgets)..where(
                (b) => b.budgetKey.equals(categoryId) & b.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (live == null) {
        if (amount == null) return;
        await _db
            .into(_db.budgets)
            .insert(
              BudgetsCompanion.insert(
                id: _uuid.v7(),
                budgetKey: categoryId,
                amountPaise: amount,
                createdAt: now,
                updatedAt: now,
              ),
            );
        return;
      }
      await (_db.update(_db.budgets)..where((b) => b.id.equals(live.id))).write(
        amount == null
            ? BudgetsCompanion(
                deletedAt: Value(now),
                updatedAt: Value(now),
                dirty: const Value(true),
              )
            : BudgetsCompanion(
                amountPaise: Value(amount),
                updatedAt: Value(now),
                dirty: const Value(true),
              ),
      );
    });
  }
}

import 'package:drift/drift.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/budget.dart';
import 'package:uuid/uuid.dart';

/// The budget and the caps, and changes to them. Cleared amounts are only
/// marked deleted, like entries, so sync can carry the change later.
class BudgetRepository {
  BudgetRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  static const _uuid = Uuid();
  static const _everyday = 'everyday';

  Stream<Budget> watch() {
    final query = _db.select(_db.budgets)..where((b) => b.deletedAt.isNull());
    return query.watch().map(
      (rows) => Budget(
        everydayPaise: rows
            .where((row) => row.budgetKey == _everyday)
            .firstOrNull
            ?.amountPaise,
        caps: {
          for (final row in rows)
            if (row.budgetKey != _everyday) row.budgetKey: row.amountPaise,
        },
      ),
    );
  }

  /// The everyday budget a month. Null or nothing clears it.
  Future<void> setEveryday(int? paise) => _set(_everyday, paise);

  /// [categoryId]'s cap a month. Null or nothing clears it.
  Future<void> setCap(String categoryId, int? paise) => _set(categoryId, paise);

  Future<void> _set(String key, int? paise) {
    final amount = paise != null && paise > 0 ? paise : null;
    final now = _clock();
    return _db.transaction(() async {
      final live =
          await (_db.select(_db.budgets)
                ..where((b) => b.budgetKey.equals(key) & b.deletedAt.isNull()))
              .getSingleOrNull();
      if (live == null) {
        if (amount == null) return;
        await _db
            .into(_db.budgets)
            .insert(
              BudgetsCompanion.insert(
                id: _uuid.v7(),
                budgetKey: key,
                amountPaise: amount,
                createdAt: now,
                updatedAt: now,
              ),
            );
        return;
      }
      await (_db.update(_db.budgets)..where((b) => b.id.equals(live.id))).write(
        amount == null
            ? BudgetsCompanion(deletedAt: Value(now), updatedAt: Value(now))
            : BudgetsCompanion(
                amountPaise: Value(amount),
                updatedAt: Value(now),
              ),
      );
    });
  }
}

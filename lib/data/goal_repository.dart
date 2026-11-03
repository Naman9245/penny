import 'package:drift/drift.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:uuid/uuid.dart';

/// Goals, and the money put toward them. Deletes only mark rows deleted,
/// like entries, so sync can carry them later.
class GoalRepository {
  GoalRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  static const _uuid = Uuid();

  /// The longest title a goal keeps.
  static const maxTitleLength = 40;

  /// Live goals, soonest deadline first.
  Stream<List<Goal>> watchGoals() {
    final query = _db.select(_db.goals)
      ..where((g) => g.deletedAt.isNull())
      ..orderBy([
        (g) => OrderingTerm.asc(g.deadline),
        (g) => OrderingTerm.asc(g.createdAt),
      ]);
    return query.watch();
  }

  /// The live money in and out of every live goal, oldest first.
  Stream<List<GoalDeposit>> watchDeposits() {
    final query = _db.select(_db.goalDeposits)
      ..where((d) => d.deletedAt.isNull())
      ..orderBy([
        (d) => OrderingTerm.asc(d.occurredAt),
        (d) => OrderingTerm.asc(d.createdAt),
      ]);
    return query.watch();
  }

  /// Saves a new goal and returns its id.
  Future<String> add({
    required String title,
    required int targetPaise,
    required DateTime deadline,
  }) async {
    final id = _uuid.v7();
    final now = _clock();
    await _db
        .into(_db.goals)
        .insert(
          GoalsCompanion.insert(
            id: id,
            title: _title(title),
            targetPaise: targetPaise,
            deadline: dayStart(deadline),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> update(
    String id, {
    required String title,
    required int targetPaise,
    required DateTime deadline,
  }) {
    return (_db.update(_db.goals)..where((g) => g.id.equals(id))).write(
      GoalsCompanion(
        title: Value(_title(title)),
        targetPaise: Value(targetPaise),
        deadline: Value(dayStart(deadline)),
        updatedAt: Value(_clock()),
        dirty: const Value(true),
      ),
    );
  }

  /// Deletes [id], the money put toward it and Penny's plan for it.
  Future<void> delete(String id) {
    final now = _clock();
    return _db.transaction(() async {
      await (_db.update(_db.goals)..where((g) => g.id.equals(id))).write(
        GoalsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          dirty: const Value(true),
        ),
      );
      await (_db.update(
        _db.goalDeposits,
      )..where((d) => d.goalId.equals(id) & d.deletedAt.isNull())).write(
        GoalDepositsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          dirty: const Value(true),
        ),
      );
      // The plan never left the phone, so it can go for good.
      await (_db.delete(_db.goalPlans)..where((p) => p.goalId.equals(id))).go();
    });
  }

  /// Puts [amountPaise] toward [goalId], or takes it out when negative, and
  /// returns the entry's id.
  Future<String> deposit(String goalId, int amountPaise) async {
    final id = _uuid.v7();
    final now = _clock();
    await _db
        .into(_db.goalDeposits)
        .insert(
          GoalDepositsCompanion.insert(
            id: id,
            goalId: goalId,
            amountPaise: amountPaise,
            occurredAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> deleteDeposit(String id) => _setDepositDeletedAt(id, _clock());

  Future<void> restoreDeposit(String id) => _setDepositDeletedAt(id, null);

  Future<void> _setDepositDeletedAt(String id, DateTime? at) {
    return (_db.update(_db.goalDeposits)..where((d) => d.id.equals(id))).write(
      GoalDepositsCompanion(
        deletedAt: Value(at),
        updatedAt: Value(_clock()),
        dirty: const Value(true),
      ),
    );
  }

  static String _title(String raw) {
    final title = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    return title.length > maxTitleLength
        ? title.substring(0, maxTitleLength).trim()
        : title;
  }
}

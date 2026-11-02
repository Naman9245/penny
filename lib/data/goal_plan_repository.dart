import 'dart:convert';

import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/goal_plan.dart';

/// Penny's saved plans, one per goal. They stay on this phone.
class GoalPlanRepository {
  GoalPlanRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  /// The plan for [goalId], or null when there is none (or it can't be read
  /// any more).
  Stream<SavedGoalPlan?> watch(String goalId) {
    final query = _db.select(_db.goalPlans)
      ..where((p) => p.goalId.equals(goalId));
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _read(row),
    );
  }

  /// Keeps [plan] as [goalId]'s plan, replacing any earlier one.
  Future<void> save({
    required String goalId,
    required DateTime month,
    required String inputHash,
    required Map<String, List<String>> groupKeys,
    required GoalPlan plan,
    required String model,
  }) {
    return _db
        .into(_db.goalPlans)
        .insertOnConflictUpdate(
          GoalPlansCompanion.insert(
            goalId: goalId,
            month: monthKey(month),
            inputHash: inputHash,
            groupKeys: jsonEncode(groupKeys),
            answer: jsonEncode(plan.toJson()),
            model: model,
            createdAt: _clock(),
          ),
        );
  }

  static SavedGoalPlan? _read(GoalPlanRow row) {
    try {
      final groupKeys = {
        for (final MapEntry(:key, :value)
            in (jsonDecode(row.groupKeys) as Map<String, dynamic>).entries)
          key: (value as List).cast<String>(),
      };
      final plan = GoalPlan.fromJson(
        jsonDecode(row.answer),
        groupIds: groupKeys.keys.toSet(),
      );
      if (plan == null) return null;
      final [year, month] = row.month.split('-').map(int.parse).toList();
      return SavedGoalPlan(
        goalId: row.goalId,
        month: DateTime(year, month),
        inputHash: row.inputHash,
        groupKeys: groupKeys,
        plan: plan,
        model: row.model,
        createdAt: row.createdAt,
      );
    } on Object {
      // A plan from an older version that no longer reads: plan again.
      return null;
    }
  }
}

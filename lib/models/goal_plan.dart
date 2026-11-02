import 'package:flutter/foundation.dart';
import 'package:penny/models/month_insight.dart';

/// Penny's plan for reaching a goal, as plan-goal cleaned it: which spending
/// to cut, shaped like the report's habits, and a line of encouragement.
/// Group ids ("s1"…) are the ones the phone sent.
@immutable
class GoalPlan {
  const GoalPlan({required this.cuts, required this.summary});

  final List<InsightHabit> cuts;
  final String summary;

  /// Reads a plan, keeping only cuts that make sense: known cuts, with
  /// groups among [groupIds] when given. Null when [json] isn't a plan.
  static GoalPlan? fromJson(Object? json, {Set<String>? groupIds}) {
    if (json is! Map) return null;
    final summary = json['summary'];
    return GoalPlan(
      cuts: InsightHabit.listFromJson(json['cuts'], groupIds: groupIds),
      summary: summary is String ? summary.trim() : '',
    );
  }

  Map<String, Object?> toJson() => {
    'cuts': [for (final cut in cuts) cut.toJson()],
    'summary': summary,
  };
}

/// A plan kept on the phone for one goal.
@immutable
class SavedGoalPlan {
  const SavedGoalPlan({
    required this.goalId,
    required this.month,
    required this.inputHash,
    required this.groupKeys,
    required this.plan,
    required this.model,
    required this.createdAt,
  });

  final String goalId;

  /// The month whose spending the plan went by.
  final DateTime month;

  /// Fingerprint of the goal as it was when Penny planned.
  final String inputHash;

  /// The local groups behind each id Penny saw. Never leaves the phone.
  final Map<String, List<String>> groupKeys;
  final GoalPlan plan;
  final String model;
  final DateTime createdAt;
}

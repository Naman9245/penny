import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/budget.dart';
import 'package:penny/models/goal_plan.dart';
import 'package:penny/models/month_insight.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/models/your_rules.dart';
import 'package:penny/services/goal_math.dart';
import 'package:penny/services/insight_builder.dart';
import 'package:penny/services/insight_math.dart';

// Penny's plan for a goal: what goes to plan-goal, and the plan's cuts with
// what each saves a month, worked out on the phone. Penny only picks.

/// Days a month needs before Penny plans with it, when there is no full
/// month to go by.
const minPlanDays = 14;

/// Everything about one request for Penny's plan for a goal.
@immutable
class GoalPlanRequest {
  const GoalPlanRequest({
    required this.goalId,
    required this.month,
    required this.tags,
    required this.goal,
    required this.inputHash,
  });

  final String goalId;

  /// The month the plan goes by, as the report would send it.
  final InsightRequest month;

  /// Each spend group's tag as the phone works it out.
  final Map<String, TxnTag> tags;

  /// The goal as Penny is told it: its title, amounts in whole rupees and
  /// the weeks left.
  final Map<String, Object?> goal;

  /// Fingerprint of the goal's target and deadline.
  final String inputHash;

  Map<String, Object?> toJson() => {
    'v': 1,
    'month': month.body,
    'tags': {
      for (final MapEntry(:key, :value) in tags.entries) key: value.name,
    },
    'goal': goal,
  };
}

/// What goes to plan-goal for [progress], going by last month's spending,
/// or this month's once it has [minPlanDays] days when last month had too
/// little. Null when neither month will do yet, or there is nothing left to
/// plan because the goal is reached or its date has passed.
///
/// [txns] runs from [insightHistoryStart] of last month to the end of this
/// one; [insights] holds the saved reports, by month, for their tags.
GoalPlanRequest? buildGoalPlanRequest({
  required GoalProgress progress,
  required List<Txn> txns,
  required DateTime now,
  YourRules rules = YourRules.none,
  String? note,
  Budget budget = Budget.none,
  Map<DateTime, SavedInsight?> insights = const {},
}) {
  if (progress.reached || progress.isMissed(now)) return null;

  InsightRequest requestFor(DateTime month) => buildInsightRequest(
    month: month,
    txns: txns,
    now: now,
    rules: rules,
    note: note,
    budget: budget,
  );
  final thisMonth = monthStart(now);
  var month = requestFor(prevMonth(thisMonth));
  if (!month.canAsk) {
    month = requestFor(thisMonth);
    final days = month.body['daysCounted']! as int;
    if (!month.canAsk || days < minPlanDays) return null;
  }

  final monthTxns = [
    for (final txn in txns)
      if (monthStart(txn.occurredAt) == month.month) txn,
  ];
  final goal = progress.goal;
  return GoalPlanRequest(
    goalId: goal.id,
    month: month,
    tags: groupTags(month, monthTxns, insights[month.month], rules: rules),
    goal: {
      'title': goal.title,
      'target': _rupees(goal.targetPaise),
      'saved': _rupees(math.max(0, progress.savedPaise)),
      // The server takes up to ten years of weeks.
      'weeksLeft': math.min(520, progress.weeksLeft(now)),
      'perWeek': _rupees(progress.perWeekPaise(now)),
      'perMonth': _rupees(progress.perMonthPaise(now)),
    },
    inputHash: goalFingerprint(goal),
  );
}

/// Fingerprint of what Penny planned for: the goal's target and deadline.
/// Money going in or out changes what's needed, which the plan's numbers
/// follow live, but not the plan.
String goalFingerprint(Goal goal) => sha256
    .convert(
      utf8.encode(
        'penny-goal-v1|${goal.targetPaise}|'
        '${goal.deadline.toIso8601String()}',
      ),
    )
    .toString();

/// One of Penny's cuts with what it saves a month.
@immutable
class PlanCutView {
  const PlanCutView({
    required this.cut,
    required this.names,
    required this.savePaise,
  });

  final InsightHabit cut;

  /// The shops (or categories) in the cut, as the user knows them.
  final List<String> names;

  /// What the cut saves a month, in whole rupees.
  final int savePaise;

  String get title => cut.title.isNotEmpty ? cut.title : names.join(' & ');
}

/// [saved]'s cuts with what each saves a month, from the plan month's
/// entries as they are now. A month still going counts as a whole one, so
/// those amounts are estimates.
List<PlanCutView> planCutViews(
  SavedGoalPlan saved,
  Iterable<Txn> monthTxns,
  DateTime now,
) {
  final month = saved.month;
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final counted = monthStart(now) == month ? now.day : daysInMonth;
  final spends = [
    for (final txn in monthTxns)
      if (txn.type == TxnType.debit && monthStart(txn.occurredAt) == month) txn,
  ];
  return [
    for (final cut in saved.plan.cuts)
      _cutView(cut, saved.groupKeys, spends, scale: daysInMonth / counted),
  ];
}

/// Everything [cuts] save together, a month.
int planSavingPaise(Iterable<PlanCutView> cuts) =>
    cuts.fold(0, (sum, cut) => sum + cut.savePaise);

PlanCutView _cutView(
  InsightHabit cut,
  Map<String, List<String>> groupKeys,
  List<Txn> spends, {
  required double scale,
}) {
  final keys = {for (final id in cut.groupIds) ...?groupKeys[id]};
  final members = [
    for (final txn in spends)
      if (keys.contains(groupKeyOf(txn))) txn,
  ];
  final spent = members.fold(0, (sum, txn) => sum + txn.amountPaise);
  return PlanCutView(
    cut: cut,
    names: namesOf(members),
    savePaise: (spent * scale * cut.cut.quarters / 400).round() * 100,
  );
}

int _rupees(int paise) => (paise / 100).round();

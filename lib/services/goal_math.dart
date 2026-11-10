import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/db/app_database.dart';

// What a goal has saved and still needs, worked out on the phone from the
// money put in and taken out. Nothing here is stored.

/// A goal with what has been put toward it.
@immutable
class GoalProgress {
  const GoalProgress({
    required this.goal,
    required this.savedPaise,
    required this.reachedOn,
  });

  final Goal goal;

  /// Put in, less taken out.
  final int savedPaise;

  /// The day the money put in last reached the target, while it still
  /// does.
  final DateTime? reachedOn;

  bool get reached => reachedOn != null;

  int get toGoPaise => math.max(0, goal.targetPaise - savedPaise);

  /// How far along it is, from 0 to 1.
  double get progress => (savedPaise / goal.targetPaise).clamp(0, 1).toDouble();

  /// Whole days from [today] to the deadline; 0 when it is today, and
  /// negative once it has passed.
  int daysLeft(DateTime today) =>
      goal.deadline.difference(dayStart(today)).inDays;

  /// The deadline has gone by without the goal being reached.
  bool isMissed(DateTime today) => !reached && daysLeft(today) < 0;

  /// Weeks to the deadline, counting a part week as one; at least one.
  int weeksLeft(DateTime today) => math.max(1, (daysLeft(today) / 7).ceil());

  /// Still to put aside each week to make it in time, to the rupee above.
  /// Nothing once reached or missed.
  int perWeekPaise(DateTime today) => _per(today, days: 7);

  /// The same, for each month.
  int perMonthPaise(DateTime today) => _per(today, days: 365 / 12);

  int _per(DateTime today, {required num days}) {
    if (reached || isMissed(today)) return 0;
    final left = math.max(1, daysLeft(today));
    final paise = math.min(toGoPaise, (toGoPaise * days / left).ceil());
    return _upToRupee(paise);
  }
}

/// Each of [goals] with the money in [deposits] that belongs to it, in the
/// order given.
List<GoalProgress> goalProgress(
  Iterable<Goal> goals,
  Iterable<GoalDeposit> deposits,
) {
  final byGoal = <String, List<GoalDeposit>>{};
  for (final deposit in deposits) {
    (byGoal[deposit.goalId] ??= []).add(deposit);
  }
  return [
    for (final goal in goals) _progressOf(goal, byGoal[goal.id] ?? const []),
  ];
}

GoalProgress _progressOf(Goal goal, List<GoalDeposit> deposits) {
  final ordered = [...deposits]
    ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
  var saved = 0;
  DateTime? reachedOn;
  for (final deposit in ordered) {
    final before = saved;
    saved += deposit.amountPaise;
    if (before < goal.targetPaise && saved >= goal.targetPaise) {
      reachedOn = dayStart(deposit.occurredAt);
    } else if (saved < goal.targetPaise) {
      reachedOn = null;
    }
  }
  return GoalProgress(goal: goal, savedPaise: saved, reachedOn: reachedOn);
}

/// [goals] in the order Penny lists them: those still going, soonest date
/// first, then those whose date has passed, the latest first, then those
/// reached, the latest first. Goals that tie keep the order given.
List<GoalProgress> inListOrder(Iterable<GoalProgress> goals, DateTime today) {
  int group(GoalProgress g) => g.reached ? 2 : (g.isMissed(today) ? 1 : 0);
  final ordered = goals.indexed.toList()
    ..sort((a, b) {
      final (i, x) = a;
      final (j, y) = b;
      final byGroup = group(x).compareTo(group(y));
      if (byGroup != 0) return byGroup;
      final byDate = switch (group(x)) {
        0 => x.goal.deadline.compareTo(y.goal.deadline),
        1 => y.goal.deadline.compareTo(x.goal.deadline),
        _ => y.reachedOn!.compareTo(x.reachedOn!),
      };
      return byDate != 0 ? byDate : i.compareTo(j);
    });
  return [for (final (_, goal) in ordered) goal];
}

/// Put in, less taken out, between [from] and [to] across every goal.
int savedBetween(Iterable<GoalDeposit> deposits, DateTime from, DateTime to) =>
    deposits
        .where((d) => !d.occurredAt.isBefore(from) && d.occurredAt.isBefore(to))
        .fold(0, (sum, d) => sum + d.amountPaise);

/// A goal reached on [today], the first if there are several: Penny is
/// celebrating it, and the day is sky blue on the mood calendar.
GoalProgress? justReachedGoal(Iterable<GoalProgress> goals, DateTime today) {
  final day = dayStart(today);
  for (final goal in goals) {
    if (goal.reachedOn == day) return goal;
  }
  return null;
}

/// Whether a goal was reached on [today].
bool justReached(Iterable<GoalProgress> goals, DateTime today) =>
    justReachedGoal(goals, today) != null;

int _upToRupee(int paise) => (paise + 99) ~/ 100 * 100;

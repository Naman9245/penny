import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/services/goal_math.dart';
import 'package:penny/widgets/brutal_pill.dart';
import 'package:penny/widgets/meter_bar.dart';

/// Penny's cheer for a goal just reached, naming it.
String celebrationLine(GoalProgress progress) =>
    '${progress.goal.title} reached! You did it!';

/// What a goal still needs, in one line: reached, missed, or to go and
/// what a week until the deadline.
String goalNeedLine(GoalProgress progress, DateTime today) {
  final reachedOn = progress.reachedOn;
  if (reachedOn != null) {
    return 'Reached on ${DateFormat('d MMM').format(reachedOn)}!';
  }
  if (progress.isMissed(today)) {
    return 'The date has passed. Move it or lower the target.';
  }
  return '${formatPaise(progress.toGoPaise)} to go · '
      '${formatPaise(progress.perWeekPaise(today))} a week until '
      '${DateFormat('d MMM').format(progress.goal.deadline)}';
}

/// Marks a goal whose date went by before it was reached.
class DatePassedPill extends StatelessWidget {
  const DatePassedPill({super.key});

  @override
  Widget build(BuildContext context) =>
      const BrutalPill(label: 'Date passed', color: AppColors.white);
}

/// How far along a goal is, as a chunky bar.
class GoalProgressBar extends StatelessWidget {
  const GoalProgressBar({super.key, required this.progress});

  /// From 0 to 1.
  final double progress;

  @override
  Widget build(BuildContext context) => MeterBar(value: progress, chunky: true);
}

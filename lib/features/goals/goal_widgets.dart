import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/brutal_theme.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/services/goal_math.dart';

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

/// How far along a goal is, as a chunky bar.
class GoalProgressBar extends StatelessWidget {
  const GoalProgressBar({super.key, required this.progress});

  /// From 0 to 1.
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 16,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(kPillRadius),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.all(Radius.circular(kPillRadius)),
          ),
        ),
      ),
    );
  }
}

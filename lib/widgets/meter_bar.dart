import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/brutal_theme.dart';

/// How much of something is used or done, as a bar: an ink fill on a faint
/// track. Past full it stays full and turns [overColor], so a budget gone
/// over reads at a glance.
///
/// [chunky] draws Penny's big outlined bar, for a card's one bar; without
/// it the bar is thin and borderless, for rows of them.
class MeterBar extends StatelessWidget {
  const MeterBar({
    super.key,
    required this.value,
    this.chunky = false,
    this.color = AppColors.ink,
    this.overColor = AppColors.negative,
    this.height,
  });

  /// From 0 up; 1 is full.
  final double value;
  final bool chunky;
  final Color color;
  final Color overColor;

  /// Defaults to 16 for a chunky bar and 8 for a thin one.
  final double? height;

  @override
  Widget build(BuildContext context) {
    final over = value > 1;
    final fill = value.isNaN ? 0.0 : math.max(0.0, math.min(1.0, value));
    final height = this.height ?? (chunky ? 16.0 : 8.0);
    return Container(
      // The whole width, so the empty part of the track shows.
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: chunky ? AppColors.white : AppColors.track,
        borderRadius: BorderRadius.circular(kPillRadius),
        border: chunky ? Border.all(color: AppColors.ink, width: 2) : null,
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fill,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: over ? overColor : color,
            borderRadius: BorderRadius.circular(kPillRadius),
          ),
        ),
      ),
    );
  }
}

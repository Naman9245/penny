import 'package:flutter/painting.dart';
import 'package:penny/core/theme/app_colors.dart';

/// Penny's app states. The colour is also the day's colour on the mood
/// calendar.
enum PennyMood {
  happy('Happy', AppColors.mint, "You're under budget! Keep it up!"),
  neutral('Neutral', AppColors.lavender, "All good! You're on track."),
  worried('Worried', AppColors.yellow, "You're close to your spending cap."),
  sad(
    'Sad',
    AppColors.pink,
    "You've gone over budget. Let's plan a quick fix!",
  ),
  celebrating('Celebrating', AppColors.sky, 'Goal achieved! You did it!');

  const PennyMood(this.label, this.color, this.line);

  final String label;
  final Color color;

  /// What Penny says in this mood.
  final String line;
}

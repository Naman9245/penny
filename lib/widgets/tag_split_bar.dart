import 'package:flutter/material.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/theme/brutal_theme.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/services/insight_math.dart';

/// A month's spending as one chunky bar: necessary in mint, wasteful in
/// pink, not sorted yet in white.
class TagSplitBar extends StatelessWidget {
  const TagSplitBar({super.key, required this.split});

  final TagSplit split;

  @override
  Widget build(BuildContext context) {
    final parts = [
      for (final (paise, color) in [
        (split.necessaryPaise, AppColors.mint),
        (split.wastefulPaise, AppColors.pink),
        (split.unsortedPaise, AppColors.white),
      ])
        if (paise > 0) (paise, color),
    ];
    return Semantics(
      label:
          'Necessary ${formatPaise(split.necessaryPaise)}, '
          'wasteful ${formatPaise(split.wastefulPaise)}, '
          'not sorted ${formatPaise(split.unsortedPaise)}',
      child: Container(
        height: 24,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(kPillRadius),
          border: Border.all(color: AppColors.ink, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kPillRadius),
          child: Row(
            // The segments are plain colour, so they take the bar's height.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, (paise, color)) in parts.indexed) ...[
                if (i > 0)
                  const SizedBox(
                    width: 2,
                    child: ColoredBox(color: AppColors.ink),
                  ),
                Expanded(
                  flex: paise,
                  child: ColoredBox(color: color),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// What each colour in a [TagSplitBar] stands for, with its amount.
class TagSplitKey extends StatelessWidget {
  const TagSplitKey({super.key, required this.split});

  final TagSplit split;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final row in [
        ('Necessary', split.necessaryPaise, AppColors.mint),
        ('Wasteful', split.wastefulPaise, AppColors.pink),
        ('Not sorted yet', split.unsortedPaise, AppColors.white),
      ])
        if (row.$2 > 0) row,
    ];
    final cameBack = split.cameBackPaise;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: _rows(rows)),
        // The split stays what was paid; this is what came back since.
        if (cameBack > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${formatPaise(cameBack)} of it came back',
              key: const ValueKey('split-came-back'),
              style: AppText.small,
            ),
          ),
      ],
    );
  }

  static Widget _rows(List<(String, int, Color)> rows) {
    return Column(
      children: [
        for (final (label, paise, color) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.ink, width: 1.5),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(label, style: AppText.body)),
                Text(formatPaise(paise), style: AppText.bodyStrong),
              ],
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/widgets/brutal_icon_button.dart';

/// ‹ November 2026 ›: steps a month back or forward, never past this month.
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    super.key,
    required this.month,
    required this.onChanged,
  });

  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final thisMonth = monthStart(DateTime.now());
    return Row(
      children: [
        BrutalIconButton(
          icon: Icons.chevron_left_rounded,
          semanticLabel: 'Previous month',
          onPressed: () => onChanged(prevMonth(month)),
        ),
        Expanded(
          child: Text(
            monthLabel(month),
            style: AppText.h2,
            textAlign: TextAlign.center,
          ),
        ),
        BrutalIconButton(
          icon: Icons.chevron_right_rounded,
          semanticLabel: 'Next month',
          onPressed: month.isBefore(thisMonth)
              ? () => onChanged(nextMonth(month))
              : null,
        ),
      ],
    );
  }
}

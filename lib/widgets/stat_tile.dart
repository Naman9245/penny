import 'package:flutter/material.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/widgets/icon_badge.dart';

/// What a figure is: a badge in the colour of its kind of money, and its
/// name.
class StatLabel extends StatelessWidget {
  const StatLabel({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconBadge(icon: icon, color: color, size: 26),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: AppText.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// One figure in a row of them: its label, the amount, and a line under
/// it when there's more to say.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.hint,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 14, 14),
  });

  final IconData icon;
  final Color color;
  final String label;
  final Widget value;
  final String? hint;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final hint = this.hint;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatLabel(icon: icon, color: color, label: label),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: value,
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint, style: AppText.small),
          ],
        ],
      ),
    );
  }
}

/// A thin upright line between figures in a row.
class StatDivider extends StatelessWidget {
  const StatDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: AppColors.hairline, child: SizedBox(width: 1.5));
}

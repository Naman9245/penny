import 'package:flutter/material.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/widgets/icon_badge.dart';

/// The top of a card: a badge in the colour of what it's about, its title,
/// and a line under it.
class CardTitle extends StatelessWidget {
  const CardTitle({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final trailing = this.trailing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconBadge(icon: icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lines up with the badge's middle when there's one line.
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(title, style: AppText.h3),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.small),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing],
      ],
    );
  }
}

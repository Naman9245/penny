import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/widgets/brutal_icon_button.dart';

/// The top of a screen that opens over the tabs: Back, the screen's title,
/// a line on what it's for, and any [actions] at the end. Every such screen
/// starts the same way.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// Defaults to going back a screen.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return Row(
      children: [
        BrutalIconButton(
          icon: Icons.arrow_back_rounded,
          semanticLabel: 'Back',
          onPressed: onBack ?? () => context.pop(),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppText.h2,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) Text(subtitle, style: AppText.bodyMuted),
            ],
          ),
        ),
        for (final action in actions) ...[const SizedBox(width: 10), action],
      ],
    );
  }
}

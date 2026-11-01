import 'package:flutter/material.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/brutal_theme.dart';
import 'package:penny/widgets/brutal_pressable.dart';

/// A filled card with an ink border and a hard shadow. Pass [onTap] to make
/// it pressable.
class BrutalCard extends StatelessWidget {
  const BrutalCard({
    super.key,
    required this.child,
    this.color = AppColors.white,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.clipChild = false,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Clips the child to the card's inner corners, for rows that paint their
  /// own backgrounds, like swipe-to-delete. Use with zero padding.
  final bool clipChild;

  @override
  Widget build(BuildContext context) {
    final brutal = context.brutal;
    final content = clipChild
        ? ClipRRect(
            borderRadius: BorderRadius.circular(
              brutal.cardRadius - brutal.borderWidth,
            ),
            child: child,
          )
        : child;

    if (onTap != null) {
      return BrutalPressable(
        onPressed: onTap,
        color: color,
        radius: brutal.cardRadius,
        padding: padding,
        child: content,
      );
    }
    return Container(
      padding: padding,
      decoration: brutalDecoration(
        color: color,
        radius: brutal.cardRadius,
        borderWidth: brutal.borderWidth,
        shadow: brutal.shadowOffset,
      ),
      child: content,
    );
  }
}

/// A hairline between rows inside a card.
class RowDivider extends StatelessWidget {
  const RowDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.hairline,
      child: SizedBox(height: 1.5, width: double.infinity),
    );
  }
}

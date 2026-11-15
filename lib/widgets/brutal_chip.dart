import 'package:flutter/material.dart';
import 'package:penny/core/theme/brutal_theme.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/widgets/brutal_pressable.dart';

/// A small pill for filters and quick choices.
class BrutalChip extends StatelessWidget {
  const BrutalChip({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.icon,
    this.selectedColor = AppColors.yellow,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final IconData? icon;
  final Color selectedColor;

  /// Read out instead of [label], for a label like "÷2" that doesn't say
  /// itself well.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return BrutalPressable(
      onPressed: onTap,
      selected: selected,
      color: selected ? selectedColor : AppColors.white,
      borderWidth: 2,
      shadowOffset: kSmallShadow,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      semanticLabel: semanticLabel,
      child: ExcludeSemantics(
        excluding: semanticLabel != null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: AppColors.ink),
              const SizedBox(width: 6),
            ],
            // Chips sit in Rows and Wraps alike, so cap the label instead of
            // relying on a parent to bound it.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                label,
                style: AppText.chip,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/widgets/brutal_pressable.dart';

/// The pill-shaped call to action.
class BrutalButton extends StatelessWidget {
  const BrutalButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AppColors.yellow,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;

  /// Fill the available width instead of hugging the label.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: AppText.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return BrutalPressable(
      onPressed: onPressed,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: AppColors.ink),
            const SizedBox(width: 8),
          ],
          // Only a full-width button has a bound to shrink the label into.
          if (expand) Flexible(child: text) else text,
        ],
      ),
    );
  }
}

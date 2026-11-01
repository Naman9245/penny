import 'package:flutter/material.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/brutal_theme.dart';
import 'package:penny/widgets/brutal_pressable.dart';

/// A round brutal button holding one icon.
class BrutalIconButton extends StatelessWidget {
  const BrutalIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.color = AppColors.white,
    this.size = 48,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final Color color;

  /// Outer diameter, border included.
  final double size;

  @override
  Widget build(BuildContext context) {
    final border = context.brutal.borderWidth;
    return BrutalPressable(
      onPressed: onPressed,
      semanticLabel: semanticLabel,
      color: color,
      shadowOffset: const Offset(3, 3),
      child: SizedBox.square(
        dimension: size - border * 2,
        child: Icon(icon, size: 24, color: AppColors.ink),
      ),
    );
  }
}

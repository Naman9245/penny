import 'package:flutter/material.dart';
import 'package:penny/core/theme/app_colors.dart';

/// A small outlined tile holding an icon, in a colour that says what the
/// card beside it is about. It never stands alone: a title always says it
/// in words too.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 36,
  });

  final IconData icon;
  final Color color;

  /// Outer size, border included.
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size * 0.32),
          border: Border.all(color: AppColors.ink, width: 2),
        ),
        child: Icon(icon, size: size * 0.52, color: AppColors.ink),
      ),
    );
  }
}

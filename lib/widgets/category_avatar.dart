import 'package:flutter/material.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/brutal_theme.dart';
import 'package:penny/models/category.dart';

/// A category's face: its drawn icon on its colour.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({
    super.key,
    required this.category,
    this.size = 44,
    this.raised = false,
  });

  final Category category;
  final double size;

  /// Adds the hard shadow, for tiles you can tap.
  final bool raised;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: brutalDecoration(
          color: category.color,
          radius: size * 0.3,
          borderWidth: 2,
          shadow: raised ? kSmallShadow : Offset.zero,
        ),
        child: Icon(category.icon, size: size * 0.5, color: AppColors.ink),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:penny/core/theme/brutal_theme.dart';
import 'package:penny/models/category.dart';

/// A category's face. Emoji for now; character art replaces this one widget.
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
        // An icon, not text: it must not grow past its tile.
        child: Text(
          category.emoji,
          textScaler: TextScaler.noScaling,
          style: TextStyle(fontSize: size * 0.46, height: 1.2),
        ),
      ),
    );
  }
}

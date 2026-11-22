import 'package:flutter/material.dart';
import 'package:penny/core/theme/app_colors.dart';

/// A list that sits flat on the page between two hairlines, as Penny's
/// crafted look has it: rows of entries, categories, shops or settings. A
/// card you act on, or one that is a single thing like Penny's, keeps the
/// bold outline instead (BrutalCard).
class FlatSection extends StatelessWidget {
  const FlatSection({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 12),
  });

  final Widget child;

  /// Room inside the hairlines. Rows that pad themselves take none.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: AppColors.hairline),
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

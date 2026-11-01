import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/models/category.dart';
import 'package:penny/widgets/category_avatar.dart';

/// Category tiles, up to four to a row. A tap picks one; ✓ on the keypad
/// saves.
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({
    super.key,
    required this.categories,
    required this.onTap,
    this.selectedId,
  });

  final List<Category> categories;
  final ValueChanged<Category> onTap;
  final String? selectedId;

  static const _gap = 8.0;

  // "Subscriptions", the longest single word, needs about 80 px at the normal
  // text size. Columns drop from four to two as text grows or the screen
  // narrows, so a label never breaks mid-word.
  static const _minTileWidth = 86.0;

  @override
  Widget build(BuildContext context) {
    final captionSize = AppText.caption.fontSize!;
    final growth =
        MediaQuery.textScalerOf(context).scale(captionSize) / captionSize;
    return LayoutBuilder(
      builder: (context, constraints) {
        final fits =
            (constraints.maxWidth + _gap) ~/ (_minTileWidth * growth + _gap);
        final columns = math.max(2, math.min(4, fits));
        final width = ((constraints.maxWidth - _gap * (columns - 1)) / columns)
            .floorToDouble();
        return Wrap(
          spacing: _gap,
          runSpacing: 16,
          children: [
            for (final category in categories)
              SizedBox(
                width: width,
                child: _Tile(
                  category: category,
                  // Until one is picked, every tile is raised and looks
                  // tappable; after, only the pick stands up.
                  raised: selectedId == null || category.id == selectedId,
                  selected: category.id == selectedId,
                  onTap: () => onTap(category),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.category,
    required this.raised,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool raised;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: category.label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            AnimatedScale(
              scale: selected ? 1.1 : 1,
              duration: const Duration(milliseconds: 120),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CategoryAvatar(category: category, size: 54, raised: raised),
                  if (selected)
                    const Positioned(top: -7, right: -7, child: _PickedBadge()),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              category.label,
              style: AppText.caption,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// The ✓ on the picked tile. Pops in when it appears.
class _PickedBadge extends StatelessWidget {
  const _PickedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.ink,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 2),
      ),
      child: const Icon(Icons.check_rounded, size: 15, color: AppColors.white),
    ).animate().scale(
      begin: const Offset(0.3, 0.3),
      duration: 220.ms,
      curve: Curves.easeOutBack,
    );
  }
}

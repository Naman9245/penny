import 'package:flutter/material.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/theme/brutal_theme.dart';

class PillNavItem {
  const PillNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// The dark pill tab bar. The active tab is a cream pill with its label;
/// the rest are outlined circles.
class PillNavBar extends StatelessWidget {
  const PillNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<PillNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Container(
            height: 64,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(kPillRadius),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  if (i == currentIndex)
                    Expanded(child: _ActiveTab(item: items[i]))
                  else
                    _Tab(item: items[i], onTap: () => onSelect(i)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveTab extends StatelessWidget {
  const _ActiveTab({required this.item});

  final PillNavItem item;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: true,
      label: item.label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(kPillRadius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 22, color: AppColors.ink),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                item.label,
                style: AppText.label,
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

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.onTap});

  final PillNavItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: false,
      label: item.label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF4A4A4A), width: 1.5),
          ),
          child: Icon(item.icon, size: 22, color: AppColors.cream),
        ),
      ),
    );
  }
}

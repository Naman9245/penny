import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/theme/brutal_theme.dart';

class PillNavItem {
  const PillNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// The dark pill tab bar. A cream pill slides to the selected tab and opens
/// up to show its label; the other tabs are outlined circles.
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

  static const _circle = 52.0;
  static const _gap = 6.0;
  static const _slide = Duration(milliseconds: 380);
  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.disableAnimationsOf(context);
    final duration = animate ? _slide : Duration.zero;

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
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The selected tab gets whatever the circles leave over.
                final wide =
                    constraints.maxWidth - (items.length - 1) * (_circle + _gap);
                double leftOf(int i) =>
                    i * (_circle + _gap) + (i > currentIndex ? wide - _circle : 0);

                // The pill and every tab move on the same clock, so the pill
                // always lands exactly under the tab that is opening up.
                final tabs = [
                  for (var i = 0; i < items.length; i++)
                    AnimatedPositioned(
                      key: ValueKey(i),
                      duration: duration,
                      curve: _curve,
                      left: leftOf(i),
                      top: 0,
                      bottom: 0,
                      width: i == currentIndex ? wide : _circle,
                      child: _Tab(
                        item: items[i],
                        selected: i == currentIndex,
                        animate: animate,
                        onTap: () => onSelect(i),
                      ),
                    ),
                ];
                return Stack(
                  children: [
                    // Unselected tabs sit under the pill: one crossing it
                    // mid-slide passes behind, and the pill slides off the
                    // tab it is leaving. Keys keep each tab's state as the
                    // order changes.
                    for (var i = 0; i < tabs.length; i++)
                      if (i != currentIndex) tabs[i],
                    AnimatedPositioned(
                      key: const ValueKey('pill'),
                      duration: duration,
                      curve: _curve,
                      left: leftOf(currentIndex),
                      top: 0,
                      bottom: 0,
                      width: wide,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.cream,
                          borderRadius: BorderRadius.all(Radius.circular(kPillRadius)),
                        ),
                      ),
                    ),
                    tabs[currentIndex],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  const _Tab({
    required this.item,
    required this.selected,
    required this.animate,
    required this.onTap,
  });

  final PillNavItem item;
  final bool selected;
  final bool animate;
  final VoidCallback onTap;

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> with SingleTickerProviderStateMixin {
  bool _down = false;

  // The icon pops when its tab becomes the selected one.
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _popScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.3, end: 0.92).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.92, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
  ]).animate(_pop);

  @override
  void didUpdateWidget(_Tab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected && widget.animate) {
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _setDown(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final fade = widget.animate ? const Duration(milliseconds: 200) : Duration.zero;

    return Semantics(
      button: true,
      selected: selected,
      label: widget.item.label,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setDown(true),
        onTapUp: (_) => _setDown(false),
        onTapCancel: () => _setDown(false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        // Squishes while pressed.
        child: AnimatedScale(
          scale: _down ? 0.88 : 1,
          duration: widget.animate ? const Duration(milliseconds: 110) : Duration.zero,
          curve: Curves.easeOut,
          child: AnimatedContainer(
            // The ring vanishes at once on the tab the pill is arriving at,
            // and fades in on the one it is leaving.
            duration: selected ? Duration.zero : fade,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kPillRadius),
              border: Border.all(
                color: selected ? Colors.transparent : const Color(0xFF4A4A4A),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _popScale,
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: selected ? AppColors.ink : AppColors.cream),
                    duration: fade,
                    builder: (context, color, _) =>
                        Icon(widget.item.icon, size: 22, color: color),
                  ),
                ),
                if (selected)
                  Flexible(
                    // The label unrolls in step with the pill opening up.
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: widget.animate ? 0 : 1, end: 1),
                      duration: PillNavBar._slide,
                      curve: PillNavBar._curve,
                      builder: (context, t, child) => ClipRect(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          widthFactor: t,
                          child: Opacity(opacity: t, child: child),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          widget.item.label,
                          style: AppText.label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.clip,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

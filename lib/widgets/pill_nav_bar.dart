import 'dart:math' as math;

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

/// The dark pill tab bar. A cream pill sits under the selected tab, which
/// opens up to show its label; the other tabs are outlined circles.
///
/// Tap a tab and the pill slides there. Or grab the bar and drag: the pill
/// follows the finger, ticks as it passes each tab, and snaps to the nearest
/// one on release. A quick flick carries it on to the next tab.
///
/// On a narrow phone or at a large text size the circles get smaller, so the
/// open tab always has room for its label.
class PillNavBar extends StatefulWidget {
  const PillNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
    this.trailing,
  });

  final List<PillNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  /// A round button beside the bar, in the same row, built as tall as the
  /// bar. The app puts Add here.
  final Widget Function(double size)? trailing;

  @override
  State<PillNavBar> createState() => _PillNavBarState();
}

// The icon and the label of a tab, and the space between them.
const _iconSize = 22.0;
const _labelGap = 6.0;

class _PillNavBarState extends State<PillNavBar>
    with SingleTickerProviderStateMixin {
  static const _maxCircle = 52.0;
  // Small enough for the longest label at the largest text size, beside
  // Add, on a 360 dp phone.
  static const _minCircle = 38.0;
  static const _gap = 6.0;
  static const _inset = 6.0;
  static const _trailingGap = 10.0;

  // Room either side of the open tab's icon and label.
  static const _openMargin = 6.0;

  // One tab along: a circle and a gap. Set at each layout.
  double _step = _maxCircle + _gap;

  // Where the pill is, in tabs: 0 is under the first tab, 1.5 is halfway
  // between the second and the third. Everything on the bar is drawn from it.
  late final AnimationController _position = AnimationController(
    vsync: this,
    upperBound: (widget.items.length - 1).toDouble(),
    value: widget.currentIndex.toDouble(),
  );
  int? _target;
  bool _dragging = false;

  bool get _animate => !MediaQuery.disableAnimationsOf(context);

  @override
  void didUpdateWidget(PillNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex && !_dragging) {
      _slideTo(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  void _slideTo(int index) {
    if (_position.isAnimating && _target == index) return;
    _target = index;
    final distance = (index - _position.value).abs();
    _position.animateTo(
      index.toDouble(),
      duration: _animate
          ? Duration(milliseconds: (160 + 110 * distance).round())
          : Duration.zero,
      curve: Curves.easeOutCubic,
    );
  }

  void _onDragStart(DragStartDetails details) {
    _dragging = true;
    _position.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final before = _position.value.round();
    // One tab's width of finger travel moves the pill one tab, so it stays
    // under the finger. The controller clamps it to the ends of the bar.
    _position.value += details.delta.dx / _step;
    if (_position.value.round() != before) HapticFeedback.selectionClick();
  }

  void _onDragEnd(DragEndDetails details) {
    _dragging = false;
    final velocity = details.primaryVelocity ?? 0;
    final flick = velocity.abs() > 300 ? velocity.sign * 0.45 : 0.0;
    final last = widget.items.length - 1;
    final target = math.max(
      0,
      math.min(last, (_position.value + flick).round()),
    );
    _slideTo(target);
    if (target != widget.currentIndex) widget.onSelect(target);
  }

  /// How big the closed tabs can be in [width] and still leave the open tab
  /// room for the longest label. The bar and the button beside it are a
  /// circle plus the bar's inset tall.
  double _circleFor(BuildContext context, double width) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    // Measured in the style the label is drawn in.
    final style = DefaultTextStyle.of(context).style.merge(AppText.label);
    var label = 0.0;
    for (final item in widget.items) {
      final painter = TextPainter(
        text: TextSpan(text: item.label, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      label = math.max(label, painter.width);
      painter.dispose();
    }
    final open = _iconSize + _labelGap + label + 2 * _openMargin;
    final hasTrailing = widget.trailing != null;
    // The circles, and the button when there is one, share what's left.
    final circles = widget.items.length - 1 + (hasTrailing ? 1 : 0);
    if (circles == 0) return _maxCircle;
    final fixed =
        2 * _inset +
        (widget.items.length - 1) * _gap +
        open +
        (hasTrailing ? 2 * _inset + _trailingGap : 0);
    return ((width - fixed) / circles).clamp(_minCircle, _maxCircle);
  }

  @override
  Widget build(BuildContext context) {
    final animate = _animate;
    final trailing = widget.trailing;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: LayoutBuilder(
            builder: (context, row) {
              final circle = _circleFor(context, row.maxWidth);
              final height = circle + 2 * _inset;
              _step = circle + _gap;
              return Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: _onDragStart,
                      onHorizontalDragUpdate: _onDragUpdate,
                      onHorizontalDragEnd: _onDragEnd,
                      onHorizontalDragCancel: () {
                        if (_dragging) _onDragEnd(DragEndDetails());
                      },
                      child: Container(
                        height: height,
                        padding: const EdgeInsets.all(_inset),
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(kPillRadius),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // The open tab gets whatever the circles leave
                            // over.
                            final wide =
                                constraints.maxWidth -
                                (widget.items.length - 1) * _step;
                            return AnimatedBuilder(
                              animation: _position,
                              builder: (context, _) =>
                                  _track(wide, circle, animate),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: _trailingGap),
                    trailing(height),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _track(double wide, double circle, bool animate) {
    final p = _position.value;
    final count = widget.items.length;
    // A tab is fully open with the pill right under it and closed by the
    // time the pill is one tab away.
    final openness = [for (var i = 0; i < count; i++) _unit(1 - (p - i).abs())];
    final lefts = <double>[];
    final widths = <double>[];
    var x = 0.0;
    for (final open in openness) {
      final width = circle + (wide - circle) * open;
      lefts.add(x);
      widths.add(width);
      x += width + _gap;
    }

    Widget tab(int i) => Positioned(
      key: ValueKey(i),
      left: lefts[i],
      top: 0,
      bottom: 0,
      width: widths[i],
      child: _Tab(
        item: widget.items[i],
        openness: openness[i],
        selected: i == widget.currentIndex,
        animate: animate,
        onTap: () => widget.onSelect(i),
      ),
    );

    return Stack(
      children: [
        // Closed tabs sit under the pill, so the pill slides over them; the
        // ones it is opening sit on top. Keys keep each tab's state as the
        // order changes.
        for (var i = 0; i < count; i++)
          if (openness[i] == 0) tab(i),
        Positioned(
          key: const ValueKey('pill'),
          left: p * _step,
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
        for (var i = 0; i < count; i++)
          if (openness[i] > 0) tab(i),
      ],
    );
  }
}

double _unit(double value) => value < 0 ? 0 : (value > 1 ? 1 : value);

class _Tab extends StatefulWidget {
  const _Tab({
    required this.item,
    required this.openness,
    required this.selected,
    required this.animate,
    required this.onTap,
  });

  final PillNavItem item;

  /// 0 is a closed circle, 1 is fully open on the pill.
  final double openness;
  final bool selected;
  final bool animate;
  final VoidCallback onTap;

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> with SingleTickerProviderStateMixin {
  static const _ring = Color(0xFF4A4A4A);

  bool _down = false;

  // The icon pops when its tab becomes the selected one.
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _popScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.3,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.3,
        end: 0.92,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 0.92,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
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
    final open = widget.openness;
    // A tab's middle crosses onto the pill at about a quarter open. The icon
    // turns from cream to ink around there, and the ring is gone before it
    // could show on the pill.
    final onPill = _unit((open - 0.12) / 0.24);
    final ring = 1 - _unit(open / 0.3);
    return Semantics(
      button: true,
      selected: widget.selected,
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
          duration: widget.animate
              ? const Duration(milliseconds: 110)
              : Duration.zero,
          curve: Curves.easeOut,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kPillRadius),
              border: Border.all(
                color: Color.lerp(_ring.withAlpha(0), _ring, ring)!,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _popScale,
                  child: Icon(
                    widget.item.icon,
                    size: _iconSize,
                    color: Color.lerp(AppColors.cream, AppColors.ink, onPill),
                  ),
                ),
                if (open > 0)
                  Flexible(
                    // The label unrolls as the tab opens.
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: open,
                        child: Opacity(
                          opacity: open,
                          child: Padding(
                            padding: const EdgeInsets.only(left: _labelGap),
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

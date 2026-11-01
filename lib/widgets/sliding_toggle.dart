import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/theme/brutal_theme.dart';

class ToggleOption<T> {
  const ToggleOption({
    required this.value,
    required this.label,
    required this.color,
  });

  final T value;
  final String label;

  /// The highlight's colour while it sits on this option.
  final Color color;
}

/// A pill toggle whose highlight slides between options.
///
/// Tap an option, or drag the highlight across: it ticks as it passes each
/// option, blends between their colours on the way, and snaps to the nearest
/// one on release.
class SlidingToggle<T> extends StatefulWidget {
  const SlidingToggle({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<ToggleOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  State<SlidingToggle<T>> createState() => _SlidingToggleState<T>();
}

class _SlidingToggleState<T> extends State<SlidingToggle<T>>
    with SingleTickerProviderStateMixin {
  static const _segmentPadding = 18.0;

  // Where the highlight is, in options: 0.5 is halfway between the first two.
  late final AnimationController _position = AnimationController(
    vsync: this,
    upperBound: (widget.options.length - 1).toDouble(),
    value: _index.toDouble(),
  );
  double _segmentWidth = 1;
  bool _dragging = false;

  int get _index =>
      math.max(0, widget.options.indexWhere((o) => o.value == widget.value));

  bool get _animate => !MediaQuery.disableAnimationsOf(context);

  @override
  void didUpdateWidget(SlidingToggle<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && !_dragging) _slideTo(_index);
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  void _slideTo(int index) {
    _position.animateTo(
      index.toDouble(),
      duration: _animate ? const Duration(milliseconds: 260) : Duration.zero,
      curve: Curves.easeOutCubic,
    );
  }

  void _select(int index) {
    _slideTo(index);
    final value = widget.options[index].value;
    if (value == widget.value) return;
    HapticFeedback.selectionClick();
    widget.onChanged(value);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final before = _position.value.round();
    _position.value += details.delta.dx / _segmentWidth;
    if (_position.value.round() != before) HapticFeedback.selectionClick();
  }

  void _onDragEnd(DragEndDetails details) {
    _dragging = false;
    final velocity = details.primaryVelocity ?? 0;
    final flick = velocity.abs() > 300 ? velocity.sign * 0.45 : 0.0;
    final last = widget.options.length - 1;
    final target = math.max(
      0,
      math.min(last, (_position.value + flick).round()),
    );
    _slideTo(target);
    final value = widget.options[target].value;
    if (value != widget.value) widget.onChanged(value);
  }

  // Blending through hue keeps the in-between colours pastel; a straight RGB
  // blend of pink and mint goes muddy grey in the middle.
  Color _colorAt(double position) {
    final from = position.floor();
    if (from >= widget.options.length - 1) return widget.options.last.color;
    return HSVColor.lerp(
      HSVColor.fromColor(widget.options[from].color),
      HSVColor.fromColor(widget.options[from + 1].color),
      position - from,
    )!.toColor();
  }

  @override
  Widget build(BuildContext context) {
    // Every option is as wide as the longest label, so the highlight keeps
    // its size as it slides.
    final scaler = MediaQuery.textScalerOf(context);
    final widest = widget.options
        .map((option) => _labelWidth(option.label, scaler))
        .reduce(math.max);
    _segmentWidth = widest + 2 * _segmentPadding;

    return GestureDetector(
      onHorizontalDragStart: (_) {
        _dragging = true;
        _position.stop();
      },
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      onHorizontalDragCancel: () {
        if (_dragging) _onDragEnd(DragEndDetails());
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: brutalDecoration(
          color: AppColors.white,
          radius: kPillRadius,
        ),
        child: AnimatedBuilder(
          animation: _position,
          builder: (context, _) {
            final position = _position.value;
            return Stack(
              children: [
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: position * _segmentWidth,
                  width: _segmentWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _colorAt(position),
                      borderRadius: BorderRadius.circular(kPillRadius),
                      border: Border.all(color: AppColors.ink, width: 2),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < widget.options.length; i++)
                      Semantics(
                        button: true,
                        selected: i == _index,
                        label: widget.options[i].label,
                        onTap: () => _select(i),
                        excludeSemantics: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _select(i),
                          child: SizedBox(
                            width: _segmentWidth,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                widget.options[i].label,
                                style: AppText.label,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static double _labelWidth(String label, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: AppText.label),
      textScaler: scaler,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}

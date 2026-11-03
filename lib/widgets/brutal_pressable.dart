import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/brutal_theme.dart';
import 'package:penny/widgets/press_timing.dart';

/// A brutal surface that sinks into its shadow while pressed.
///
/// The building block behind buttons, chips, keypad keys and tappable cards.
/// A tap shows the whole press before it acts, so nothing opens before the
/// button has visibly gone down.
class BrutalPressable extends StatefulWidget {
  const BrutalPressable({
    super.key,
    required this.onPressed,
    required this.child,
    this.onLongPress,
    this.color = AppColors.white,
    this.radius = kPillRadius,
    this.padding = EdgeInsets.zero,
    this.shadowOffset,
    this.borderWidth,
    this.semanticLabel,
    this.selected,
    this.haptics = true,
    this.waitForPress = true,
  });

  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Widget child;
  final Color color;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// Shadow at rest. Defaults to the theme's offset.
  final Offset? shadowOffset;
  final double? borderWidth;
  final String? semanticLabel;
  final bool? selected;

  /// A light tap on press. Off for widgets that pick their own feedback.
  final bool haptics;

  /// Whether [onPressed] waits until the press has been seen. Off for keys
  /// that type, which act at once.
  final bool waitForPress;

  @override
  State<BrutalPressable> createState() => _BrutalPressableState();
}

class _BrutalPressableState extends State<BrutalPressable>
    with PressTiming<BrutalPressable> {
  bool get _enabled => widget.onPressed != null || widget.onLongPress != null;

  @override
  bool get waitsForPress => widget.waitForPress;

  void _handleTap() {
    if (widget.haptics) HapticFeedback.lightImpact();
    actAfterPress(widget.onPressed!);
  }

  @override
  Widget build(BuildContext context) {
    final brutal = context.brutal;
    final rest = widget.shadowOffset ?? brutal.shadowOffset;
    final sink = pressed ? rest : Offset.zero;

    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: _enabled,
        selected: widget.selected,
        label: widget.semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? (_) => pressDown() : null,
          onTapUp: _enabled ? (_) => pressUp() : null,
          onTapCancel: pressCancel,
          onTap: widget.onPressed == null ? null : _handleTap,
          onLongPress: widget.onLongPress,
          child: Opacity(
            opacity: _enabled ? 1 : 0.45,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(sink.dx, sink.dy, 0),
              padding: widget.padding,
              decoration: brutalDecoration(
                color: widget.color,
                radius: widget.radius,
                borderWidth: widget.borderWidth ?? brutal.borderWidth,
                shadow: rest - sink,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

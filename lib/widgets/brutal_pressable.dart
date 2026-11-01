import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/brutal_theme.dart';

/// A brutal surface that sinks into its shadow while pressed.
///
/// The building block behind buttons, chips, keypad keys and tappable cards.
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

  @override
  State<BrutalPressable> createState() => _BrutalPressableState();
}

class _BrutalPressableState extends State<BrutalPressable> {
  bool _down = false;
  Timer? _release;

  bool get _enabled => widget.onPressed != null || widget.onLongPress != null;

  void _setDown(bool down) {
    if (mounted && _down != down) setState(() => _down = down);
  }

  void _press() {
    _release?.cancel();
    _setDown(true);
  }

  void _unpress() {
    _release?.cancel();
    // Hold the sunk state for a moment so even a quick tap is seen.
    _release = Timer(const Duration(milliseconds: 90), () => _setDown(false));
  }

  void _handleTap() {
    if (widget.haptics) HapticFeedback.lightImpact();
    widget.onPressed!();
  }

  @override
  void dispose() {
    _release?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brutal = context.brutal;
    final rest = widget.shadowOffset ?? brutal.shadowOffset;
    final sink = _down ? rest : Offset.zero;

    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: _enabled,
        selected: widget.selected,
        label: widget.semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? (_) => _press() : null,
          onTapUp: _enabled ? (_) => _unpress() : null,
          onTapCancel: () => _setDown(false),
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

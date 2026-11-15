import 'package:flutter/material.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/widgets/press_timing.dart';

/// A row or cell that shows it's pressed before it acts, for what isn't a
/// brutal surface: it darkens a touch, and shrinks a little when
/// [pressedScale] says so. Like the brutal buttons, [onTap] runs once the
/// press has been seen.
class PressableArea extends StatefulWidget {
  const PressableArea({
    super.key,
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.pressedScale = 1,
    this.radius = 0,
  });

  final VoidCallback? onTap;
  final Widget child;

  /// Runs on a long press, as picking entries does.
  final VoidCallback? onLongPress;

  /// Its size while pressed; 1 keeps its size and only darkens it.
  final double pressedScale;

  /// The corners of the darkening, to match the child's.
  final double radius;

  @override
  State<PressableArea> createState() => _PressableAreaState();
}

class _PressableAreaState extends State<PressableArea>
    with PressTiming<PressableArea> {
  static const _tween = Duration(milliseconds: 90);

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: onTap == null ? null : (_) => pressDown(),
      onTapUp: onTap == null ? null : (_) => pressUp(),
      onTapCancel: pressCancel,
      onTap: onTap == null ? null : () => actAfterPress(onTap),
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: pressed ? widget.pressedScale : 1,
        duration: _tween,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: _tween,
          curve: Curves.easeOut,
          foregroundDecoration: BoxDecoration(
            color: AppColors.ink.withValues(alpha: pressed ? 0.08 : 0),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

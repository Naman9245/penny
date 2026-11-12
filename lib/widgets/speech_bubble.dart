import 'package:flutter/material.dart';
import 'package:penny/core/theme/app_colors.dart';

/// What Penny says, in a bubble whose tail points left at her.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({
    super.key,
    required this.child,
    this.color = AppColors.white,
    this.padding = const EdgeInsets.fromLTRB(12, 10, 12, 11),
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(color: color, shape: const BubbleBorder()),
      child: Padding(
        padding: const EdgeInsets.only(left: BubbleBorder.tail),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A rounded box with an ink outline and a tail on its left side, near the
/// top.
class BubbleBorder extends ShapeBorder {
  const BubbleBorder();

  /// How far the tail reaches out from the box.
  static const tail = 9.0;

  static const _radius = 18.0;

  /// Where the tail's tip sits, down from the top.
  static const _tailAt = 26.0;

  static const _width = 2.0;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.only(left: tail);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(_width), textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final left = rect.left + tail;
    final r = _radius;
    // The tail stays on the straight part of the side, however short the
    // bubble is.
    final at = (rect.top + _tailAt).clamp(rect.top + r, rect.bottom - r);
    return Path()
      ..moveTo(left + r, rect.top)
      ..lineTo(rect.right - r, rect.top)
      ..arcToPoint(Offset(rect.right, rect.top + r), radius: Radius.circular(r))
      ..lineTo(rect.right, rect.bottom - r)
      ..arcToPoint(
        Offset(rect.right - r, rect.bottom),
        radius: Radius.circular(r),
      )
      ..lineTo(left + r, rect.bottom)
      ..arcToPoint(Offset(left, rect.bottom - r), radius: Radius.circular(r))
      ..lineTo(left, at + 7)
      ..lineTo(rect.left + 1, at)
      ..lineTo(left, at - 7)
      ..lineTo(left, rect.top + r)
      ..arcToPoint(Offset(left + r, rect.top), radius: Radius.circular(r))
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    canvas.drawPath(
      getOuterPath(rect.deflate(_width / 2), textDirection: textDirection),
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = _width
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  ShapeBorder scale(double t) => this;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/models/penny_mood.dart';

/// Penny, drawn in code: a yellow coin with purple headphones and a face for
/// each mood. Real art replaces the painter in Milestone 5; callers stay the
/// same.
class PennyMascot extends StatelessWidget {
  const PennyMascot({
    super.key,
    this.mood = PennyMood.neutral,
    this.size = 96,
    this.bob = true,
  });

  final PennyMood mood;
  final double size;

  /// A gentle idle float. Skipped when the system asks for less motion.
  final bool bob;

  @override
  Widget build(BuildContext context) {
    final penny = Semantics(
      image: true,
      label: 'Penny, ${mood.label.toLowerCase()}',
      child: CustomPaint(size: Size.square(size), painter: _PennyPainter(mood)),
    );
    if (!bob || MediaQuery.disableAnimationsOf(context)) return penny;
    return penny
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .moveY(
          begin: 0,
          end: -size * 0.05,
          duration: 1400.ms,
          curve: Curves.easeInOut,
        );
  }
}

/// Draws Penny on a 100 x 100 grid, scaled to the canvas.
class _PennyPainter extends CustomPainter {
  _PennyPainter(this.mood);

  final PennyMood mood;

  static const _center = Offset(50, 56);
  static const _radius = 35.0;
  static const _eyes = [Offset(39, 55), Offset(61, 55)];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    final outline = _stroke(AppColors.ink, 3.2);
    _drawBand(canvas);
    canvas.drawCircle(_center, _radius, Paint()..color = AppColors.yellow);
    canvas.drawCircle(_center, _radius - 5.5, _stroke(AppColors.coinRim, 2));
    canvas.drawCircle(const Offset(36, 38), 3.2, Paint()..color = AppColors.white);
    canvas.drawCircle(_center, _radius, outline);
    // The ₹ is unreadable on small Pennys, so it only appears on big ones.
    _drawCups(canvas, outline, withRupee: size.width >= 56);
    _drawFace(canvas, outline);

    canvas.restore();
  }

  void _drawBand(Canvas canvas) {
    final rect = Rect.fromCircle(center: const Offset(50, 54), radius: 41);
    const start = 195 * math.pi / 180;
    const sweep = 150 * math.pi / 180;
    canvas.drawArc(rect, start, sweep, false, _stroke(AppColors.ink, 11));
    canvas.drawArc(rect, start, sweep, false, _stroke(AppColors.lavender, 5.5));
  }

  void _drawCups(Canvas canvas, Paint outline, {required bool withRupee}) {
    for (final x in const [13.0, 87.0]) {
      final cup = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, 58), width: 13, height: 25),
        const Radius.circular(6.5),
      );
      canvas.drawRRect(cup, Paint()..color = AppColors.lavender);
      canvas.drawRRect(cup, outline);
    }
    if (!withRupee) return;
    final rupee = TextPainter(
      text: const TextSpan(
        text: '₹',
        style: TextStyle(
          fontFamily: AppText.displayFamily,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1,
          color: AppColors.ink,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    rupee.paint(canvas, Offset(13 - rupee.width / 2, 58 - rupee.height / 2));
    rupee.dispose();
  }

  void _drawFace(Canvas canvas, Paint outline) {
    final ink = Paint()..color = AppColors.ink;
    switch (mood) {
      case PennyMood.happy:
        _cheeks(canvas);
        _closedEyes(canvas, outline);
        _openSmile(canvas, width: 18, depth: 10);
      case PennyMood.neutral:
        _cheeks(canvas);
        _dotEyes(canvas, ink, height: 8);
        canvas.drawArc(
          Rect.fromCenter(center: const Offset(50, 64), width: 14, height: 9),
          0.35,
          math.pi - 0.7,
          false,
          outline,
        );
      case PennyMood.worried:
        _dotEyes(canvas, ink, height: 9);
        canvas.drawLine(const Offset(33, 46), const Offset(43, 43), outline);
        canvas.drawLine(const Offset(57, 43), const Offset(67, 46), outline);
        canvas.drawPath(
          Path()
            ..moveTo(41, 70)
            ..quadraticBezierTo(45.5, 66, 50, 70)
            ..quadraticBezierTo(54.5, 74, 59, 70),
          outline,
        );
        _drop(canvas, const Offset(76, 36));
      case PennyMood.sad:
        _dotEyes(canvas, ink, height: 7, lookDown: true);
        canvas.drawArc(
          Rect.fromCenter(center: const Offset(50, 73), width: 16, height: 10),
          math.pi + 0.35,
          math.pi - 0.7,
          false,
          outline,
        );
        _drop(canvas, const Offset(64, 61), scale: 0.7);
      case PennyMood.celebrating:
        _cheeks(canvas);
        _closedEyes(canvas, outline);
        _openSmile(canvas, width: 22, depth: 13);
        _sparkle(canvas, const Offset(10, 14), 5.5);
        _sparkle(canvas, const Offset(90, 12), 4.5);
    }
  }

  void _dotEyes(
    Canvas canvas,
    Paint ink, {
    required double height,
    bool lookDown = false,
  }) {
    final shine = Paint()..color = AppColors.white;
    for (final eye in _eyes) {
      final center = lookDown ? eye.translate(0, 1.5) : eye;
      canvas.drawOval(
        Rect.fromCenter(center: center, width: 6, height: height),
        ink,
      );
      canvas.drawCircle(center.translate(1.2, -height / 4), 1.1, shine);
    }
  }

  /// Happy, squeezed-shut eyes: two little arches.
  void _closedEyes(Canvas canvas, Paint outline) {
    for (final eye in _eyes) {
      canvas.drawArc(
        Rect.fromCenter(center: eye.translate(0, 2), width: 10, height: 9),
        math.pi + 0.3,
        math.pi - 0.6,
        false,
        outline,
      );
    }
  }

  void _openSmile(Canvas canvas, {required double width, required double depth}) {
    const top = 64.0;
    final mouth = Path()
      ..moveTo(50 + width / 2, top)
      ..arcTo(
        Rect.fromCenter(
          center: const Offset(50, top),
          width: width,
          height: depth * 2,
        ),
        0,
        math.pi,
        false,
      )
      ..close();
    canvas.drawPath(mouth, Paint()..color = AppColors.ink);
    canvas.save();
    canvas.clipPath(mouth);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(50, top + depth * 0.95),
        width: width * 0.6,
        height: depth * 0.9,
      ),
      Paint()..color = AppColors.pink,
    );
    canvas.restore();
  }

  void _cheeks(Canvas canvas) {
    final blush = Paint()..color = AppColors.pink;
    for (final x in const [30.0, 70.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 64), width: 8, height: 5),
        blush,
      );
    }
  }

  /// A sweat drop or tear, hanging from [tip].
  void _drop(Canvas canvas, Offset tip, {double scale = 1}) {
    final r = 4 * scale;
    final drop = Path()
      ..moveTo(tip.dx, tip.dy)
      ..quadraticBezierTo(tip.dx + r, tip.dy + r * 1.2, tip.dx + r, tip.dy + r * 2)
      ..arcToPoint(Offset(tip.dx - r, tip.dy + r * 2), radius: Radius.circular(r))
      ..quadraticBezierTo(tip.dx - r, tip.dy + r * 1.2, tip.dx, tip.dy)
      ..close();
    canvas.drawPath(drop, Paint()..color = AppColors.sky);
    canvas.drawPath(drop, _stroke(AppColors.ink, 2));
  }

  void _sparkle(Canvas canvas, Offset c, double r) {
    final star = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(star, Paint()..color = AppColors.yellow);
    canvas.drawPath(star, _stroke(AppColors.ink, 1.8));
  }

  static Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  bool shouldRepaint(_PennyPainter oldDelegate) => oldDelegate.mood != mood;
}

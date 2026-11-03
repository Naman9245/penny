import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/models/penny_mood.dart';
import 'package:penny/models/penny_pose.dart';

/// Penny, drawn in code: a yellow coin with purple headphones and a face for
/// each mood, or for a moment like thinking.
///
/// She moves unless told to keep still or the phone asks for less motion:
/// she floats and blinks, bops to her music when happy, sweats when worried,
/// cries when sad, and hops in confetti when celebrating. A new mood lands
/// with a squash and a bounce.
class PennyMascot extends StatefulWidget {
  const PennyMascot({
    super.key,
    this.mood = PennyMood.neutral,
    this.pose,
    this.size = 96,
    this.bob = true,
  });

  final PennyMood mood;

  /// A face for a moment rather than a mood, shown instead of [mood]'s.
  final PennyPose? pose;
  final double size;

  /// Whether she moves at all. Small Pennys beside text keep still.
  final bool bob;

  @override
  State<PennyMascot> createState() => _PennyMascotState();
}

/// How long Penny's idle loop runs before it repeats, in seconds. Every
/// motion's period divides it, so the loop joins up without a jump.
const _loopSeconds = 12;

class _PennyMascotState extends State<PennyMascot>
    with TickerProviderStateMixin {
  late final _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: _loopSeconds),
  );
  late final _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final _confetti = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  var _moving = false;

  bool get _celebrating =>
      widget.pose == null && widget.mood == PennyMood.celebrating;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setMoving();
  }

  @override
  void didUpdateWidget(PennyMascot old) {
    super.didUpdateWidget(old);
    _setMoving();
    if (_moving && (old.mood != widget.mood || old.pose != widget.pose)) {
      _bounce.forward(from: 0);
      if (_celebrating) _confetti.forward(from: 0);
    }
  }

  void _setMoving() {
    final moving = widget.bob && !MediaQuery.disableAnimationsOf(context);
    if (moving == _moving) return;
    _moving = moving;
    if (moving) {
      _loop.repeat();
      if (_celebrating) _confetti.forward(from: 0);
    } else {
      _loop.reset();
      _bounce.reset();
      _confetti.reset();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _bounce.dispose();
    _confetti.dispose();
    super.dispose();
  }

  _Motion get _motion => _Motion(
    _moving ? _loop.value * _loopSeconds : null,
    widget.mood,
    widget.pose,
  );

  /// Floating, hopping or bopping: squashed about her feet, tilted about
  /// her middle, on a 100 x 100 grid scaled to her size.
  Matrix4 _bodyMatrix() {
    final motion = _motion;
    final unit = widget.size / 100;
    return Matrix4.identity()
      ..translateByDouble(0, motion.lift * unit, 0, 1)
      ..translateByDouble(50 * unit, 91 * unit, 0, 1)
      ..scaleByDouble(motion.squashX, motion.squashY, 1, 1)
      ..translateByDouble(-50 * unit, -91 * unit, 0, 1)
      ..translateByDouble(50 * unit, 56 * unit, 0, 1)
      ..rotateZ(motion.tilt)
      ..translateByDouble(-50 * unit, -56 * unit, 0, 1);
  }

  /// The squash and stretch as a new mood lands, about her feet.
  Matrix4 _bounceMatrix() {
    final p = _bounce.value;
    final squash = 0.14 * math.sin(3 * math.pi * p) * (1 - p);
    final unit = widget.size / 100;
    return Matrix4.identity()
      ..translateByDouble(50 * unit, 91 * unit, 0, 1)
      ..scaleByDouble(1 + squash, 1 - squash, 1, 1)
      ..translateByDouble(-50 * unit, -91 * unit, 0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final pose = widget.pose;
    final size = Size.square(widget.size);
    return Semantics(
      image: true,
      label: 'Penny, ${pose?.label ?? widget.mood.label.toLowerCase()}',
      child: SizedBox.fromSize(
        size: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedBuilder(
              animation: _loop,
              builder: (context, child) => Transform(
                key: const ValueKey('penny-body'),
                transform: _bodyMatrix(),
                child: child,
              ),
              child: AnimatedBuilder(
                animation: _bounce,
                builder: (context, child) => Transform(
                  key: const ValueKey('penny-bounce'),
                  transform: _bounceMatrix(),
                  child: child,
                ),
                child: CustomPaint(
                  size: size,
                  painter: _PennyPainter(
                    mood: widget.mood,
                    pose: pose,
                    loop: _moving ? _loop : null,
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _confetti,
              builder: (context, _) => _confetti.isAnimating
                  ? CustomPaint(
                      key: const ValueKey('penny-confetti'),
                      size: size,
                      painter: _ConfettiPainter(_confetti.value),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Just Penny's face for [mood], without the coin: for small places, like
/// a day on the mood calendar. It matches her face everywhere else, and
/// keeps still.
class PennyFace extends StatelessWidget {
  const PennyFace({super.key, required this.mood, this.size = 32});

  final PennyMood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _FacePainter(mood));
  }
}

/// Where Penny's moving parts are [t] seconds into her loop, or at rest
/// when [t] is null.
class _Motion {
  const _Motion(this.t, this.mood, this.pose);

  static const still = _Motion(null, PennyMood.neutral, null);

  final double? t;
  final PennyMood mood;
  final PennyPose? pose;

  bool get _celebrating => pose == null && mood == PennyMood.celebrating;

  /// How far a [period]-second cycle has come, from 0 to 1.
  double _phase(double period, [double offset = 0]) =>
      (((t ?? 0) + offset) % period) / period;

  /// How far she's lifted off her spot, in grid units; up is negative. She
  /// floats, slower when sad or sleepy, and hops when celebrating.
  double get lift {
    if (t == null) return 0;
    if (_celebrating) {
      final p = _phase(1.5);
      return p < 0.4 ? -9 * math.sin(math.pi * p / 0.4) : 0;
    }
    final slow =
        pose == PennyPose.sleepy || (pose == null && mood == PennyMood.sad);
    final (height, period) = slow ? (3.0, 4.0) : (5.0, 3.0);
    return -height / 2 * (1 - math.cos(2 * math.pi * _phase(period)));
  }

  /// A squash as she lands a hop: wider and shorter.
  double get _landing {
    if (t == null || !_celebrating) return 0;
    final p = _phase(1.5);
    return p >= 0.4 && p < 0.52
        ? 0.07 * math.sin(math.pi * (p - 0.4) / 0.12)
        : 0;
  }

  double get squashX => 1 + _landing;
  double get squashY => 1 - _landing;

  /// Her head's tilt, in radians, bopping to her music when happy.
  double get tilt => t != null && pose == null && mood == PennyMood.happy
      ? 0.07 * math.sin(2 * math.pi * _phase(1.2))
      : 0;

  /// How open her eyes are, from 1 open to 0 shut: she blinks now and then.
  double get eyesOpen {
    final t = this.t;
    if (t == null) return 1;
    for (final start in const [1.8, 5.6, 8.9, 9.3]) {
      final p = (t - start) / 0.2;
      if (p >= 0 && p < 1) return 1 - math.sin(math.pi * p);
    }
    return 1;
  }

  /// The worried sweat drop: how far it has slid, and how much shows.
  (double, double) get sweat {
    if (t == null) return (0, 1);
    final p = _phase(1.5);
    return (4 * p * p, p < 0.8 ? 1 : (1 - p) / 0.2);
  }

  /// The sad tear: how big it has grown, how far it has fallen, and how
  /// much shows.
  (double, double, double) get tear {
    if (t == null) return (1, 0, 1);
    final p = _phase(2.4);
    if (p < 0.3) return (0.3 + 0.7 * p / 0.3, 0, 1);
    final fall = (p - 0.3) / 0.7;
    return (1, 14 * fall * fall, fall < 0.7 ? 1 : (1 - fall) / 0.3);
  }

  /// Sparkle [i]'s size, twinkling.
  double sparkle(int i) => t == null
      ? 1
      : 0.75 + 0.35 * math.sin(2 * math.pi * _phase(0.75) + i * math.pi);

  /// Thought dot [i]'s swell, rippling outward.
  double thought(int i) => t == null
      ? 1
      : 0.7 + 0.45 * math.max(0, math.sin(2 * math.pi * (_phase(1.2) - i / 3)));

  /// How far her eyes have scanned sideways behind her glasses.
  double get scan => t == null ? 0 : 2.2 * math.sin(2 * math.pi * _phase(2));

  /// How brightly the idea bulb shines.
  double get glow =>
      t == null ? 1 : 0.8 + 0.2 * (1 + math.sin(2 * math.pi * _phase(1)));

  /// Sleepy z [i]: how far it has floated up, from 0 to 1.
  double z(int i) => t == null ? (i == 0 ? 0.25 : 0.75) : _phase(3, i * 1.5);
}

/// Draws Penny on a 100 x 100 grid, scaled to the canvas.
class _PennyPainter extends CustomPainter {
  _PennyPainter({required this.mood, required this.pose, this.loop})
    : super(repaint: loop);

  final PennyMood mood;
  final PennyPose? pose;

  /// Her idle loop while she moves; without it she keeps still.
  final Animation<double>? loop;

  static const _center = Offset(50, 56);
  static const _radius = 35.0;

  @override
  void paint(Canvas canvas, Size size) {
    final loop = this.loop;
    final motion = loop == null
        ? _Motion.still
        : _Motion(loop.value * _loopSeconds, mood, pose);
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    final outline = _stroke(AppColors.ink, 3.2);
    _drawBand(canvas);
    canvas.drawCircle(_center, _radius, Paint()..color = AppColors.yellow);
    canvas.drawCircle(_center, _radius - 5.5, _stroke(AppColors.coinRim, 2));
    canvas.drawCircle(
      const Offset(36, 38),
      3.2,
      Paint()..color = AppColors.white,
    );
    canvas.drawCircle(_center, _radius, outline);
    // The ₹ is unreadable on small Pennys, so it only appears on big ones.
    _drawCups(canvas, outline, withRupee: size.width >= 56);
    if (pose case final pose?) {
      _Pose.draw(canvas, pose, outline, motion);
    } else {
      _Face.draw(canvas, mood, outline, motion: motion);
    }

    canvas.restore();
  }

  void _drawBand(Canvas canvas) {
    final rect = Rect.fromCircle(center: const Offset(50, 54), radius: 41);
    const start = 195 * math.pi / 180;
    const sweep = 150 * math.pi / 180;
    canvas.drawArc(rect, start, sweep, false, _stroke(AppColors.ink, 11));
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      _stroke(AppColors.headphones, 5.5),
    );
  }

  void _drawCups(Canvas canvas, Paint outline, {required bool withRupee}) {
    for (final x in const [13.0, 87.0]) {
      final cup = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, 58), width: 13, height: 25),
        const Radius.circular(6.5),
      );
      canvas.drawRRect(cup, Paint()..color = AppColors.headphones);
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

  @override
  bool shouldRepaint(_PennyPainter oldDelegate) =>
      oldDelegate.mood != mood ||
      oldDelegate.pose != pose ||
      oldDelegate.loop != loop;
}

/// Draws only the face: the middle 60 x 60 of Penny's 100 x 100 grid,
/// filling the canvas, so it reads when small.
class _FacePainter extends CustomPainter {
  _FacePainter(this.mood);

  final PennyMood mood;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 60, size.height / 60);
    // The face sits around (50, 60) on Penny's grid.
    canvas.translate(-20, -30);
    _Face.draw(canvas, mood, _stroke(AppColors.ink, 4), sparkles: false);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FacePainter oldDelegate) => oldDelegate.mood != mood;
}

/// Penny's face for each mood, drawn around the middle of the 100 x 100
/// grid with [outline] for its lines.
abstract final class _Face {
  static const _eyes = [Offset(39, 55), Offset(61, 55)];

  static void draw(
    Canvas canvas,
    PennyMood mood,
    Paint outline, {
    bool sparkles = true,
    _Motion motion = _Motion.still,
  }) {
    final ink = Paint()..color = AppColors.ink;
    switch (mood) {
      case PennyMood.happy:
        _cheeks(canvas);
        _closedEyes(canvas, outline);
        _openSmile(canvas, width: 18, depth: 10);
      case PennyMood.neutral:
        _cheeks(canvas);
        _dotEyes(canvas, ink, height: 8, open: motion.eyesOpen);
        canvas.drawArc(
          Rect.fromCenter(center: const Offset(50, 64), width: 14, height: 9),
          0.35,
          math.pi - 0.7,
          false,
          outline,
        );
      case PennyMood.worried:
        _dotEyes(canvas, ink, height: 9, open: motion.eyesOpen);
        canvas.drawLine(const Offset(33, 46), const Offset(43, 43), outline);
        canvas.drawLine(const Offset(57, 43), const Offset(67, 46), outline);
        canvas.drawPath(
          Path()
            ..moveTo(41, 70)
            ..quadraticBezierTo(45.5, 66, 50, 70)
            ..quadraticBezierTo(54.5, 74, 59, 70),
          outline,
        );
        final (slid, shows) = motion.sweat;
        _drop(canvas, Offset(76, 36 + slid), opacity: shows);
      case PennyMood.sad:
        _dotEyes(canvas, ink, height: 7, lookDown: true, open: motion.eyesOpen);
        canvas.drawArc(
          Rect.fromCenter(center: const Offset(50, 73), width: 16, height: 10),
          math.pi + 0.35,
          math.pi - 0.7,
          false,
          outline,
        );
        final (grown, fallen, shows) = motion.tear;
        _drop(
          canvas,
          Offset(64, 61 + fallen),
          scale: 0.7 * grown,
          opacity: shows,
        );
      case PennyMood.celebrating:
        _cheeks(canvas);
        _closedEyes(canvas, outline);
        _openSmile(canvas, width: 22, depth: 13);
        if (sparkles) {
          _sparkle(canvas, const Offset(10, 14), 5.5 * motion.sparkle(0));
          _sparkle(canvas, const Offset(90, 12), 4.5 * motion.sparkle(1));
        }
    }
  }

  /// Open eyes, [open] of the way: shut mid-blink they're short lines.
  /// [look] turns them, like up and aside when thinking.
  static void _dotEyes(
    Canvas canvas,
    Paint ink, {
    required double height,
    bool lookDown = false,
    double open = 1,
    Offset look = Offset.zero,
  }) {
    final shine = Paint()..color = AppColors.white;
    for (final eye in _eyes) {
      final center = (lookDown ? eye.translate(0, 1.5) : eye) + look;
      if (open < 0.25) {
        canvas.drawLine(
          center.translate(-3.2, 0),
          center.translate(3.2, 0),
          _stroke(AppColors.ink, 2.2),
        );
        continue;
      }
      final tall = height * open;
      canvas.drawOval(
        Rect.fromCenter(center: center, width: 6, height: tall),
        ink,
      );
      if (open > 0.7) {
        canvas.drawCircle(center.translate(1.2, -tall / 4), 1.1, shine);
      }
    }
  }

  /// Happy, squeezed-shut eyes: two little arches.
  static void _closedEyes(Canvas canvas, Paint outline) {
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

  static void _openSmile(
    Canvas canvas, {
    required double width,
    required double depth,
  }) {
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

  static void _cheeks(Canvas canvas) {
    final blush = Paint()..color = AppColors.pink;
    for (final x in const [30.0, 70.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 64), width: 8, height: 5),
        blush,
      );
    }
  }

  /// A sweat drop or tear, hanging from [tip].
  static void _drop(
    Canvas canvas,
    Offset tip, {
    double scale = 1,
    double opacity = 1,
  }) {
    if (opacity <= 0) return;
    final r = 4 * scale;
    final drop = Path()
      ..moveTo(tip.dx, tip.dy)
      ..quadraticBezierTo(
        tip.dx + r,
        tip.dy + r * 1.2,
        tip.dx + r,
        tip.dy + r * 2,
      )
      ..arcToPoint(
        Offset(tip.dx - r, tip.dy + r * 2),
        radius: Radius.circular(r),
      )
      ..quadraticBezierTo(tip.dx - r, tip.dy + r * 1.2, tip.dx, tip.dy)
      ..close();
    canvas.drawPath(
      drop,
      Paint()..color = AppColors.sky.withValues(alpha: opacity),
    );
    canvas.drawPath(drop, _stroke(AppColors.ink.withValues(alpha: opacity), 2));
  }

  static void _sparkle(Canvas canvas, Offset c, double r) {
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
}

/// Penny's faces for moments rather than moods, drawn like [_Face].
abstract final class _Pose {
  static void draw(
    Canvas canvas,
    PennyPose pose,
    Paint outline,
    _Motion motion,
  ) {
    final ink = Paint()..color = AppColors.ink;
    switch (pose) {
      case PennyPose.thinking:
        // Eyes up and aside, a small "hmm", and a trail of thought.
        _Face._dotEyes(
          canvas,
          ink,
          height: 8,
          open: motion.eyesOpen,
          look: const Offset(2, -2.5),
        );
        canvas.drawLine(const Offset(45, 69), const Offset(55, 67), outline);
        for (final (i, (at, r)) in const [
          (Offset(80, 22), 2.0),
          (Offset(87, 14), 2.8),
          (Offset(95, 5), 3.6),
        ].indexed) {
          final radius = r * motion.thought(i);
          canvas.drawCircle(at, radius, Paint()..color = AppColors.white);
          canvas.drawCircle(at, radius, _stroke(AppColors.ink, 1.6));
        }
      case PennyPose.analyzing:
        // Round glasses, her eyes scanning behind them.
        _Face._dotEyes(
          canvas,
          ink,
          height: 7,
          open: motion.eyesOpen,
          look: Offset(motion.scan, 0.5),
        );
        final rim = _stroke(AppColors.ink, 2.6);
        final glint = _stroke(AppColors.white, 1.6);
        for (final eye in _Face._eyes) {
          canvas.drawCircle(
            eye,
            8,
            Paint()..color = AppColors.white.withValues(alpha: 0.3),
          );
          canvas.drawCircle(eye, 8, rim);
          canvas.drawArc(
            Rect.fromCircle(center: eye, radius: 5.5),
            math.pi * 1.1,
            0.7,
            false,
            glint,
          );
        }
        canvas.drawLine(const Offset(47, 55), const Offset(53, 55), rim);
        canvas.drawLine(const Offset(45, 69), const Offset(55, 69), outline);
      case PennyPose.idea:
        // Wide eyes, a smile, and a bulb lit above her.
        _Face._cheeks(canvas);
        _Face._dotEyes(canvas, ink, height: 9.5, open: motion.eyesOpen);
        _Face._openSmile(canvas, width: 14, depth: 7);
        _bulb(canvas, const Offset(88, 13), motion.glow);
      case PennyPose.sleepy:
        // Shut eyes, a small "o", and z's floating up.
        for (final eye in _Face._eyes) {
          canvas.drawArc(
            Rect.fromCenter(center: eye.translate(0, -1), width: 10, height: 7),
            0.3,
            math.pi - 0.6,
            false,
            outline,
          );
        }
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(50, 69), width: 5, height: 6),
          ink,
        );
        for (var i = 0; i < 2; i++) {
          _z(canvas, motion.z(i));
        }
    }
  }

  /// A lit bulb at [c], its rays as long as [glow] says.
  static void _bulb(Canvas canvas, Offset c, double glow) {
    final ray = _stroke(AppColors.ink, 1.6);
    for (final angle in const [-2.6, -math.pi / 2, -0.55]) {
      final towards = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(c + towards * 8, c + towards * (8 + 4 * glow), ray);
    }
    canvas.drawCircle(c, 5.5, Paint()..color = AppColors.yellow);
    canvas.drawCircle(c, 5.5, _stroke(AppColors.ink, 1.8));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c.translate(0, 7.5), width: 5, height: 3.5),
        const Radius.circular(1),
      ),
      Paint()..color = AppColors.ink,
    );
  }

  /// A "z" floating up from her head and fading, [p] of the way along.
  static void _z(Canvas canvas, double p) {
    final shows = math.sin(math.pi * p);
    if (shows <= 0.02) return;
    final s = 4 + 3 * p;
    final at = Offset(76 + 6 * p, 26 - 18 * p);
    canvas.drawPath(
      Path()
        ..moveTo(at.dx, at.dy)
        ..lineTo(at.dx + s, at.dy)
        ..lineTo(at.dx, at.dy + s)
        ..lineTo(at.dx + s, at.dy + s),
      _stroke(AppColors.ink.withValues(alpha: shows), 1.8),
    );
  }
}

/// A burst of confetti from Penny, [p] of the way through, on her 100 x 100
/// grid: it flies up and out, falls, and fades.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.p);

  final double p;

  static const _colors = [
    AppColors.pink,
    AppColors.mint,
    AppColors.sky,
    AppColors.lavender,
    AppColors.yellow,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final shows = p < 0.7 ? 1.0 : (1 - p) / 0.3;
    final edge = _stroke(AppColors.ink.withValues(alpha: shows), 0.8);
    for (var i = 0; i < 16; i++) {
      final angle = -math.pi / 2 + (i - 7.5) * 0.2;
      final reach = 38 + (i * 7 % 5) * 6;
      canvas.save();
      canvas.translate(
        50 + math.cos(angle) * reach * p,
        50 + math.sin(angle) * reach * p + 55 * p * p,
      );
      canvas.rotate(angle + p * 8);
      final piece = Rect.fromCenter(
        center: Offset.zero,
        width: 4.5,
        height: 2.6,
      );
      canvas.drawRect(
        piece,
        Paint()..color = _colors[i % _colors.length].withValues(alpha: shows),
      );
      canvas.drawRect(piece, edge);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.p != p;
}

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

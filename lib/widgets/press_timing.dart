import 'dart:async';

import 'package:flutter/widgets.dart';

/// The timing behind everything pressable in the app: a press shows long
/// enough to be seen, and a tap acts only once it has, so nothing opens
/// before what was tapped has visibly gone down.
///
/// Wire [pressDown], [pressUp] and [pressCancel] to a gesture detector's
/// tap callbacks, run the tap through [actAfterPress], and draw [pressed].
mixin PressTiming<T extends StatefulWidget> on State<T> {
  /// How long a tap shows its press before it acts: the sink, then a beat
  /// at the bottom.
  static const shown = Duration(milliseconds: 150);

  /// How long something that acts at once stays pressed after a tap.
  static const brief = Duration(milliseconds: 90);

  /// Whether it looks pressed right now.
  bool get pressed => _pressed;
  var _pressed = false;
  Timer? _release;
  Timer? _act;

  /// How long the current press has lasted.
  final _held = Stopwatch();

  /// Whether a tap waits for its press to show. Keys that type don't.
  bool get waitsForPress => true;

  /// Not when the phone asks for less motion: there's no press to watch.
  bool get _waits => waitsForPress && !MediaQuery.disableAnimationsOf(context);

  /// What's left of [shown] since the press began.
  Duration get _left {
    final left = shown - _held.elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  void _show(bool pressed) {
    if (mounted && _pressed != pressed) setState(() => _pressed = pressed);
  }

  void pressDown() {
    _release?.cancel();
    _held
      ..reset()
      ..start();
    _show(true);
  }

  /// Stays pressed until the tap acts, or [brief] for what acts at once,
  /// so even a quick tap is seen.
  void pressUp() {
    _release?.cancel();
    _release = Timer(_waits ? _left : brief, () => _show(false));
  }

  void pressCancel() {
    _release?.cancel();
    _show(false);
  }

  /// Runs [action] once the press has been seen. A tap while one waits is
  /// dropped, so a quick double tap can't open something twice.
  void actAfterPress(VoidCallback action) {
    if (_act?.isActive ?? false) return;
    final wait = _waits ? _left : Duration.zero;
    if (wait == Duration.zero) {
      action();
      return;
    }
    _act = Timer(wait, () {
      if (mounted) action();
    });
  }

  @override
  void dispose() {
    _release?.cancel();
    _act?.cancel();
    super.dispose();
  }
}

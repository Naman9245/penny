import 'package:flutter/material.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/widgets/money_text.dart';

// A screen's first look: cards rise into place one after another, and its
// big amounts count up. Each plays once a screen, so a card scrolled away
// and back, or rebuilt, never comes in twice, and none of it plays when the
// phone asks for less motion.

/// Remembers what its screen has brought in already.
class FirstShowScope extends StatefulWidget {
  const FirstShowScope({super.key, required this.child});

  final Widget child;

  @override
  State<FirstShowScope> createState() => _FirstShowScopeState();
}

class _FirstShowScopeState extends State<FirstShowScope> {
  final _shown = <Object>{};

  @override
  Widget build(BuildContext context) =>
      _Shown(shown: _shown, child: widget.child);
}

class _Shown extends InheritedWidget {
  const _Shown({required this.shown, required super.child});

  final Set<Object> shown;

  @override
  bool updateShouldNotify(_Shown oldWidget) => false;
}

/// Whether [id] should play its first look now: only the first time its
/// screen asks, and never when the phone asks for less motion.
bool _playsFirstShow(BuildContext context, Object id) {
  if (MediaQuery.disableAnimationsOf(context)) return false;
  final scope = context.getInheritedWidgetOfExactType<_Shown>();
  return scope?.shown.add(id) ?? true;
}

/// Rises into place and fades in the first time its screen shows it,
/// [index] beats after the screen's first card.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.id,
    required this.child,
    this.index = 0,
  });

  /// What it is on its screen, so it plays once.
  final Object id;
  final Widget child;
  final int index;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  static const _rise = 420;
  static const _beat = 70;

  // Its wait for the cards before it is the start of its own animation, so
  // there's no timer to outlive it.
  late final int _wait = _beat * widget.index.clamp(0, 8);
  late final _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _wait + _rise),
    value: 1,
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Interval(_wait / (_wait + _rise), 1, curve: Curves.easeOutCubic),
  );
  var _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;
    if (_playsFirstShow(context, widget.id)) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - _curve.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// [MoneyText] that counts up to its amount the first time its screen
/// shows it, and slides from the old amount to a new one after, so a change
/// is seen.
class AnimatedMoney extends StatefulWidget {
  const AnimatedMoney(
    this.paise, {
    super.key,
    required this.id,
    this.type,
    this.style = AppText.h3,
  });

  final int paise;

  /// What it is on its screen, so it counts up once.
  final Object id;
  final TxnType? type;
  final TextStyle style;

  @override
  State<AnimatedMoney> createState() => _AnimatedMoneyState();
}

class _AnimatedMoneyState extends State<AnimatedMoney>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 1,
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late int _from = widget.paise;
  var _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;
    if (!_playsFirstShow(context, widget.id)) return;
    _from = 0;
    _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(AnimatedMoney oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paise == widget.paise) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    _from = _shown;
    _controller.forward(from: 0);
  }

  /// What shows now: whole rupees on the way, the exact amount at the end.
  int get _shown {
    final t = _curve.value;
    if (t >= 1) return widget.paise;
    final paise = _from + (widget.paise - _from) * t;
    return (paise / 100).round() * 100;
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // Read out once, as it ends up.
      label: switch (widget.type) {
        TxnType.debit => '−${formatPaise(widget.paise)}',
        TxnType.credit => '+${formatPaise(widget.paise)}',
        null => formatPaise(widget.paise),
      },
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, _) =>
            MoneyText(_shown, type: widget.type, style: widget.style),
      ),
    );
  }
}

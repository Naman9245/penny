import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:penny/core/theme/brutal_theme.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/widgets/brutal_pressable.dart';

/// A chunky number pad that adds and takes away like a calculator, with a
/// wide ✓ key that saves. A pad of our own, because the system keyboard
/// would cover the category grid.
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({
    super.key,
    required this.onKey,
    required this.onBackspace,
    required this.onClear,
    required this.onDone,
    required this.ready,
    this.compact = false,
  });

  /// A digit, ".", "+" or "−".
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;

  /// Long-press on backspace.
  final VoidCallback onClear;

  /// The ✓ key.
  final VoidCallback onDone;

  /// There is something to save, so ✓ lights up.
  final bool ready;

  /// Smaller keys, once an amount is typed, so the categories above get the
  /// room. Still easy to tap.
  final bool compact;

  static const _rowHeight = 58.0;
  static const _compactRowHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    Widget cell(Widget key, {int flex = 1}) => Expanded(
      flex: flex,
      child: Padding(padding: const EdgeInsets.all(4), child: key),
    );
    Widget digit(String label, {String? semanticLabel}) => cell(
      _Key(
        key: ValueKey('key-$label'),
        semanticLabel: semanticLabel,
        onTap: () {
          HapticFeedback.selectionClick();
          onKey(label);
        },
        child: Text(label, style: AppText.h2),
      ),
    );
    Widget row(List<Widget> cells) => Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: cells,
      ),
    );

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 4 * (compact ? _compactRowHeight : _rowHeight),
          child: Column(
            children: [
              row([
                digit('1'),
                digit('2'),
                digit('3'),
                cell(
                  _Key(
                    key: const ValueKey('key-⌫'),
                    semanticLabel: 'Backspace, hold to clear',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onBackspace();
                    },
                    onLongPress: onClear,
                    child: const Icon(
                      Icons.backspace_outlined,
                      size: 22,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ]),
              row([
                digit('4'),
                digit('5'),
                digit('6'),
                digit('+', semanticLabel: 'Plus'),
              ]),
              row([
                digit('7'),
                digit('8'),
                digit('9'),
                digit('−', semanticLabel: 'Minus'),
              ]),
              row([
                digit('.'),
                digit('0'),
                cell(
                  _Key(
                    key: const ValueKey('key-done'),
                    semanticLabel: 'Save',
                    color: ready ? AppColors.yellow : AppColors.white,
                    types: false,
                    onTap: onDone,
                    child: const Icon(
                      Icons.check_rounded,
                      size: 34,
                      color: AppColors.ink,
                    ),
                  ),
                  flex: 2,
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    super.key,
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.semanticLabel,
    this.color = AppColors.white,
    this.types = true,
  });

  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final Color color;
  final Widget child;

  /// A key that types acts at once; ✓ shows its press first, like any
  /// button that closes the screen.
  final bool types;

  @override
  Widget build(BuildContext context) {
    return BrutalPressable(
      onPressed: onTap,
      onLongPress: onLongPress,
      haptics: false,
      waitForPress: !types,
      color: color,
      radius: 16,
      shadowOffset: kSmallShadow,
      semanticLabel: semanticLabel,
      child: SizedBox.expand(child: Center(child: child)),
    );
  }
}

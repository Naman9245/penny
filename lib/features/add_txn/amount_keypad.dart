import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/widgets/brutal_pressable.dart';

/// A chunky number pad with a tall ✓ key that saves. A pad of our own,
/// because the system keyboard would cover the category grid.
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({
    super.key,
    required this.onKey,
    required this.onBackspace,
    required this.onClear,
    required this.onDone,
    required this.ready,
  });

  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;

  /// Long-press on backspace.
  final VoidCallback onClear;

  /// The ✓ key.
  final VoidCallback onDone;

  /// Amount and category are both in, so ✓ lights up.
  final bool ready;

  static const _rowHeight = 58.0;

  @override
  Widget build(BuildContext context) {
    Widget cell(Widget key, {int flex = 1}) => Expanded(
          flex: flex,
          child: Padding(padding: const EdgeInsets.all(4), child: key),
        );
    Widget digit(String label, {int flex = 1}) => cell(
          _Key(
            key: ValueKey('key-$label'),
            onTap: () {
              HapticFeedback.selectionClick();
              onKey(label);
            },
            child: Text(label, style: AppText.h2),
          ),
          flex: flex,
        );
    Widget row(List<Widget> cells) => Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells),
        );

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: SizedBox(
          height: 4 * _rowHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    row([digit('1'), digit('2'), digit('3')]),
                    row([digit('4'), digit('5'), digit('6')]),
                    row([digit('7'), digit('8'), digit('9')]),
                    row([digit('.'), digit('0', flex: 2)]),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                    cell(
                      _Key(
                        key: const ValueKey('key-done'),
                        semanticLabel: 'Save',
                        color: ready ? AppColors.yellow : AppColors.white,
                        onTap: onDone,
                        child: const Icon(
                          Icons.check_rounded,
                          size: 34,
                          color: AppColors.ink,
                        ),
                      ),
                      flex: 3,
                    ),
                  ],
                ),
              ),
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
  });

  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BrutalPressable(
      onPressed: onTap,
      onLongPress: onLongPress,
      haptics: false,
      color: color,
      radius: 16,
      shadowOffset: const Offset(3, 3),
      semanticLabel: semanticLabel,
      child: SizedBox.expand(child: Center(child: child)),
    );
  }
}

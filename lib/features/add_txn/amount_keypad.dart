import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/widgets/brutal_pressable.dart';

/// A chunky number pad. The system keyboard would cover the category grid.
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({
    super.key,
    required this.onKey,
    required this.onBackspace,
    required this.onClear,
  });

  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;

  /// Long-press on backspace.
  final VoidCallback onClear;

  static const _backspace = '⌫';
  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['.', '0', _backspace],
  ];

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in _rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    for (final label in row)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _Key(
                            key: ValueKey('key-$label'),
                            label: label,
                            onTap: () {
                              if (label == _backspace) {
                                onBackspace();
                              } else {
                                onKey(label);
                              }
                            },
                            onLongPress: label == _backspace ? onClear : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    super.key,
    required this.label,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final backspace = label == AmountKeypad._backspace;
    return BrutalPressable(
      onPressed: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      onLongPress: onLongPress,
      haptics: false,
      radius: 16,
      shadowOffset: const Offset(3, 3),
      semanticLabel: backspace ? 'Backspace, hold to clear' : null,
      child: SizedBox(
        height: 50,
        child: Center(
          child: backspace
              ? const Icon(Icons.backspace_outlined, size: 22, color: AppColors.ink)
              : Text(label, style: AppText.h2),
        ),
      ),
    );
  }
}

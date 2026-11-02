import 'package:flutter/material.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/widgets/amount_keypad.dart';

/// Asks for an amount on Penny's keypad, in a bottom sheet. Returns it in
/// paise, 0 when the user clears what was there, or null when they back out.
/// With [maxPaise], ✓ only lights up up to that amount.
Future<int?> showAmountSheet(
  BuildContext context, {
  required String title,
  String? hint,
  int? initialPaise,
  int? maxPaise,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _AmountSheet(
      title: title,
      hint: hint,
      initialPaise: initialPaise,
      maxPaise: maxPaise,
    ),
  );
}

class _AmountSheet extends StatefulWidget {
  const _AmountSheet({
    required this.title,
    required this.hint,
    required this.initialPaise,
    required this.maxPaise,
  });

  final String title;
  final String? hint;
  final int? initialPaise;
  final int? maxPaise;

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  late String _text = switch (widget.initialPaise) {
    final paise? when paise > 0 => paiseToAmountText(paise),
    _ => '',
  };

  int get _paise => amountTextToPaise(_text);

  bool get _ready =>
      _paise > 0 && (widget.maxPaise == null || _paise <= widget.maxPaise!);

  @override
  Widget build(BuildContext context) {
    final hint = widget.hint;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
            child: Row(
              children: [
                Expanded(child: Text(widget.title, style: AppText.h2)),
                if ((widget.initialPaise ?? 0) > 0)
                  TextButton(
                    key: const ValueKey('amount-clear'),
                    onPressed: () => Navigator.pop(context, 0),
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
              child: Text(hint, style: AppText.bodyMuted),
            ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatAmountText(_text),
                key: const ValueKey('amount-shown'),
                style: AppText.hero,
              ),
            ),
          ),
          const SizedBox(height: 10),
          AmountKeypad(
            onKey: (key) => setState(() => _text = applyAmountKey(_text, key)),
            onBackspace: () => setState(() => _text = dropAmountKey(_text)),
            onClear: () => setState(() => _text = ''),
            onDone: () {
              if (_ready) Navigator.pop(context, _paise);
            },
            ready: _ready,
          ),
        ],
      ),
    );
  }
}

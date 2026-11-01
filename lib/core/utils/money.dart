import 'package:intl/intl.dart';

// Amounts are integer paise everywhere; rupees exist only on screen.

/// Most whole-rupee digits the keypad accepts (₹99,99,999).
const kMaxRupeeDigits = 7;

final _grouped = NumberFormat('#,##,##0', 'en_IN');

/// ₹ with Indian grouping: 10151300 → "₹1,01,513", 24950 → "₹249.50".
String formatPaise(int paise) {
  final sign = paise < 0 ? '−' : '';
  final abs = paise.abs();
  final rupees = _grouped.format(abs ~/ 100);
  final rest = abs % 100;
  if (rest == 0) return '$sign₹$rupees';
  return '$sign₹$rupees.${rest.toString().padLeft(2, '0')}';
}

/// Short ₹ for chart axes: ₹950, ₹12.5K, ₹1.2L, ₹3.4Cr.
String compactRupees(int paise) {
  final rupees = paise / 100;
  if (rupees < 1000) return '₹${rupees.round()}';
  if (rupees < 100000) return '₹${_short(rupees / 1000)}K';
  if (rupees < 10000000) return '₹${_short(rupees / 100000)}L';
  return '₹${_short(rupees / 10000000)}Cr';
}

String _short(double value) => value >= 100
    ? value.round().toString()
    : value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');

/// The keypad buffer as shown while typing: "123456.5" → "₹1,23,456.5".
String formatAmountText(String text) {
  if (text.isEmpty) return '₹0';
  final dot = text.indexOf('.');
  final whole = dot == -1 ? text : text.substring(0, dot);
  final grouped = _grouped.format(int.parse(whole.isEmpty ? '0' : whole));
  return dot == -1 ? '₹$grouped' : '₹$grouped${text.substring(dot)}';
}

/// Applies one keypad press ("0"–"9" or ".") to the buffer. Presses that
/// would make it invalid are ignored.
String applyAmountKey(String text, String key) {
  if (key == '.') {
    if (text.contains('.')) return text;
    return text.isEmpty ? '0.' : '$text.';
  }
  final dot = text.indexOf('.');
  if (dot != -1) return text.length - dot > 2 ? text : '$text$key';
  if (text == '0') return key;
  if (text.length >= kMaxRupeeDigits) return text;
  return '$text$key';
}

String dropAmountKey(String text) =>
    text.isEmpty ? text : text.substring(0, text.length - 1);

/// "249.5" → 24950. Partial input such as "" or "0." is 0.
int amountTextToPaise(String text) {
  if (text.isEmpty) return 0;
  final dot = text.indexOf('.');
  final whole = dot == -1 ? text : text.substring(0, dot);
  final fraction = dot == -1 ? '' : text.substring(dot + 1);
  return int.parse(whole.isEmpty ? '0' : whole) * 100 +
      int.parse(fraction.padRight(2, '0').substring(0, 2));
}

/// The keypad buffer that shows [paise], for editing: 24950 → "249.50".
String paiseToAmountText(int paise) {
  final rest = paise % 100;
  if (rest == 0) return '${paise ~/ 100}';
  return '${paise ~/ 100}.${rest.toString().padLeft(2, '0')}';
}

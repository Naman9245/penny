import 'dart:math' as math;

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

// The keypad also adds and takes away, like a calculator: "3000+2500-200".
// Each term follows the single-amount rules above, and "-" is the minus key.

/// Most terms one sum may have.
const kMaxSumTerms = 10;

/// Applies one keypad press, a digit, "." or "+" and "−", to a sum being
/// typed. Presses that would make it invalid are ignored, and a second
/// operator in a row replaces the first.
String applySumKey(String text, String key) {
  if (key == '+' || key == '−' || key == '-') {
    final op = key == '+' ? '+' : '-';
    if (text.isEmpty) return op == '-' ? '-' : text;
    final last = text[text.length - 1];
    if (last == '+' || last == '-') {
      // A lone leading minus stays as it is.
      if (text.length == 1) return text;
      return '${text.substring(0, text.length - 1)}$op';
    }
    if (_signedTerms(text).length >= kMaxSumTerms) return text;
    return '${text.endsWith('.') ? dropAmountKey(text) : text}$op';
  }
  final cut = math.max(text.lastIndexOf('+'), text.lastIndexOf('-'));
  final term = text.substring(cut + 1);
  return '${text.substring(0, cut + 1)}${applyAmountKey(term, key)}';
}

/// Whether [text] adds or takes anything away, so its total is worth
/// showing apart from what was typed.
bool isSum(String text) => text.contains('+') || text.contains('-');

/// The total of a sum being typed, in paise: "3000+2500-200" → 530000.
/// Partial terms such as "" or "0." count as nothing, and the total can come
/// out at zero or below.
int sumTextToPaise(String text) => _signedTerms(text)
    .fold(0, (total, term) => total + term.sign * amountTextToPaise(term.text));

/// A sum being typed, as shown: "3000+2500-200" → "₹3,000 + ₹2,500 − ₹200".
String formatSumText(String text) {
  if (!isSum(text)) return formatAmountText(text);
  final parts = <String>[];
  for (final (i, term) in _signedTerms(text).indexed) {
    if (i > 0 || term.sign < 0) parts.add(term.sign < 0 ? '−' : '+');
    if (term.text.isNotEmpty) parts.add(formatAmountText(term.text));
  }
  return parts.join(' ');
}

List<({int sign, String text})> _signedTerms(String text) {
  final terms = <({int sign, String text})>[];
  var sign = 1;
  var start = 0;
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char != '+' && char != '-') continue;
    if (i > 0) terms.add((sign: sign, text: text.substring(start, i)));
    sign = char == '+' ? 1 : -1;
    start = i + 1;
  }
  return terms..add((sign: sign, text: text.substring(start)));
}

/// The keypad buffer that shows [paise], for editing: 24950 → "249.50".
String paiseToAmountText(int paise) {
  final rest = paise % 100;
  if (rest == 0) return '${paise ~/ 100}';
  return '${paise ~/ 100}.${rest.toString().padLeft(2, '0')}';
}

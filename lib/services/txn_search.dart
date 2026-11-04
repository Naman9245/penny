import 'package:penny/core/utils/money.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/services/money_kinds.dart';

// Searching a month's entries on Transactions, and adding up what's shown.

/// An amount as searched: "250", "₹1,200", "rs 99.50".
final _amount = RegExp(r'^\d+(?:\.\d{1,2})?$');
final _amountMarks = RegExp(r'[₹,\s]|rs\.?', caseSensitive: false);

/// Whether [txn] matches [query]: an amount matches entries of those rupees
/// ("250" finds ₹250 and ₹250.50, not ₹1,250); words match the place or
/// what it was for, like "swiggy", "food" or "paid back".
bool matchesSearch(Txn txn, String query) {
  final words = query.trim().toLowerCase();
  if (words.isEmpty) return true;
  final bare = words.replaceAll(_amountMarks, '');
  if (_amount.hasMatch(bare)) {
    final wanted = paiseToAmountText(amountTextToPaise(bare));
    final amount = paiseToAmountText(txn.amountPaise);
    return amount == wanted ||
        (!bare.contains('.') && amount.startsWith('$wanted.'));
  }
  final place = txn.merchant?.toLowerCase() ?? '';
  final what = kindLabel(txn.type, txn.categoryId).toLowerCase();
  return place.contains(words) || what.contains(words);
}

/// What [txns] add up to, by kind: "8 entries · spent ₹3,240".
String totalLine(Iterable<Txn> txns) {
  var count = 0;
  final sums = {for (final kind in MoneyKind.values) kind: 0};
  for (final txn in txns) {
    count++;
    sums[txn.kind] = sums[txn.kind]! + txn.amountPaise;
  }
  String part(MoneyKind kind, String Function(String) words) =>
      sums[kind]! > 0 ? words(formatPaise(sums[kind]!)) : '';
  return [
    count == 1 ? '1 entry' : '$count entries',
    part(MoneyKind.spent, (paise) => 'spent $paise'),
    part(MoneyKind.got, (paise) => 'got $paise'),
    part(MoneyKind.paidBack, (paise) => '$paise came back'),
    part(MoneyKind.invested, (paise) => '$paise invested'),
  ].where((part) => part.isNotEmpty).join(' · ');
}

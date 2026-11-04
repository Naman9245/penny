import 'package:penny/core/utils/money.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/merchant_categories.dart';

// Two ways to log faster, worked out on the phone: an entry typed in one go
// ("240 swiggy"), and the entries someone logs again and again.

/// An entry typed in one go: its amount, the words around it as the place,
/// and the category those words suggest, if any.
typedef TypedEntry = ({int amountPaise, String? place, String? categoryId});

/// A currency mark before or after an amount, alone or stuck to it.
final _currency = RegExp(
  r'^(?:₹|rs\.?|inr)|(?:₹|/-|rs\.?)$',
  caseSensitive: false,
);

/// An amount as typed: "240", "1,200", "1,00,000", "99.50".
final _number = RegExp(r'^\d[\d,]*(?:\.\d{1,2})?$');

/// Reads [text] like "240 swiggy", "auto 45" or "₹1,200 rent". Null when it
/// has no amount, or more than one, so it's just a place.
TypedEntry? readTypedEntry(String text, {required TxnType type}) {
  int? paise;
  final words = <String>[];
  for (final word in text.trim().split(RegExp(r'\s+'))) {
    if (word.isEmpty) continue;
    final bare = word.replaceAll(_currency, '');
    if (bare.isEmpty) continue;
    if (_number.hasMatch(bare)) {
      if (paise != null) return null;
      paise = _paise(bare);
      if (paise == null) return null;
      continue;
    }
    words.add(word);
  }
  if (paise == null || paise <= 0) return null;
  final place = words.isEmpty ? null : words.join(' ');
  return (
    amountPaise: paise,
    place: place,
    categoryId: place == null ? null : _guessCategory(place, type),
  );
}

/// Everyday words people type that aren't shop names. Only typed entries
/// use them: in a bank SMS, "auto" is more often an auto-debit.
const _everydayWords = {
  TxnType.debit: {
    'food': [
      'chai',
      'tea',
      'breakfast',
      'lunch',
      'dinner',
      'snacks',
      'samosa',
      'dosa',
      'thali',
      'maggi',
      'juice',
      'mess',
    ],
    'groceries': ['milk', 'sabzi', 'vegetables', 'veggies', 'fruits', 'eggs'],
    'travel': ['auto', 'rickshaw', 'taxi', 'train', 'flight', 'parking'],
    'rent': ['pg'],
    'fun': ['movie', 'movies', 'party'],
    'health': ['medicine', 'medicines', 'doctor'],
    'education': ['books', 'fees', 'stationery', 'xerox'],
    'bills': ['wifi', 'internet'],
    'shopping': ['clothes', 'shoes'],
  },
  TxnType.credit: {
    'pocket_money': ['pocket money', 'allowance'],
    'freelance': ['freelance', 'gig'],
  },
};

final _everydayPatterns = {
  for (final MapEntry(key: type, value: lists) in _everydayWords.entries)
    type: {
      for (final MapEntry(key: category, value: words) in lists.entries)
        category: RegExp(
          r'\b(?:' + words.map(RegExp.escape).join('|') + r')\b',
          caseSensitive: false,
        ),
    },
};

/// The shops Penny knows first, then everyday words.
String? _guessCategory(String place, TxnType type) {
  final shop = suggestCategory(type: type, text: place, payee: place);
  if (shop != null) return shop;
  for (final MapEntry(key: category, value: pattern)
      in _everydayPatterns[type]!.entries) {
    if (pattern.hasMatch(place)) return category;
  }
  return null;
}

/// "1,200" → 120000, or null past what the keypad takes.
int? _paise(String typed) {
  final plain = typed.replaceAll(',', '');
  final whole = plain.split('.').first;
  if (whole.length > kMaxRupeeDigits) return null;
  return amountTextToPaise(plain);
}

/// One of the entries someone logs again and again: the same category,
/// place and amount.
typedef UsualEntry = ({String categoryId, String? place, int amountPaise});

/// Up to [max] usual entries of [type] among [txns]: seen at least twice,
/// the most often first and, among equals, the latest. A place's spelling
/// is its latest.
List<UsualEntry> usualEntries(Iterable<Txn> txns, TxnType type, {int max = 4}) {
  final seen = <(String, String, int), ({UsualEntry entry, int count})>{};
  final latest = <(String, String, int), DateTime>{};
  for (final txn in txns) {
    if (txn.type != type) continue;
    final place = txn.merchant?.trim();
    final key = (txn.categoryId, place?.toLowerCase() ?? '', txn.amountPaise);
    final before = seen[key];
    final last = latest[key];
    final newer = last == null || txn.occurredAt.isAfter(last);
    seen[key] = (
      entry: newer || before == null
          ? (
              categoryId: txn.categoryId,
              place: place == null || place.isEmpty ? null : place,
              amountPaise: txn.amountPaise,
            )
          : before.entry,
      count: (before?.count ?? 0) + 1,
    );
    if (newer) latest[key] = txn.occurredAt;
  }
  final usual =
      [
        for (final MapEntry(:key, :value) in seen.entries)
          if (value.count >= 2)
            (key: key, count: value.count, entry: value.entry),
      ]..sort((a, b) {
        final often = b.count.compareTo(a.count);
        return often != 0 ? often : latest[b.key]!.compareTo(latest[a.key]!);
      });
  return [for (final group in usual.take(max)) group.entry];
}

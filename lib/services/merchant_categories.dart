import 'package:penny/models/txn_enums.dart';

// Guesses a category from who was paid. Only a suggestion: the user sees it
// pre-picked and can tap another before saving.

// Checked in this order, so "Amazon Prime" lands in subscriptions before
// "amazon" can claim it for shopping, and a SIP is investing whatever else
// it mentions.
const _spendKeywords = <String, List<String>>{
  'invest': [
    'zerodha',
    'groww',
    'indmoney',
    'kuvera',
    'upstox',
    'coin',
    'sip',
    'mutual fund',
    'mutual funds',
  ],
  'subscriptions': [
    'netflix',
    'spotify',
    'prime',
    'hotstar',
    'youtube',
    'apple',
    'google play',
    'sonyliv',
    'zee5',
    'jiocinema',
    'audible',
    'chatgpt',
    'openai',
    'claude',
    'anthropic',
    'perplexity',
    'github',
    'notion',
    'grammarly',
    'duolingo',
    'linkedin',
    'icloud',
    'canva',
  ],
  'food': [
    'swiggy',
    'zomato',
    'dominos',
    "domino's",
    'pizza',
    'mcdonalds',
    "mcdonald's",
    'kfc',
    'burger',
    'starbucks',
    'chaayos',
    'cafe',
    'coffee',
    'coffeeday',
    'restaurant',
    'eatsure',
    'faasos',
    'haldiram',
    'biryani',
    'bakery',
    'canteen',
  ],
  'groceries': [
    'blinkit',
    'zepto',
    'instamart',
    'bigbasket',
    'dmart',
    'jiomart',
    'grocery',
    'supermarket',
    'kirana',
    'reliance fresh',
  ],
  'travel': [
    'uber',
    'ola',
    'rapido',
    'irctc',
    'redbus',
    'metro',
    'bmtc',
    'bus',
    'indigo',
    'air india',
    'makemytrip',
    'goibibo',
    'fastag',
    'petrol',
    'fuel',
    'hpcl',
    'iocl',
    'indian oil',
    'bharat petroleum',
    'yulu',
    'namma yatri',
    'cab',
  ],
  'shopping': [
    'amazon',
    'flipkart',
    'myntra',
    'ajio',
    'meesho',
    'nykaa',
    'decathlon',
    'croma',
    'lenskart',
    'adidas',
    'nike',
    'puma',
    'zara',
  ],
  'bills': [
    'airtel',
    'jio',
    'vodafone',
    'bsnl',
    'bescom',
    'electricity',
    'water bill',
    'gas',
    'broadband',
    'fibernet',
    'tata play',
    'recharge',
    'billpay',
  ],
  'fun': [
    'bookmyshow',
    'pvr',
    'inox',
    'cinepolis',
    'steam',
    'playstation',
    'xbox',
  ],
  'health': [
    'apollo',
    'pharmeasy',
    '1mg',
    'netmeds',
    'practo',
    'medplus',
    'hospital',
    'clinic',
    'pharmacy',
    'chemist',
    'cultfit',
    'gym',
  ],
  'education': [
    'udemy',
    'coursera',
    'unacademy',
    'byjus',
    'college',
    'school',
    'university',
    'vedantu',
    'physics wallah',
  ],
  'rent': ['rent', 'landlord', 'nobroker', 'nestaway', 'hostel', 'stanza'],
};

/// Every shop and brand above, for telling a shop from a person.
final knownShopNames = [for (final words in _spendKeywords.values) ...words];

final _spendPatterns = {
  for (final MapEntry(key: category, value: words) in _spendKeywords.entries)
    category: RegExp(
      r'\b(?:' + words.map(RegExp.escape).join('|') + r')\b',
      caseSensitive: false,
    ),
};

final _salary = RegExp(
  r'\b(?:salary|sal|payroll|stipend|wages)\b',
  caseSensitive: false,
);
final _company = RegExp(
  r'\b(?:pvt|private|ltd|limited|llp|technologies|solutions|labs)\b',
  caseSensitive: false,
);
final _bankTransfer = RegExp(r'\b(?:neft|imps|rtgs)\b', caseSensitive: false);
final _refund = RegExp(
  r'\b(?:refund|refunded|reversal|reversed|cashback)\b',
  caseSensitive: false,
);

/// The id of the category [payee] (or failing that, the whole [text])
/// most likely belongs to, or null when nothing fits well enough.
String? suggestCategory({
  required TxnType type,
  required String text,
  String? payee,
}) {
  switch (type) {
    case TxnType.debit:
      for (final haystack in [?payee, text]) {
        for (final MapEntry(key: category, value: pattern)
            in _spendPatterns.entries) {
          if (pattern.hasMatch(haystack)) return category;
        }
      }
      return null;
    case TxnType.credit:
      if (_refund.hasMatch(text)) return 'refund';
      if (_salary.hasMatch(text)) return 'salary';
      if (_bankTransfer.hasMatch(text) && _company.hasMatch(payee ?? text)) {
        return 'salary';
      }
      return null;
  }
}

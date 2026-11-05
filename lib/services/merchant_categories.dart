import 'package:penny/models/txn_enums.dart';

// Guesses a category from who was paid. Only a suggestion: the user sees it
// pre-picked and can tap another before saving.

// Checked in this order, so "Amazon Prime" lands in subscriptions before
// "amazon" can claim it for shopping, a SIP is investing whatever else it
// mentions, "Coin by Zerodha" is a mutual fund before Zerodha is stocks,
// and cooking gas is the home's before gas is a bill.
const _spendKeywords = <String, List<String>>{
  'deposits': [
    'fixed deposit',
    'fd',
    'recurring deposit',
    'rd',
    'ppf',
    'public provident fund',
    'nps',
    'national pension',
    'sukanya',
    'nsc',
    'post office',
  ],
  'invest': [
    'sip',
    'mutual fund',
    'mutual funds',
    'mf',
    'bse limited',
    'bse star mf',
    'iccl',
    'indian clearing corporation',
    'mf utilities',
    'cams',
    'kfintech',
    'coin',
    'kuvera',
    'groww',
    'nextbillion',
    'indmoney',
    'paytm money',
    'et money',
    'ppfas',
    'parag parikh',
    'nippon india',
    'mirae',
    'quant mf',
    'sbi mf',
    'hdfc mf',
    'icici pru',
    'axis mf',
    'kotak mf',
    'uti mf',
  ],
  'stocks': [
    'zerodha',
    'kite',
    'upstox',
    'angel one',
    'angel broking',
    'dhan',
    '5paisa',
    'icici direct',
    'hdfc securities',
    'kotak securities',
    'motilal oswal',
    'shares',
    'stocks',
    'equity',
    'demat',
    'trading account',
    'nse clearing',
    'ipo',
    'etf',
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
  'fuel': [
    'petrol',
    'diesel',
    'fuel',
    'cng',
    'hpcl',
    'hp petrol',
    'iocl',
    'indian oil',
    'bharat petroleum',
    'bpcl',
    'shell',
    'nayara',
    'jio-bp',
    'jio bp',
    'filling station',
    'petroleum',
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
  'emi': [
    'emi',
    'loan',
    'bajaj finserv',
    'bajaj finance',
    'home credit',
    'kreditbee',
    'moneyview',
    'navi',
    'lazypay',
    'simpl',
    'tata capital',
    'hdb financial',
    'muthoot',
  ],
  'home': [
    'maintenance',
    'society',
    'furniture',
    'pepperfry',
    'ikea',
    'urban ladder',
    'wakefit',
    'home centre',
    'indane',
    'hp gas',
    'bharat gas',
    'lpg',
    'cylinder',
    'plumber',
    'electrician',
    'carpenter',
    'house help',
    'maid',
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
  'care': [
    'salon',
    'spa',
    'barber',
    'parlour',
    'parlor',
    'gym',
    'cultfit',
    'cult.fit',
    'cult fit',
    'fitness',
    'naturals',
    'jawed habib',
    'lakme salon',
    'green trends',
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
  'gifts': [
    'gift',
    'gifts',
    'donation',
    'donate',
    'charity',
    'temple',
    'mandir',
    'gurudwara',
    'church',
    'ngo',
    'giveindia',
    'ketto',
    'milaap',
  ],
  'rent': ['rent', 'landlord', 'nobroker', 'nestaway', 'hostel', 'stanza'],
  // Many SMS mention a fee or charges in passing: only when nothing
  // else fits.
  'charges': [
    'charges',
    'charge',
    'fee',
    'fees',
    'penalty',
    'late payment',
    'annual fee',
    'gst',
    'interest charged',
    'finance charges',
  ],
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
final _dividend = RegExp(r'\bdividends?\b', caseSensitive: false);
final _interest = RegExp(
  r'\b(?:interest|int\.?\s*pd|int\.?\s*cr)\b',
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
      if (_dividend.hasMatch(text)) return 'dividends';
      if (_interest.hasMatch(text)) return 'interest';
      if (_salary.hasMatch(text)) return 'salary';
      if (_bankTransfer.hasMatch(text) && _company.hasMatch(payee ?? text)) {
        return 'salary';
      }
      return null;
  }
}

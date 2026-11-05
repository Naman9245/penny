import 'package:penny/services/merchant_categories.dart';

// Getting a notification ready for Penny's AI, when her own rules couldn't
// read it. Only money words, numbers and the names of shops and money
// brands go; every other word, which could be a person's or a place's
// name, is swapped for a tag like [w3] and stays on the phone.

/// The most of a notification that's sent.
const maxAiText = 600;

/// Words that say how money moved, and the plain words around them.
const _plainWords = {
  // Little words.
  'a', 'an', 'the', 'to', 'from', 'by', 'via', 'on', 'at', 'in', 'of',
  'for', 'with', 'and', 'or', 'is', 'are', 'was', 'were', 'has', 'have',
  'had', 'been', 'be', 'will', 'your', 'you', 'yours', 'ur', 'u', 'our',
  'we', 'us', 'it', 'its', 'this', 'that', 'not', 'no', 'if', 'as', 'any',
  'all', 'now', 'today', 'yesterday', 'please', 'pls', 'dear', 'customer',
  'sir', 'madam', 'thank', 'thanks', 'call', 'sms', 'report', 'block',
  'help', 'info', 'details', 'more', 'here', 'click', 'link', 'visit',
  'app', 'new', 'updated', 'update', 'current', 'after', 'before', 'left',
  'than', 'into', 'towards', 'toward', 'against', 'only', 'just', 'also',
  'same', 'per', 'day', 'days', 'working', 'within', 'next', 'last',
  // Money.
  'rs', 'inr', 'rupees', 'rupee', 'amount', 'amt', 'debit', 'debited',
  'credit', 'credited', 'paid', 'pay', 'payment', 'payments', 'sent',
  'send', 'received', 'receive', 'deducted', 'deduct', 'added', 'add',
  'spent', 'spend', 'withdrawn', 'withdrawal', 'transfer', 'transferred',
  'txn', 'transaction', 'trxn', 'ref', 'refno', 'reference', 'utr', 'upi',
  'imps', 'neft', 'rtgs', 'nach', 'ecs', 'mandate', 'autopay', 'auto',
  'emi', 'loan', 'sip', 'mutual', 'fund', 'funds', 'units', 'unit', 'nav',
  'folio', 'invested', 'investment', 'invest', 'allotted', 'allotment',
  'redemption', 'redeemed', 'dividend', 'interest', 'fd', 'rd', 'ppf',
  'nps', 'deposit', 'deposits', 'deposited', 'fixed', 'recurring',
  'booked', 'account', 'acct', 'ac', 'c', 'card', 'cards', 'wallet',
  'lite', 'balance', 'bal', 'avl', 'avail', 'available', 'limit', 'total',
  'due', 'bill', 'bills', 'charge', 'charges', 'charged', 'levied', 'fee',
  'fees', 'gst', 'tax', 'refund', 'refunded', 'reversal', 'reversed',
  'cashback', 'reward', 'rewards', 'points', 'successful', 'successfully',
  'success', 'failed', 'failure', 'declined', 'pending', 'processed',
  'executed', 'completed', 'done', 'order', 'purchase', 'purchased',
  'merchant', 'shop', 'store', 'online', 'pos', 'atm', 'cash', 'cheque',
  'chq', 'statement', 'otp', 'code', 'offer', 'request', 'requested',
  'collect', 'money', 'recharge', 'mobile', 'prepaid', 'postpaid',
  'electricity', 'gas', 'water', 'broadband', 'insurance', 'premium',
  'policy', 'trading', 'demat', 'broker', 'broking', 'shares', 'share',
  'stock', 'stocks', 'equity', 'market', 'bank', 'banking', 'netbanking',
  'net', 'self', 'own', 'top', 'topup', 'topped', 'load', 'loaded',
  'savings', 'saving', 'salary', 'stipend', 'ending', 'number', 'xx', 'id',
  'date', 'dt', 'time', 'ist', 'am', 'pm', 'hrs', 'dr', 'cr', 'contribution',
  'pran', 'margin', 'debitcard', 'creditcard', 'direct', 'growth', 'plan',
  'regular', 'investor', 'user', 'holder',
  // When.
  'jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'sept',
  'oct', 'nov', 'dec', 'january', 'february', 'march', 'april', 'june',
  'july', 'august', 'september', 'october', 'november', 'december', 'mon',
  'tue', 'wed', 'thu', 'fri', 'sat', 'sun', 'st', 'nd', 'th',
  // Money brands.
  'hdfc', 'icici', 'sbi', 'axis', 'kotak', 'yes', 'indusind', 'idfc',
  'first', 'idbi', 'pnb', 'bob', 'baroda', 'canara', 'union', 'federal',
  'rbl', 'au', 'equitas', 'bandhan', 'dbs', 'hsbc', 'citi', 'amex',
  'paytm', 'phonepe', 'gpay', 'google', 'amazon', 'payzapp', 'mobikwik',
  'freecharge', 'cred', 'bhim', 'super', 'airtel', 'jio', 'groww',
  'zerodha', 'kite', 'coin', 'upstox', 'kuvera', 'indmoney', 'lic',
  'onecard', 'slice', 'npci', 'bse', 'nse', 'cdsl', 'nsdl', 'cams',
  'kfintech', 'iccl', 'pixel', 'rupay', 'visa', 'mastercard',
};

/// Shops and brands Penny knows: their names aren't anyone's.
final _shopWords = {
  for (final name in knownShopNames)
    for (final word in name.toLowerCase().split(RegExp(r'[^a-z0-9]+')))
      if (word.isNotEmpty) word,
};

final _word = RegExp(r'\p{L}+', unicode: true);
final _longDigits = RegExp(r'\d{9,}');
// "XX4821", "*4821", "91XXXX8888": an account or card number.
final _maskedNumber = RegExp(r'[\dxX*]*[xX*][\dxX*]*\d[\dxX*]*|\d+[xX*]+');

/// [text] as Penny's AI may see it: every word that isn't a plain money
/// word, or a shop or brand Penny knows, swapped for a tag like [w1] (the
/// same word, the same tag), and account, card and long reference numbers
/// as •••. A UPI ID's name goes as tags too: "rahul.k@okaxis" is
/// "[w1].[w2]@[w3]". [tags] says what each tag stands for, to put back
/// what the AI answers. At most [maxAiText] characters.
({String text, Map<String, String> tags}) maskForAi(String text) {
  final tags = <String, String>{};
  final byWord = <String, String>{};
  final numbersHidden = text
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(_maskedNumber, '•••')
      .replaceAll(_longDigits, '•••');
  final masked = numbersHidden.replaceAllMapped(_word, (m) {
    final word = m.group(0)!;
    final lower = word.toLowerCase();
    if (_plainWords.contains(lower) || _shopWords.contains(lower)) return word;
    return byWord.putIfAbsent(lower, () {
      final tag = '[w${byWord.length + 1}]';
      tags[tag] = word;
      return tag;
    });
  });
  return (
    text: masked.length > maxAiText ? masked.substring(0, maxAiText) : masked,
    tags: tags,
  );
}

/// [payee], the AI's words with tags in them, with each tag put back as the
/// word it stands for. Null when it has a tag Penny never made.
String? unmask(String? payee, Map<String, String> tags) {
  if (payee == null || payee.trim().isEmpty) return null;
  var unknown = false;
  final words = payee.replaceAllMapped(RegExp(r'\[w\d+\]'), (m) {
    final word = tags[m.group(0)!];
    if (word == null) unknown = true;
    return word ?? '';
  });
  return unknown ? null : words.trim();
}

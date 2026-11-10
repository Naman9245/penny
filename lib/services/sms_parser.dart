import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/merchant_categories.dart';

// Reads one bank or UPI SMS, on the phone. Nothing here keeps or sends the
// text: callers get the numbers Penny needs, a masked preview to show, and a
// fingerprint that stops the same message being added twice.

/// Why a message wasn't taken as a payment, in words for the user.
enum IgnoreReason {
  otp("It's a one-time password. Penny never keeps those."),
  request("It's a request for money, not a payment."),
  upcoming("It's about a payment that hasn't happened yet."),
  failed('The payment failed, so no money moved.'),
  offer('It looks like an offer, not a payment.'),
  ownTransfer(
    'It moves money between your own accounts, so Penny leaves it out.',
  ),
  cardBill(
    'It pays a credit card bill. Penny counted what you bought with the card '
    'when you paid by it.',
  ),
  receipt(
    "It confirms a payment you've already made, which your bank's message "
    'covers.',
  ),
  balance('It only tells you a balance.'),
  unreadable("Penny couldn't find an amount and a debit or credit in it.");

  const IgnoreReason(this.explanation);

  final String explanation;
}

/// What a stretch of the preview is.
enum SpanKind { amount, payee, date, hidden }

class SmsSpan {
  const SmsSpan(this.start, this.end, this.kind);

  final int start;
  final int end;
  final SpanKind kind;
}

/// The message as Penny shows it: account, card and reference numbers, UPI
/// IDs and balances blanked out with •, and the parts it read marked.
class SmsPreview {
  const SmsPreview(this.text, this.spans);

  final String text;
  final List<SmsSpan> spans;
}

sealed class SmsParse {
  const SmsParse();
}

class SmsTxn extends SmsParse {
  const SmsTxn({
    required this.amountPaise,
    required this.type,
    required this.payee,
    required this.payeeIsPerson,
    required this.occurredAt,
    required this.hasTime,
    required this.suggestedCategoryId,
    required this.dedupeKey,
    required this.preview,
  });

  final int amountPaise;
  final TxnType type;
  final String? payee;

  /// The payee looks like a person rather than a business. People's names
  /// never go to the AI: it sees them as "Person 1, 2".
  final bool payeeIsPerson;

  /// When the message says it happened. Null when it doesn't say, or says
  /// something implausible.
  final DateTime? occurredAt;

  /// Whether [occurredAt] carries a time of day.
  final bool hasTime;
  final String? suggestedCategoryId;

  /// Fingerprint of the message. Local only: never synced.
  final String dedupeKey;
  final SmsPreview preview;

  /// The same payment, fingerprinted as [key].
  SmsTxn withDedupeKey(String key) => SmsTxn(
    amountPaise: amountPaise,
    type: type,
    payee: payee,
    payeeIsPerson: payeeIsPerson,
    occurredAt: occurredAt,
    hasTime: hasTime,
    suggestedCategoryId: suggestedCategoryId,
    dedupeKey: key,
    preview: preview,
  );

  /// The same money, coming back for the payment to [payee] in
  /// [categoryId]: it goes in that category, as money back.
  SmsTxn backFor({
    required String? payee,
    required String categoryId,
    required bool payeeIsPerson,
  }) => SmsTxn(
    amountPaise: amountPaise,
    type: type,
    payee: payee,
    payeeIsPerson: payeeIsPerson,
    occurredAt: occurredAt,
    hasTime: hasTime,
    suggestedCategoryId: categoryId,
    dedupeKey: dedupeKey,
    preview: preview,
  );
}

class SmsIgnored extends SmsParse {
  const SmsIgnored(this.reason);

  final IgnoreReason reason;
}

RegExp _rx(String pattern) => RegExp(pattern, caseSensitive: false);

// Gates, checked before anything is read. Disclaimers such as "never share
// your OTP" are stripped first, so a real alert that carries one still counts.
final _disclaimer = _rx(
  r"(?:never|do not|don't|dont|please do not|pls do not|not to)\s+(?:share|disclose)[^.\n]*",
);
final _otpWord = _rx(
  r'\b(?:otp|one[\s-]?time[\s-]?password|verification code|security code|passcode|cvv)\b',
);
final _request = _rx(
  r'\b(?:has requested|have requested|is requesting|collect request|payment request|requested (?:money|payment|rs|inr|₹))',
);
final _upcoming = _rx(
  r'\b(?:will be (?:auto[\s-]?)?(?:debited|deducted|charged|processed)|to be debited|is due|are due|due on|due by|due date|payment due|scheduled (?:for|on)|pre-?debit|reminder)\b'
  r'|\bmandate\b[^\n]{0,80}\b(?:created|registered|set ?up|activated)\b',
);
// Paying your own credit card bill: the debit shows up on the bank account.
final _ownCardPayment = _rx(
  r'\breceived\b[^\n]{0,40}\btowards your\b[^\n]{0,40}\bcredit card\b',
);
final _failed = _rx(
  r'\b(?:failed|declined|unsuccessful|could not be processed|was not processed|insufficient (?:funds|balance))\b',
);
// What a bank says might happen, not what did: "In case of failed
// transaction, amount will be refunded", "If the txn failed, …".
final _ifFailed = _rx(
  r'\b(?:in\s+case\s+of\s+(?:a\s+|any\s+)?|if\s+(?:the\s+|your\s+|this\s+)?(?:transaction|txn|payment)\s+(?:is\s+|has\s+|was\s+)?)(?:failed|unsuccessful|declined)\b[^.\n]*',
);
// The next one coming, under a payment that's been made: "Next payment due
// on 10-12-26".
final _nextDue = _rx(
  r'\bnext\s+(?:payment|debit|due|emi|instal(?:l)?ment|bill|renewal|auto[\s-]?pay)\b[^.\n]*',
);
// Money that has already moved.
final _moved = _rx(
  r'\b(?:debited|deducted|spent|paid|sent|withdrawn|transferred)\b',
);
// Paying a credit card's bill from the bank account: what the card bought
// was counted when it was bought.
final _cardBill = _rx(
  r'\bcredit\s*card\b[^\n]{0,60}\b(?:bill|dues?|outstanding|payment)\b'
  r'|\b(?:bill\s+)?payment\b[^\n]{0,60}\b(?:for|towards|to)\s+(?:your\s+)?[^\n]{0,30}\bcredit\s*card\b'
  r'|\bbilldesk\b[^\n]{0,40}\bcredit\s*card\b'
  r'|\bto\s+(?:vpa\s+)?cred(?:\s*club|\.club)?\b(?![.\w]*@)'
  r'|\bcred\.club@',
);
// A lender's receipt for an EMI, or an insurer's for a premium: the bank's
// own message already has the money leaving.
final _receipt = _rx(
  r'\b(?:emi|loan|repayment|instal(?:l)?ments?|premium)\b[^\n]{0,80}\b(?:received|realised|realized)\b',
);
final _receiptFor = _rx(r'\b(?:towards|for|against)\s+(?:your|the)\b');
// A shop's thanks for a payment the bank's own message has.
final _shopReceipt = _rx(
  r'\b(?:received|realised|realized)\s+your\s+payment\b'
  r'|\byour\s+payment\b[^\n]{0,40}\b(?:has\s+been|was|is)\s+received\b'
  r'|\bthank(?:s|\s+you)\s+for\s+(?:your|the)\s+payment\b',
);
final _receiptTowards = _rx(
  r'\b(?:received|realised|realized)\b[^\n]{0,40}\btowards\b[^\n]{0,20}\b(?:emi|loan|repayment|instal(?:l)?ments?|premium|policy)\b',
);
// Money moved to the user's own account.
final _ownAccount = _rx(
  r'\bto\s+(?:your\s+)?own\b|\bself[\s-]?transfer\b|\bto\s+self\b|\bown\s+a/?c\b',
);
// A refund that reached the user, as against one promised.
final _refundedTo = _rx(r'\brefunded\s+(?:to|into)\b');
// Money moved into a wallet or UPI Lite from the user's own bank account.
// Only paying from it is spending.
final _walletLoad = _rx(
  r'\b(?:add(?:ed)?\s+money|money\s+added|loaded|load|top[\s-]?up|topped\s+up|added|recharged)\b[^\n]{0,60}\b(?:wallet|upi\s*lite|pay\s+balance)\b'
  r'|\b(?:wallet|upi\s*lite)\b[^\n]{0,30}\b(?:load|loaded|top[\s-]?up|topped\s+up)\b',
);
// Paid out of a wallet: "Recharged … using Paytm Wallet". Spending, not
// loading it.
final _paidFromWallet = _rx(
  r'\b(?:using|via|from|through)\s+(?:your\s+)?(?:(?!to\b)[a-z]+\s+){0,2}(?:wallet|pay\s+balance)\b',
);
final _notALoad = _rx(
  r'\b(?:cashback|refund(?:ed)?|reward|rewards|reversal|reversed)\b',
);
// Money put into investing, even when the message never says "invested":
// a SIP processed, units allotted, a contribution or units credited to an
// investment, funds added to a broker, a deposit booked.
final _investOut = _rx(
  r'\b(?:invested|allotted|allotment)\b'
  r'|\bsip\b[^\n]{0,80}\b(?:processed|successful|successfully|executed|debited|paid|received)\b'
  r'|\b(?:contribution|units?)\b[^\n]{0,60}\bcredited\b'
  r'|\bfunds?\b[^\n]{0,30}\badded\b'
  r'|\badded\b[^\n]{0,40}\b(?:trading|demat|broking)\s+(?:a/?c|account)\b'
  r'|\b(?:fixed deposit|recurring deposit|fd|rd)\b[^\n]{0,60}\b(?:booked|opened|created)\b',
);
final _autopay = _rx(
  r'\bauto[\s-]?pay\b[^\n]{0,60}\b(?:successful|successfully|executed|processed)\b',
);
// "Rs.350.00 Dr", "is Dr with Rs.350", "Rs.2,000.00 Cr to A/c".
final _drWord = _rx(
  r'(?<=\d\s{0,2})dr\b|\bdr\.?(?=\s*(?:rs\b|inr\b|₹|for\b|with\b|by\b))',
);
final _crWord = _rx(
  r'(?<=\d\s{0,2})cr\b|\bcr\.?(?=\s*(?:rs\b|inr\b|₹|to\b|for\b|with\b|by\b))',
);
final _refundWord = _rx(r'\b(?:refund|refunded|reversal|reversed)\b');
final _credited = _rx(r'\bcredited\b');
final _offer = _rx(
  r"\b(?:pre-?approved|apply now|loan (?:of )?(?:up ?to|upto)|cashback (?:of )?up ?to|offer|congratulations|t&c|limited period|get flat|use code|scratch ?card|you(?:'ve| have)? won|win up ?to)\b",
);
final _balanceWord = _rx(r'\b(?:bal|balance|avl|available)\b');

// "A/c XX4821", "Card 7712", "AC X8899", "account XXX234", "card ending 4455",
// "a/c 91XXXX8888".
final _accountRef = _rx(
  r'\b(?:a/?c|acct|account|card)(?:\s*no\.?)?(?:\s*ending(?:\s*with)?)?[\s:.]*([xX*•.]*\d[\dxX*•]*\d)',
);
final _vpa = _rx(r'\b([\w.\-]{2,})@([a-z][a-z.]*)\b');
final _maskedVpa = _rx(r'\bvpa\s+[*xX•]+[\w.\-]*@[a-z]');
// The account or card tail in a bank's "SMS BLOCK DC 7712 to …" footer.
final _blockRef = _rx(r'\bblock\s*(?:dc|cc|upi)?\s+(\d{3,6})\b');
final _longDigits = RegExp(r'\d{6,}');

final _strongDebit = _rx(
  r'\b(?:debited|spent|sent|paid|withdrawn|deducted|purchased?|levied|charged|transferred\s+to(?!\s+your)|transferred\s+from)\b',
);
final _strongCredit = _rx(
  r'\b(?:credited|received|deposited|refund(?:ed)?|reversal|reversed|credit\s+of|paid\s+you|sent\s+you|dividends?|cashback\s+(?:of\s+)?(?:rs\.?|inr|₹)?\s*[\d,.]*\s*(?:added|credited))\b',
);
final _weakDebit = _rx(r'\b(?:txn|transaction|payment)\b');

final _currencyAmount = _rx(
  r'(?:₹|\brs\.?|\binr)\s*:?\s*([\d,]+(?:\.\d{1,2})?)',
);
final _bareAmount = _rx(
  r'\b(?:debited|credited)\s+(?:by|for|with)\s+([\d,]+(?:\.\d{1,2})?)\b',
);
final _amountIsBalance = _rx(
  r'(?:bal(?:ance)?|limit|avl(?:bl)?|avail(?:able)?|outstanding|due|min(?:imum)?)\.?[\s:.\-]*(?:amt|amount|bal(?:ance)?)?[\s:.\-]*(?:is\s*)?(?:of\s*)?$',
);
final _balanceAfter = _rx(
  r'^\s*(?:is\s+(?:your\s+)?)?(?:the\s+)?(?:avl\.?\s*|available\s+)?bal(?:ance)?\b',
);

// Payee patterns. A name runs until a word or mark that ends it.
const _honorific = r'(?:(?:mr|mrs|ms|miss|shri|smt|dr)\.?\s+)?';
const _name = r"([a-z][a-z0-9&'* ]{0,40}?)";
const _end =
    r'(?=\s*(?:$|[\n.;,(:/])|\s+(?:on|ref|refno|upi|via|from|avl|info|not|if|call|dt|dated|thru|towards|for|has|have|is|was|by|with|using|at|in|to|bal|incl|including|successful|successfully|done|completed|booking|executed|processed|a/?c|acct|account|debited|credited|deducted|auto[\s-]?pay|mandate|subscription)\b|\s+-)';
final _upiPath = _rx(r'\bupi/(?:p2[am]/)?\d+/([a-z][^/\n.]{1,40})');
final _debitPayees = [
  _rx(r'\b(?:invested|allotted|sip)\b[^\n]{0,40}?\bin\s+' + _name + _end),
  _rx(
    r'\bto\s+(?:vpa\s+)?'
    r'([\w.\-]{2,}@[a-z][a-z.]*)\b',
  ),
  _upiPath,
  _rx(r';\s*' + _name + r'\s+credited'),
  _rx(r'\btrf to\s+' + _honorific + _name + _end),
  _rx(r'\btransferred to\s+' + _honorific + _name + _end),
  _rx(r'\btowards\s+' + _name + _end),
  _rx(r'\bto[\s:]+' + _honorific + _name + _end),
  _rx(r'\bat\s+' + _name + _end),
  RegExp(r"\bon\s+([A-Z][A-Z0-9&' ]{1,40}?)\.(?:\s|$)"),
  _rx(r'\bfor\s+' + _name + _end),
];
final _creditPayees = [
  _rx(
    r'\b(?:from|by|linked to)\s+(?:vpa\s+)?'
    r'([\w.\-]{2,}@[a-z][a-z.]*)\b',
  ),
  _upiPath,
  _rx(r'\bneft\s*cr-[a-z0-9]+-([a-z][a-z0-9 .&]{1,60}?)-'),
  _rx(r'\bfrom\s+' + _honorific + _name + _end),
  _rx(r'\bby\s+' + _name + _end),
  // "Rahul Kumar paid you ₹500", as payment apps say it.
  _rx(
    r'(?:^|[.:]\s+)' +
        _honorific +
        _name +
        r'[.:]?\s+(?:has\s+)?(?:paid|sent)\s+you\b',
  ),
];
final _notAPayee = _rx(
  r'^(?:(?:rs|inr)\.?\s*\d|(?:rs|inr|upi|txn|your|you|ur|a/?c|ac|acct|account|card|bank|the|ref|vpa|imps|neft|nach|ecs|pran|folio|date|dt)\b)',
);
final _atmWithdrawal = _rx(
  r'\b(?:withdrawn|withdrawal)\b[^\n]*\batm\b|\batm\b[^\n]*\bwithdrawn\b',
);
final _business = _rx(
  r'\b(?:pvt|private|ltd|limited|llp|india|store|stores|services|technologies|solutions|pay|bank|mart|enterprises|restaurant|cafe|hotel'
  // What a shop sells, or is: "Sharma Sweets", "Apollo Pharmacy".
  r'|sweets?|medicals?|pharmacy|pharma|chemists?|bakery|bakers|kirana|traders|trading|foods?|dhaba|general|stall|cent(?:er|re)|agency|agencies'
  r'|motors|fuels?|petroleum|pizza|pizzeria|burgers?|coffee|chai|tea|juice|snacks|kitchen|biryani|bhojanalaya|canteen|mess|lodge|resort'
  r'|cabs?|travels?|tours|salon|parlou?r|studio|electronics|mobiles?|fashions?|garments|textiles|footwear|opticals?|optics|clinic|hospital'
  r'|diagnostics|labs?|school|academy|institute|college|classes|tuitions?|gym|fitness|fresh|bazaar|market|supermarket|hypermarket|industries'
  r'|company|corporation|associates|brothers|bros|sons|international|retail|wholesale|distributors|supplies|hardware|paints|furniture'
  r'|jewell?ers?|books|stationery|xerox|printers|garage|automobiles|dairy|vegetables|fruits|meat|chicken|bar|pub|lounge|bistro'
  // What a payment is for, after a shop's name: "NETFLIX autopay".
  r'|auto[\s-]?pay|mandate|subscriptions?|orders?|bill|recharge|payment|emi|nach|trip|rides?|bookings?|tickets?|money|wallet)\b',
);
const _acronyms = {
  'ATM',
  'UPI',
  'NEFT',
  'IMPS',
  'RTGS',
  'IRCTC',
  'LIC',
  'EMI',
  'HDFC',
  'ICICI',
  'SBI',
  'BSE',
  'NSE',
  'NSDL',
  'CDSL',
  'ICCL',
  'NACH',
  'SIP',
  'NPS',
  'PPF',
  'GST',
  'SMS',
  'UTI',
  'AMC',
  'ETF',
  'IPO',
  'IDFC',
  'IDBI',
  'PNB',
  'RBL',
  'DBS',
  'HSBC',
};
// Vowel-less, but words rather than abbreviations.
const _plainWords = {'PVT', 'LTD'};

final _isoDate = RegExp(
  r'\b(20\d{2})-(\d{1,2})-(\d{1,2})(?:[:\sT,]+(\d{1,2}):(\d{2})(?::(\d{2}))?)?',
);
final _namedDate = _rx(
  r'\b(\d{1,2})[-\s]?(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[-\s,]?(\d{2,4})\b'
  r'(?:[\s,]+(\d{1,2}):(\d{2})(?::(\d{2}))?)?',
);
final _numericDate = RegExp(
  r'\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})\b(?:[\s,]+(\d{1,2}):(\d{2})(?::(\d{2}))?)?',
);
const _months = [
  'jan',
  'feb',
  'mar',
  'apr',
  'may',
  'jun',
  'jul',
  'aug',
  'sep',
  'oct',
  'nov',
  'dec',
];

// A sender as a Messages app shows it: a bank's code, with its prefix
// ("JM-HDFCBK", "VM-GROWWZ-S") or without ("HDFCBK"), or a money brand by
// name ("HDFC Bank", "PayZapp").
final _senderCode = _rx(r'^[A-Z]{2}-[A-Z0-9]{3,9}(?:-[A-Z])?$');
final _bareSenderCode = RegExp(r'^[A-Z][A-Z0-9]{5}$');
final _moneyBrand = _rx(
  r'\b(?:bank|wallet|cards?|payments?|pay|upi|mf|amc|mutual\s*funds?|securities|broking|finserv|finance|capital'
  r'|sbi|hdfc|icici|axis|kotak|indusind|idfc|idbi|baroda|bob|pnb|canara|federal|rbl|equitas|ujjivan|bandhan|dbs|hsbc|citi|amex'
  r'|payzapp|paytm|phonepe|gpay|mobikwik|freecharge|cred|bhim|onecard|slice|groww|zerodha|upstox|kuvera|indmoney|cams|kfintech|nsdl|cdsl'
  r'|super\.money|angel\s*one|jio\s*money|airtel\s*money|et\s*money)\b',
);
// An account or card number shown masked, as only a bank's own message
// does: "A/c XX4821", "card *4455", "card ending 4455". Must match
// MASKED_ACCOUNT in MoneyFilter.kt.
final _maskedAccount = _rx(
  r'\b(?:a/?c|acct|account|card)(?:\s*no\.?)?[\s:.]*(?:[x*•.]+\d{2,}|ending(?:\s*with)?[\s:.]*[x*•]*\d{3,})',
);

/// Whether an SMS from [sender], as the Messages app names it, can be from a
/// bank, a wallet or an investment: a sender code, or a money brand's name.
/// A friend's name never is.
bool isMoneySender(String sender) {
  final name = sender.trim();
  return _senderCode.hasMatch(name) ||
      _bareSenderCode.hasMatch(name) ||
      _moneyBrand.hasMatch(name);
}

/// Whether [text] shows a masked account or card number, as only a bank's
/// own message does: "A/c XX4821", "card ending 4455". A friend's text that
/// just says "account" or "wallet" doesn't.
bool mentionsMaskedAccount(String text) =>
    _maskedAccount.hasMatch(_normalise(text));

/// Whether [text] names an account or card, as a bank's message does: "A/c
/// XX4821", "card ending 4455".
bool mentionsAccount(String text) => _accountRef.hasMatch(_normalise(text));

/// Reads [raw], one SMS, as a payment, or says why it isn't one. [now] is
/// for dates: one later than tomorrow or over a year old is not believed.
SmsParse parseSms(String raw, {DateTime? now}) {
  now ??= DateTime.now();
  final text = _normalise(raw);
  if (text.isEmpty) return const SmsIgnored(IgnoreReason.unreadable);

  // OTPs are refused before anything else is looked at.
  if (_otpWord.hasMatch(text.replaceAll(_disclaimer, ' '))) {
    return const SmsIgnored(IgnoreReason.otp);
  }
  if (_request.hasMatch(text)) return const SmsIgnored(IgnoreReason.request);
  // The next one due, under money that has already left, isn't this one.
  final withoutNext = text.replaceAll(_nextDue, ' ');
  final dueLater = _moved.hasMatch(withoutNext) ? withoutNext : text;
  if (_upcoming.hasMatch(dueLater)) {
    return const SmsIgnored(IgnoreReason.upcoming);
  }
  final refundCredited =
      _refundWord.hasMatch(text) &&
      (_credited.hasMatch(text) || _refundedTo.hasMatch(text));
  if (!refundCredited && _failed.hasMatch(text.replaceAll(_ifFailed, ' '))) {
    return const SmsIgnored(IgnoreReason.failed);
  }
  if (_ownCardPayment.hasMatch(text)) {
    return const SmsIgnored(IgnoreReason.ownTransfer);
  }
  if (_cardBill.hasMatch(text)) return const SmsIgnored(IgnoreReason.cardBill);
  if (_ownAccount.hasMatch(text)) {
    return const SmsIgnored(IgnoreReason.ownTransfer);
  }
  if ((_receipt.hasMatch(text) && _receiptFor.hasMatch(text)) ||
      _receiptTowards.hasMatch(text) ||
      _shopReceipt.hasMatch(text)) {
    return const SmsIgnored(IgnoreReason.receipt);
  }
  if (_walletLoad.hasMatch(text) &&
      !_notALoad.hasMatch(text) &&
      !_paidFromWallet.hasMatch(text)) {
    return const SmsIgnored(IgnoreReason.ownTransfer);
  }
  final accounts = _accountRef.allMatches(text).toList();
  if (accounts.isEmpty && _offer.hasMatch(text)) {
    return const SmsIgnored(IgnoreReason.offer);
  }

  final type = _direction(text);
  final amount = _amount(text);
  if (type == null || amount == null) {
    return SmsIgnored(
      _balanceWord.hasMatch(text)
          ? IgnoreReason.balance
          : IgnoreReason.unreadable,
    );
  }

  final payee = _payee(text, type);
  final date = _date(text, now);
  // A person's name can hold a brand's word, like "Zara Khan", and the
  // message other words, like the bank's own "Airtel Payments Bank": for a
  // person, neither picks a category. Investing is never paying a person.
  final fromText = suggestCategory(type: type, text: text, payee: payee?.name);
  final toPerson =
      type == TxnType.debit &&
      payee != null &&
      payee.isPerson &&
      _isPersonName(payee.name) &&
      // The rest of the message, the name aside, says it's investing.
      !isInvestCategory(
        suggestCategory(
          type: type,
          text: text.replaceRange(payee.start, payee.end, ' '),
        ),
      );
  final category = toPerson ? null : fromText;

  return SmsTxn(
    amountPaise: amount.paise,
    type: type,
    payee: payee?.name,
    // A UPI ID shown only in part ("from VPA *amit@okhdfcbank") is a person's.
    payeeIsPerson:
        category == null &&
        (payee != null ? payee.isPerson : _maskedVpa.hasMatch(text)),
    occurredAt: date?.at,
    hasTime: date?.hasTime ?? false,
    suggestedCategoryId: category,
    dedupeKey: _fingerprint(text),
    preview: _preview(text, accounts, amount, payee, date),
  );
}

/// [raw] as a payment read some other way, by Penny's AI: [type] and
/// [amountPaise], paid to [payee] (words of the message), in [categoryId].
/// Null when [amountPaise] isn't an amount the message gives, so a misread
/// amount is never kept. The rest is as [parseSms] would have it: the
/// date, the fingerprint and the masked preview.
SmsTxn? paymentFrom(
  String raw, {
  required TxnType type,
  required int amountPaise,
  String? payee,
  String? categoryId,
  DateTime? now,
}) {
  now ??= DateTime.now();
  final text = _normalise(raw);
  _Amount? amount;
  for (final match in [
    ..._currencyAmount.allMatches(text),
    ..._anyNumber.allMatches(text),
  ]) {
    if (_toPaise(match.group(1)!) != amountPaise) continue;
    amount = (paise: amountPaise, start: match.start, end: match.end);
    break;
  }
  if (amount == null) return null;

  _Payee? found;
  final name = payee?.trim() ?? '';
  final at = name.isEmpty ? -1 : text.toLowerCase().indexOf(name.toLowerCase());
  if (at >= 0) {
    final cleaned = _cleanName(text.substring(at, at + name.length));
    if (cleaned != null) {
      found = (
        name: cleaned,
        isPerson: _looksLikePerson(cleaned),
        start: at,
        end: at + name.length,
      );
    }
  }
  final accounts = _accountRef.allMatches(text).toList();
  final date = _date(text, now);
  return SmsTxn(
    amountPaise: amountPaise,
    type: type,
    payee: found?.name,
    // A name that reads like a person's is kept from the AI, whatever it's
    // for.
    payeeIsPerson: found != null ? found.isPerson : _maskedVpa.hasMatch(text),
    occurredAt: date?.at,
    hasTime: date?.hasTime ?? false,
    suggestedCategoryId: categoryId,
    dedupeKey: _fingerprint(text),
    preview: _preview(text, accounts, amount, found, date),
  );
}

// A plain number, as in "debited by 250.0".
final _anyNumber = RegExp(r'(?<![\d.,])([\d,]+(?:\.\d{1,2})?)(?![\d,]|\.\d)');

/// [raw] with account and card numbers, references and UPI IDs blanked, as
/// the SMS card shows a message, for one Penny couldn't read.
String maskedText(String raw) {
  final text = _normalise(raw);
  final chars = text.split('');
  final digit = RegExp(r'\d');
  void blank(int start, int end, {bool all = false}) {
    for (var i = start; i < end; i++) {
      if (all || digit.hasMatch(chars[i])) chars[i] = '•';
    }
  }

  for (final match in [
    ..._accountRef.allMatches(text),
    ..._blockRef.allMatches(text),
  ]) {
    final digits = match.group(1)!;
    final start = match.start + match.group(0)!.lastIndexOf(digits);
    blank(start, start + digits.length);
  }
  for (final match in _longDigits.allMatches(text)) {
    blank(match.start, match.end);
  }
  for (final match in _vpa.allMatches(text)) {
    final local = match.group(1)!;
    if (local.length > 2) {
      blank(match.start + 2, match.start + local.length, all: true);
    }
  }
  return chars.join();
}

String _normalise(String raw) {
  return raw
      .replaceAll(RegExp('[​-‍﻿]'), '')
      .replaceAll('\r\n', '\n')
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .join('\n');
}

String _fingerprint(String text) {
  final canonical = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  return sha256.convert(utf8.encode('penny-sms-v1|$canonical')).toString();
}

/// Money put into investing is money out, whatever words it uses ("units
/// credited"). Otherwise the earliest clear money word decides; "txn" or
/// "payment" alone means money out.
TxnType? _direction(String text) {
  if (_investOut.hasMatch(text)) return TxnType.debit;
  int? earliest(List<RegExp> patterns) {
    int? start;
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && (start == null || match.start < start)) {
        start = match.start;
      }
    }
    return start;
  }

  final debit = earliest([_strongDebit, _drWord, _autopay]);
  final credit = earliest([_strongCredit, _crWord]);
  if (debit != null && (credit == null || debit < credit)) {
    return TxnType.debit;
  }
  if (credit != null) return TxnType.credit;
  if (_weakDebit.hasMatch(text) || _paidFromWallet.hasMatch(text)) {
    return TxnType.debit;
  }
  return null;
}

typedef _Amount = ({int paise, int start, int end});

_Amount? _amount(String text) {
  for (final match in _currencyAmount.allMatches(text)) {
    final before = text.substring(math.max(0, match.start - 25), match.start);
    if (_amountIsBalance.hasMatch(before)) continue;
    if (_balanceAfter.hasMatch(text.substring(match.end))) continue;
    final paise = _toPaise(match.group(1)!);
    if (paise != null && paise > 0) {
      return (paise: paise, start: match.start, end: match.end);
    }
  }
  final bare = _bareAmount.firstMatch(text);
  final paise = bare == null ? null : _toPaise(bare.group(1)!);
  if (bare != null && paise != null && paise > 0) {
    final start = bare.start + bare.group(0)!.lastIndexOf(bare.group(1)!);
    return (paise: paise, start: start, end: start + bare.group(1)!.length);
  }
  // No ₹, Rs or INR at all, as in "Your UPI transaction of 641.00 has been
  // reversed": the first amount with paise that isn't a balance or a limit.
  for (final match in _plainAmount.allMatches(text)) {
    final before = text.substring(math.max(0, match.start - 25), match.start);
    if (_amountIsBalance.hasMatch(before)) continue;
    if (_balanceAfter.hasMatch(text.substring(match.end))) continue;
    final plain = _toPaise(match.group(0)!);
    if (plain != null && plain > 0) {
      return (paise: plain, start: match.start, end: match.end);
    }
  }
  return null;
}

// "641.00", "1,200.00": an amount with paise, standing on its own, so a
// date like "06.11.26" isn't one.
final _plainAmount = RegExp(r'(?<![\d.,])\d[\d,]*\.\d{2}(?![\d.])');

int? _toPaise(String number) {
  final cleaned = number.replaceAll(',', '');
  final parts = cleaned.split('.');
  final rupees = int.tryParse(parts[0]);
  if (rupees == null) return null;
  final fraction = parts.length > 1
      ? parts[1].padRight(2, '0').substring(0, 2)
      : '00';
  return rupees * 100 + int.parse(fraction);
}

typedef _Payee = ({String name, bool isPerson, int start, int end});

_Payee? _payee(String text, TxnType type) {
  if (type == TxnType.debit && _atmWithdrawal.hasMatch(text)) {
    return (name: 'ATM withdrawal', isPerson: false, start: 0, end: 0);
  }
  final patterns = type == TxnType.debit ? _debitPayees : _creditPayees;
  for (final pattern in patterns) {
    for (final match in pattern.allMatches(text)) {
      final raw = match.group(1)!;
      final start = match.start + match.group(0)!.indexOf(raw);
      final end = start + raw.length;
      if (raw.contains('@')) {
        final local = raw.substring(0, raw.indexOf('@'));
        // A phone number is not a name worth keeping.
        if (RegExp(r'\d{6,}').hasMatch(local)) return null;
        final name = _titleCase(local.replaceAll(RegExp(r'[._\-]+'), ' '));
        return (
          name: name,
          isPerson: !_business.hasMatch(name),
          start: start,
          end: end,
        );
      }
      if (raw == raw.toLowerCase() &&
          _domainNext.hasMatch(text.substring(end))) {
        continue;
      }
      final name = _cleanName(raw);
      if (name == null) continue;
      final isPerson =
          pattern != _upiPath ||
          match.group(0)!.toLowerCase().contains('/p2a/');
      return (
        name: name,
        isPerson: isPerson && _looksLikePerson(name),
        start: start,
        end: end,
      );
    }
  }
  return null;
}

final _domainNext = RegExp(r'^\.[a-z]{2,6}\b');

String? _cleanName(String raw) {
  final name = raw
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r"[\s\-&'*]+$"), '')
      .trim();
  if (name.length < 2 || _notAPayee.hasMatch(name)) return null;
  if (!RegExp('[A-Za-z]{2}').hasMatch(name)) return null;
  return _titleCase(name.length > 40 ? name.substring(0, 40).trim() : name);
}

/// Brands named like people: in a name of two or more words they're more
/// likely someone's first name ("Zara Khan", "Dhan Singh") than the shop.
const _nameLikeBrands = {
  'zara',
  'dhan',
  'max',
  'raymond',
  'mango',
  'arrow',
  'lakme',
  'tanishq',
};

/// Whether [name], a payee that reads like a person's, is one: two to four
/// words that, brands named like people aside, say nothing of a shop.
/// "Zara Khan" and "Dhan Singh" are; "Zara" alone, "HP Petrol Pump" and
/// "Shree Ganesh Mandir Trust" aren't.
bool _isPersonName(String name) {
  final words = name.split(' ');
  if (words.length < 2) return false;
  final rest = [
    for (final word in words)
      if (!_nameLikeBrands.contains(word.toLowerCase())) word,
  ].join(' ');
  return rest.isEmpty ||
      suggestCategory(type: TxnType.debit, text: rest, payee: rest) == null;
}

/// Whether an SMS payee's name reads like a person's rather than a shop's:
/// a few plain words, and no business words.
bool _looksLikePerson(String name) {
  final words = name.split(' ');
  return words.length <= 4 &&
      words.every((word) => RegExp(r"^[A-Za-z.']+$").hasMatch(word)) &&
      !_business.hasMatch(name);
}

/// "SWIGGY" → "Swiggy", "rohan das" → "Rohan Das". Mixed case is left as
/// the sender wrote it; acronyms and vowel-less abbreviations stay capitals.
String _titleCase(String name) {
  final hasUpper = name.contains(RegExp('[A-Z]'));
  final hasLower = name.contains(RegExp('[a-z]'));
  if (hasUpper && hasLower) return name;
  return name
      .split(' ')
      .map((word) {
        if (word.isEmpty) return word;
        final upper = word.toUpperCase();
        if (_acronyms.contains(upper)) return upper;
        if (word.length >= 2 &&
            !_plainWords.contains(upper) &&
            !RegExp('[aeiouAEIOU]').hasMatch(word) &&
            RegExp('^[A-Za-z]+\$').hasMatch(word)) {
          return upper;
        }
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      })
      .join(' ');
}

typedef _Date = ({DateTime at, bool hasTime, int start, int end});

_Date? _date(String text, DateTime now) {
  final candidates = <_Date>[];
  void add(RegExpMatch match, int year, int month, int day) {
    final y = year < 100 ? 2000 + year : year;
    if (month < 1 || month > 12 || day < 1 || day > 31) return;
    final hour = int.tryParse(match.group(4) ?? '');
    final minute = int.tryParse(match.group(5) ?? '');
    final second = int.tryParse(match.group(6) ?? '') ?? 0;
    final hasTime = hour != null && minute != null && hour < 24 && minute < 60;
    final at = hasTime
        ? DateTime(y, month, day, hour, minute, second)
        : DateTime(y, month, day);
    if (at.month != month || at.day != day) return;
    if (at.isAfter(now.add(const Duration(days: 1)))) return;
    if (at.isBefore(now.subtract(const Duration(days: 400)))) return;
    candidates.add((
      at: at,
      hasTime: hasTime,
      start: match.start,
      end: match.end,
    ));
  }

  for (final m in _isoDate.allMatches(text)) {
    add(
      m,
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }
  for (final m in _namedDate.allMatches(text)) {
    final month =
        _months.indexOf(m.group(2)!.toLowerCase().substring(0, 3)) + 1;
    add(m, int.parse(m.group(3)!), month, int.parse(m.group(1)!));
  }
  for (final m in _numericDate.allMatches(text)) {
    add(
      m,
      int.parse(m.group(3)!),
      int.parse(m.group(2)!),
      int.parse(m.group(1)!),
    );
  }
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) => a.start.compareTo(b.start));
  return candidates.first;
}

SmsPreview _preview(
  String text,
  List<RegExpMatch> accounts,
  _Amount amount,
  _Payee? payee,
  _Date? date,
) {
  // Digits are blanked in account numbers, references and balances; whole
  // characters in the name part of a UPI ID (past its first two).
  final hidden = <SmsSpan>[];
  final namesHidden = <SmsSpan>[];
  for (final match in accounts) {
    final digits = match.group(1)!;
    final start = match.start + match.group(0)!.lastIndexOf(digits);
    hidden.add(SmsSpan(start, start + digits.length, SpanKind.hidden));
  }
  for (final match in _blockRef.allMatches(text)) {
    final digits = match.group(1)!;
    final start = match.start + match.group(0)!.lastIndexOf(digits);
    hidden.add(SmsSpan(start, start + digits.length, SpanKind.hidden));
  }
  for (final match in _vpa.allMatches(text)) {
    final local = match.group(1)!;
    if (local.length > 2) {
      namesHidden.add(
        SmsSpan(match.start + 2, match.start + local.length, SpanKind.hidden),
      );
    }
  }
  for (final match in _longDigits.allMatches(text)) {
    if (match.end <= amount.start || match.start >= amount.end) {
      hidden.add(SmsSpan(match.start, match.end, SpanKind.hidden));
    }
  }
  // Balances and limits: not read, so not shown.
  for (final match in _currencyAmount.allMatches(text)) {
    final before = text.substring(math.max(0, match.start - 25), match.start);
    if (_amountIsBalance.hasMatch(before)) {
      hidden.add(SmsSpan(match.start, match.end, SpanKind.hidden));
    }
  }

  final chars = text.split('');
  final digit = RegExp(r'\d');
  for (final span in hidden) {
    for (var i = span.start; i < span.end; i++) {
      if (digit.hasMatch(chars[i])) chars[i] = '•';
    }
  }
  for (final span in namesHidden) {
    for (var i = span.start; i < span.end; i++) {
      chars[i] = '•';
    }
  }
  hidden.addAll(namesHidden);

  return SmsPreview(chars.join(), [
    ...hidden,
    SmsSpan(amount.start, amount.end, SpanKind.amount),
    if (payee != null && payee.end > payee.start)
      SmsSpan(payee.start, payee.end, SpanKind.payee),
    if (date != null) SmsSpan(date.start, date.end, SpanKind.date),
  ]);
}

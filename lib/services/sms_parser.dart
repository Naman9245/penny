import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
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
final _refundWord = _rx(r'\b(?:refund|refunded|reversal|reversed)\b');
final _credited = _rx(r'\bcredited\b');
final _offer = _rx(
  r"\b(?:pre-?approved|apply now|loan (?:of )?(?:up ?to|upto)|cashback (?:of )?up ?to|offer|congratulations|t&c|limited period|get flat|use code)\b",
);
final _balanceWord = _rx(r'\b(?:bal|balance|avl|available)\b');

// "A/c XX4821", "Card 7712", "AC X8899", "account XXX234", "card ending 4455".
final _accountRef = _rx(
  r'\b(?:a/?c|acct|account|card)(?:\s*no\.?)?(?:\s*ending(?:\s*with)?)?[\s:.]*([xX*•.]*\d{2,})',
);
final _vpa = _rx(r'\b([\w.\-]{2,})@([a-z][a-z.]*)\b');
// The account or card tail in a bank's "SMS BLOCK DC 7712 to …" footer.
final _blockRef = _rx(r'\bblock\s*(?:dc|cc|upi)?\s+(\d{3,6})\b');
final _longDigits = RegExp(r'\d{6,}');

final _strongDebit = _rx(
  r'\b(?:debited|spent|sent|paid|withdrawn|deducted|purchased?|transferred\s+to(?!\s+your)|transferred\s+from)\b',
);
final _strongCredit = _rx(
  r'\b(?:credited|received|deposited|refund(?:ed)?|reversal|reversed|credit\s+of)\b',
);
final _weakDebit = _rx(r'\b(?:txn|transaction|payment)\b');

final _currencyAmount = _rx(
  r'(?:₹|\brs\.?|\binr)\s*:?\s*([\d,]+(?:\.\d{1,2})?)',
);
final _bareAmount = _rx(
  r'\b(?:debited|credited)\s+(?:by|for|with)\s+([\d,]+(?:\.\d{1,2})?)\b',
);
final _amountIsBalance = _rx(
  r'(?:bal(?:ance)?|limit|avl(?:bl)?|avail(?:able)?|outstanding|due|min(?:imum)?)\.?[\s:.\-]*(?:amt|amount|bal(?:ance)?)?[\s:.\-]*$',
);

// Payee patterns. A name runs until a word or mark that ends it.
const _honorific = r'(?:(?:mr|mrs|ms|miss|shri|smt|dr)\.?\s+)?';
const _name = r"([a-z][a-z0-9&'* ]{0,40}?)";
const _end =
    r'(?=\s*(?:$|[\n.;,(:/])|\s+(?:on|ref|refno|upi|via|from|avl|info|not|if|call|dt|dated|thru|towards|for|has|have|is|was|by|with|using|at|in|to|bal)\b|\s+-)';
final _upiPath = _rx(r'\bupi/(?:p2[am]/)?\d+/([a-z][^/\n.]{1,40})');
final _debitPayees = [
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
];
final _notAPayee = _rx(
  r'^(?:(?:rs|inr)\.?\s*\d|(?:rs|inr|upi|txn|your|you|ur|a/?c|ac|acct|account|card|bank|the|ref|vpa|imps|neft|date|dt)\b)',
);
final _atmWithdrawal = _rx(
  r'\b(?:withdrawn|withdrawal)\b[^\n]*\batm\b|\batm\b[^\n]*\bwithdrawn\b',
);
final _business = _rx(
  r'\b(?:pvt|private|ltd|limited|llp|india|store|stores|services|technologies|solutions|pay|bank|mart|enterprises|restaurant|cafe|hotel)\b',
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
  if (_upcoming.hasMatch(text)) return const SmsIgnored(IgnoreReason.upcoming);
  final refundCredited = _refundWord.hasMatch(text) && _credited.hasMatch(text);
  if (!refundCredited && _failed.hasMatch(text)) {
    return const SmsIgnored(IgnoreReason.failed);
  }
  if (_ownCardPayment.hasMatch(text)) {
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
  final category = suggestCategory(type: type, text: text, payee: payee?.name);

  return SmsTxn(
    amountPaise: amount.paise,
    type: type,
    payee: payee?.name,
    payeeIsPerson: payee != null && payee.isPerson && category == null,
    occurredAt: date?.at,
    hasTime: date?.hasTime ?? false,
    suggestedCategoryId: category,
    dedupeKey: _fingerprint(text),
    preview: _preview(text, accounts, amount, payee, date),
  );
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

/// The earliest clear money verb decides; "txn" or "payment" alone means
/// money out.
TxnType? _direction(String text) {
  final debit = _strongDebit.firstMatch(text);
  final credit = _strongCredit.firstMatch(text);
  if (debit != null && (credit == null || debit.start < credit.start)) {
    return TxnType.debit;
  }
  if (credit != null) return TxnType.credit;
  if (_weakDebit.hasMatch(text)) return TxnType.debit;
  return null;
}

typedef _Amount = ({int paise, int start, int end});

_Amount? _amount(String text) {
  for (final match in _currencyAmount.allMatches(text)) {
    final before = text.substring(math.max(0, match.start - 25), match.start);
    if (_amountIsBalance.hasMatch(before)) continue;
    final paise = _toPaise(match.group(1)!);
    if (paise != null && paise > 0) {
      return (paise: paise, start: match.start, end: match.end);
    }
  }
  final bare = _bareAmount.firstMatch(text);
  final paise = bare == null ? null : _toPaise(bare.group(1)!);
  if (bare == null || paise == null || paise <= 0) return null;
  final start = bare.start + bare.group(0)!.lastIndexOf(bare.group(1)!);
  return (paise: paise, start: start, end: start + bare.group(1)!.length);
}

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

String? _cleanName(String raw) {
  final name = raw
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r"[\s\-&'*]+$"), '')
      .trim();
  if (name.length < 2 || _notAPayee.hasMatch(name)) return null;
  if (!RegExp('[A-Za-z]{2}').hasMatch(name)) return null;
  return _titleCase(name.length > 40 ? name.substring(0, 40).trim() : name);
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

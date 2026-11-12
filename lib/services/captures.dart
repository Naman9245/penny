import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/capture_repository.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/prefs_repository.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/data/upcoming_repository.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/models/your_rules.dart';
import 'package:penny/services/merchant_categories.dart';
import 'package:penny/services/money_kinds.dart';
import 'package:penny/services/notification_inbox.dart';
import 'package:penny/services/penny_ai.dart';
import 'package:penny/services/sms_ai.dart';
import 'package:penny/services/sms_parser.dart';

// Payments read from notifications, all on the phone: which notifications
// are payments, which of those are already here, what's done with the rest,
// and what Penny tells the user about it.

/// The apps Penny reads, as people call them.
const _appNames = {
  'sms': 'SMS',
  'gpay': 'GPay',
  'phonepe': 'PhonePe',
  'paytm': 'Paytm',
  'payzapp': 'PayZapp',
  'mobikwik': 'MobiKwik',
  'cred': 'CRED',
  'bhim': 'BHIM',
  'supermoney': 'super.money',
  'groww': 'Groww',
  'kite': 'Kite',
  'upstox': 'Upstox',
  'indmoney': 'INDmoney',
  'paytmmoney': 'Paytm Money',
};

/// [app], as people call it: "SMS", "GPay".
String appName(String app) => _appNames[app] ?? app;

/// Why a notification isn't a payment, in words for "What Penny read".
const _letGo = {
  IgnoreReason.otp: 'an OTP',
  IgnoreReason.request: 'a request for money',
  IgnoreReason.upcoming: 'a payment not made yet',
  IgnoreReason.failed: 'a failed payment',
  IgnoreReason.offer: 'an offer',
  IgnoreReason.ownTransfer: 'a move between your own accounts',
  IgnoreReason.cardBill: 'a credit card bill',
  IgnoreReason.receipt: 'a receipt for a payment already made',
  IgnoreReason.balance: 'only a balance',
  IgnoreReason.unreadable: 'no payment in it',
};

/// [capture] read the way a shared SMS is: the payment in it, or why it was
/// let go. From the SMS app it counts only when it's from a bank, a wallet
/// or an investment: a sender code or a money brand's name, or a message
/// showing a masked account or card number. So a friend's text about money
/// isn't taken, even one that says "account" or "wallet".
({SmsTxn? payment, String? letGo}) explainCapture(Capture capture) {
  final fromSms = capture.app == 'sms';
  if (fromSms &&
      !isMoneySender(capture.title) &&
      !mentionsMaskedAccount(capture.text)) {
    return (payment: null, letGo: 'not from a bank');
  }
  // A payment app puts half of it in the title: "₹250 paid to Swiggy".
  final text = fromSms || capture.title.trim().isEmpty
      ? capture.text
      : '${capture.title}\n${capture.text}';
  return switch (parseSms(text, now: capture.at)) {
    // A payment app's notices for two payments can read alike, word for
    // word: the minute each came tells them apart. An SMS never does, with
    // its own reference or balance.
    final SmsTxn payment when !fromSms => (
      payment: payment.withDedupeKey(_appKey(payment, capture.at)),
      letGo: null,
    ),
    final SmsTxn payment => (payment: payment, letGo: null),
    SmsIgnored(:final reason) => (payment: null, letGo: _letGo[reason]),
  };
}

String _appKey(SmsTxn payment, DateTime at) {
  final minute = DateTime(at.year, at.month, at.day, at.hour, at.minute);
  return sha256
      .convert(
        utf8.encode(
          'penny-app|${payment.dedupeKey}|${minute.millisecondsSinceEpoch}',
        ),
      )
      .toString();
}

/// [capture]'s payment, or null when it isn't one.
SmsTxn? readCapture(Capture capture) => explainCapture(capture).payment;

/// Words that say money moved. Only a notification with one is worth
/// asking Penny's AI about.
final _moneyMoved = RegExp(
  r'\b(?:debit(?:ed)?|credit(?:ed)?|paid|pay(?:ment)?|sent|received|deducted|added|spent|withdrawn|transferred|refund(?:ed)?|cashback|invest(?:ed|ment)?|purchased?|order|sip|emi|txn|transaction|dr|cr|units?|allotted|deposit(?:ed)?|redeemed|redemption)\b',
  caseSensitive: false,
);

/// What [capture] says, as it's read: a payment app puts half of it in the
/// title.
String _textOf(Capture capture) =>
    capture.app == 'sms' || capture.title.trim().isEmpty
    ? capture.text
    : '${capture.title}\n${capture.text}';

/// [capture], which Penny's rules couldn't read, as her AI reads it: every
/// word that could be a name hidden first ([maskForAi]), and put back in
/// what the AI answers. A payment counts only with an amount the message
/// gives. Throws [AiException] when the AI can't answer now.
Future<({SmsTxn? payment, String? letGo})> readWithAi(
  AiClient ai,
  Capture capture,
) async {
  final fromSms = capture.app == 'sms';
  final text = _textOf(capture);
  final masked = maskForAi(text);
  final read = await ai.readSms(
    from: fromSms ? 'sms' : 'app',
    text: masked.text,
  );
  final type = read.type;
  if (!read.payment || type == null) {
    return (
      payment: null,
      letGo: read.ownMoney
          ? _letGo[IgnoreReason.ownTransfer]
          : _letGo[IgnoreReason.unreadable],
    );
  }
  final id = read.categoryId;
  final categoryId =
      id != null &&
          categoryById(id).id == id &&
          categoryById(id).type == type &&
          // Pay only when the message says so.
          (id != 'salary' || looksLikeSalary(text))
      ? id
      : null;
  final payment = paymentFrom(
    text,
    type: type,
    amountPaise: read.amountPaise,
    payee: unmask(read.payee, masked.tags),
    categoryId: categoryId,
    now: capture.at,
  );
  if (payment == null) {
    return (payment: null, letGo: _letGo[IgnoreReason.unreadable]);
  }
  return (
    payment: fromSms
        ? payment
        : payment.withDedupeKey(_appKey(payment, capture.at)),
    letGo: null,
  );
}

/// When [sms] happened: the time it gives, or else when its notification
/// came, on the day it gives.
DateTime occurredAtOf(SmsTxn sms, DateTime notified) {
  final at = sms.occurredAt;
  if (at == null) return notified;
  if (sms.hasTime) return at;
  return dayStart(at) == dayStart(notified) ? notified : onDay(at, notified);
}

/// A payment in a few words: "−₹250 · Swiggy", "+₹500 · Got".
String whatOf(SmsTxn sms) {
  final sign = sms.type == TxnType.debit ? '−' : '+';
  final who = sms.payee ?? (sms.type == TxnType.debit ? 'Spent' : 'Got');
  return '$sign${formatPaise(sms.amountPaise)} · $who';
}

/// The category [read] went in, or would, like "🍔 Food". Null without
/// one.
String? _categoryOf(CaptureRead read) {
  final id = read.categoryId;
  final sms = read.sms;
  if (id == null || sms == null) return null;
  return '${categoryById(id).emoji} ${kindLabel(sms.type, id)}';
}

/// Where a payment Penny can't place goes when she saves it straight away:
/// To people, or From people, for a person; Other for anything else. The
/// user can change it.
String fallbackCategoryOf(SmsTxn sms) => switch (sms.type) {
  TxnType.debit => sms.payeeIsPerson ? 'people' : 'other',
  TxnType.credit => sms.payeeIsPerson ? 'from_people' : 'other_income',
};

/// How far apart a bank SMS and a payment app's notice of one payment can
/// come.
const _sameMoment = Duration(minutes: 30);

/// An entry, or a payment waiting, that [sms] at [at] may already be, in
/// words: the same amount the same way, within half an hour, or on the same
/// day when the entry was typed by hand. Null when there's none.
Future<String?> lookalikeOf(AppDatabase db, SmsTxn sms, DateTime at) async {
  final day = dayStart(at);
  final nextDay = DateTime(day.year, day.month, day.day + 1);
  final early = at.subtract(_sameMoment);
  final late = at.add(_sameMoment);
  final entries =
      await (db.select(db.txns)..where(
            (t) =>
                t.deletedAt.isNull() &
                t.amountPaise.equals(sms.amountPaise) &
                t.type.equalsValue(sms.type) &
                t.occurredAt.isBetweenValues(
                  early.isBefore(day) ? early : day,
                  late.isAfter(nextDay) ? late : nextDay,
                ),
          ))
          .get();
  for (final txn in entries) {
    final near = txn.occurredAt.difference(at).abs() <= _sameMoment;
    final sameDay = dayStart(txn.occurredAt) == day;
    if (txn.source == TxnSource.manual ? sameDay : near) {
      return '${formatPaise(txn.amountPaise)} · '
          '${txn.merchant ?? kindLabel(txn.type, txn.categoryId)} at '
          '${_time(txn.occurredAt)}';
    }
  }
  final waiting =
      await (db.select(db.pendingCaptures)..where(
            (p) =>
                p.skippedAt.isNull() &
                p.dedupeKey.equals(sms.dedupeKey).not() &
                p.amountPaise.equals(sms.amountPaise) &
                p.type.equalsValue(sms.type) &
                p.occurredAt.isBetweenValues(early, late),
          ))
          .get();
  if (waiting.firstOrNull case final other?) {
    return '${formatPaise(other.amountPaise)} · '
        '${other.payee ?? 'a payment'} at ${_time(other.occurredAt)}, also '
        'waiting';
  }
  return null;
}

String _time(DateTime at) => DateFormat('h:mm a').format(at);

/// How far apart a bank's SMS for an investment and the fund's own
/// confirmation of it can come.
const _sameInvestment = Duration(days: 3);

/// Where a payment was read: an app, or for an SMS, who sent it. A sender
/// code's route prefix and suffix don't count: "JM-HDFCBK-S" is "HDFCBK".
String _sourceOf(String app, String? sender) {
  if (app != 'sms') return app;
  final name = (sender ?? '').trim();
  final code = _senderCode.firstMatch(name)?.group(1);
  return 'sms:${(code ?? name).toUpperCase()}';
}

final _senderCode = RegExp(
  r'^[A-Z]{2}-([A-Z0-9]{3,9})(?:-[A-Z])?$',
  caseSensitive: false,
);

/// The same payment, read already: the bank's SMS and a payment app's
/// notice (GPay, PhonePe…) for the same amount the same way, within half an
/// hour. Two apps' notices are two payments, as one payment never shows in
/// two apps, and so are two SMS. For investing, any other place within
/// three days counts: the bank's debit, then the fund's confirmation. Two
/// payments from one place are two payments, and one already matched with
/// a copy from this place isn't matched again. Says where it was read, in words for "What Penny read"
/// like "already saved from SMS", and the entry it was saved as, if it was.
Future<({String what, String? entryId})?> repeatOf(
  AppDatabase db,
  SmsTxn sms,
  DateTime at, {
  required String app,
  String? sender,
}) async {
  final investing = isInvestCategory(sms.suggestedCategoryId);
  final window = investing ? _sameInvestment : _sameMoment;
  final source = _sourceOf(app, sender);
  final rows =
      await (db.select(db.pendingCaptures)..where(
            (p) =>
                p.dedupeKey.equals(sms.dedupeKey).not() &
                p.amountPaise.equals(sms.amountPaise) &
                p.type.equalsValue(sms.type) &
                p.occurredAt.isBetweenValues(
                  at.subtract(window),
                  at.add(window),
                ),
          ))
          .get();
  for (final row in rows) {
    // Kept before senders were: who sent it isn't known.
    if (row.app == 'sms' && row.sender == null) continue;
    final from = _sourceOf(row.app, row.sender);
    if (from == source) continue;
    // One payment is an SMS and an app's notice, never two of either; an
    // investment and its confirmation can be any two places.
    if (!investing && (row.app == 'sms') == (app == 'sms')) continue;
    final entryId = row.savedAs;
    if (entryId != null) {
      final copies =
          await (db.select(db.pendingCaptures)..where(
                (p) =>
                    p.savedAs.equals(entryId) &
                    p.dedupeKey.equals(row.dedupeKey).not(),
              ))
              .get();
      if (copies.any((copy) => _sourceOf(copy.app, copy.sender) == source)) {
        continue;
      }
    }
    final where = appName(row.app);
    return (
      what: entryId != null
          ? 'already saved from $where'
          : row.skippedAt != null
          ? 'already skipped from $where'
          : 'already waiting from $where',
      entryId: entryId,
    );
  }
  return null;
}

/// The entry [sms] at [at], read from [app] (an SMS from [sender]), already
/// is, for the same amount the same way: one typed by hand that day, or one
/// saved from a read Penny has no record of, like an entry back from the
/// backup, within half an hour (three days for investing). One already
/// matched with a copy from this place isn't matched again, so two real
/// payments of one amount stay two. Says how, in words for "What Penny
/// read", and which entry. Null when there's none.
Future<({String what, String entryId})?> sameEntryOf(
  AppDatabase db,
  SmsTxn sms,
  DateTime at, {
  required String app,
  String? sender,
}) async {
  final window = isInvestCategory(sms.suggestedCategoryId)
      ? _sameInvestment
      : _sameMoment;
  final day = dayStart(at);
  final nextDay = DateTime(day.year, day.month, day.day + 1);
  final early = at.subtract(window);
  final late = at.add(window);
  final source = _sourceOf(app, sender);
  final entries =
      await (db.select(db.txns)..where(
            (t) =>
                t.deletedAt.isNull() &
                t.amountPaise.equals(sms.amountPaise) &
                t.type.equalsValue(sms.type) &
                t.occurredAt.isBetweenValues(
                  early.isBefore(day) ? early : day,
                  late.isAfter(nextDay) ? late : nextDay,
                ),
          ))
          .get();
  Duration apart(Txn txn) => txn.occurredAt.difference(at).abs();
  entries.sort((a, b) => apart(a).compareTo(apart(b)));
  for (final txn in entries) {
    final typed = txn.source == TxnSource.manual;
    if (typed ? dayStart(txn.occurredAt) != day : apart(txn) > window) {
      continue;
    }
    final copies = await (db.select(
      db.pendingCaptures,
    )..where((p) => p.savedAs.equals(txn.id))).get();
    // Where a read entry came from is [repeatOf]'s to weigh.
    if (!typed && copies.any((copy) => copy.dedupeKey == txn.dedupeKey)) {
      continue;
    }
    if (copies.any((copy) => _sourceOf(copy.app, copy.sender) == source)) {
      continue;
    }
    return (
      what: typed ? 'already typed by you' : 'already saved',
      entryId: txn.id,
    );
  }
  return null;
}

/// The category of the latest entry paid to, or from, the same name as
/// [sms], so a shop or person Penny reads again goes where the user put it
/// before. Null for a payment without a name, or a name not met yet.
Future<String?> yourCategoryOf(AppDatabase db, SmsTxn sms) async {
  final payee = sms.payee?.trim().toLowerCase();
  if (payee == null || payee.isEmpty) return null;
  final last =
      await (db.select(db.txns)
            ..where(
              (t) =>
                  t.deletedAt.isNull() &
                  t.type.equalsValue(sms.type) &
                  t.merchant.trim().lower().equals(payee),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
            ..limit(1))
          .getSingleOrNull();
  final id = last?.categoryId;
  // Only one of the same kind: a spend's category for a spend.
  if (id == null || categoryById(id).type != sms.type) return null;
  return id;
}

/// An entry Penny saved from a payment she read that copies an entry
/// already there, and that entry.
typedef ReadCopy = ({Txn copy, Txn of});

/// Every entry Penny saved from a payment she read that copies another,
/// oldest first: for the same amount the same way, on the day of one typed
/// by hand, or within half an hour (three days for investing) of an older
/// one read somewhere else (an SMS against an app's notice), or one she has
/// no record of, like an entry back from the backup. One typed by hand is
/// always the one kept, and each entry is copied at most once from each
/// place, so two real payments of one amount stay two.
Future<List<ReadCopy>> findReadCopies(AppDatabase db) async {
  final entries = await (db.select(
    db.txns,
  )..where((t) => t.deletedAt.isNull())).get();
  final byId = {for (final entry in entries) entry.id: entry};
  final records = await (db.select(
    db.pendingCaptures,
  )..where((p) => p.savedAs.isNotNull())).get();
  // Where each read entry was read, and the places already matched to each
  // entry.
  final readAs = <String, PendingCapture>{};
  final matched = <String, Set<String>>{};
  for (final record in records) {
    final id = record.savedAs!;
    if (byId[id]?.dedupeKey == record.dedupeKey) {
      readAs[id] = record;
    } else {
      (matched[id] ??= {}).add(_sourceOf(record.app, record.sender));
    }
  }
  final reads = [
    for (final entry in entries)
      if (readAs.containsKey(entry.id)) entry,
  ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  final copies = <ReadCopy>[];
  final gone = <String>{};
  for (final copy in reads) {
    final record = readAs[copy.id]!;
    final place = _sourceOf(record.app, record.sender);
    final investing = isInvestCategory(copy.categoryId);
    final window = investing ? _sameInvestment : _sameMoment;
    Duration apart(Txn other) =>
        other.occurredAt.difference(copy.occurredAt).abs();
    final candidates = [
      for (final other in entries)
        if (other.id != copy.id &&
            !gone.contains(other.id) &&
            other.amountPaise == copy.amountPaise &&
            other.type == copy.type &&
            !(matched[other.id]?.contains(place) ?? false) &&
            _isCopyOf(copy, record, other, readAs[other.id], investing, window))
          other,
    ];
    if (candidates.isEmpty) continue;
    // One typed by hand first, then the nearest.
    candidates.sort((a, b) {
      final typed = (b.source == TxnSource.manual ? 1 : 0).compareTo(
        a.source == TxnSource.manual ? 1 : 0,
      );
      return typed != 0 ? typed : apart(a).compareTo(apart(b));
    });
    final of = candidates.first;
    copies.add((copy: copy, of: of));
    gone.add(copy.id);
    (matched[of.id] ??= {}).add(place);
  }
  return copies;
}

/// Whether [copy], read as [record], is the same payment as [other], read
/// as [otherRecord] when Penny knows.
bool _isCopyOf(
  Txn copy,
  PendingCapture record,
  Txn other,
  PendingCapture? otherRecord,
  bool investing,
  Duration window,
) {
  if (other.source == TxnSource.manual) {
    return dayStart(other.occurredAt) == dayStart(copy.occurredAt);
  }
  if (other.occurredAt.difference(copy.occurredAt).abs() > window) {
    return false;
  }
  // The older one stays.
  if (!other.createdAt.isBefore(copy.createdAt)) return false;
  if (otherRecord == null) return true;
  if (_sourceOf(otherRecord.app, otherRecord.sender) ==
      _sourceOf(record.app, record.sender)) {
    return false;
  }
  // One payment is an SMS and an app's notice, never two of either; an
  // investment and its confirmation can be any two places.
  return investing || (otherRecord.app == 'sms') != (record.app == 'sms');
}

/// Takes [copies] off: each copy is deleted, and what was read for it is
/// kept as a copy of the entry it copies, so it's never saved again. What
/// [restoreReadCopies] needs to put them back.
Future<Map<String, List<String>>> removeReadCopies(
  AppDatabase db,
  TxnRepository txns,
  List<ReadCopy> copies,
) => db.transaction(() async {
  final moved = <String, List<String>>{};
  for (final (:copy, :of) in copies) {
    final records = await (db.select(
      db.pendingCaptures,
    )..where((p) => p.savedAs.equals(copy.id))).get();
    await (db.update(db.pendingCaptures)
          ..where((p) => p.savedAs.equals(copy.id)))
        .write(PendingCapturesCompanion(savedAs: Value(of.id)));
    await txns.softDelete(copy.id);
    moved[copy.id] = [for (final record in records) record.dedupeKey];
  }
  return moved;
});

/// Puts back the copies [removeReadCopies] took off, as [moved] says.
Future<void> restoreReadCopies(
  AppDatabase db,
  TxnRepository txns,
  Map<String, List<String>> moved,
) => db.transaction(() async {
  for (final MapEntry(key: id, value: keys) in moved.entries) {
    await txns.restore(id);
    await (db.update(db.pendingCaptures)..where((p) => p.dedupeKey.isIn(keys)))
        .write(PendingCapturesCompanion(savedAs: Value(id)));
  }
});

/// Words that say money came back for a payment.
final _moneyBack = RegExp(
  r'\b(?:reversed|reversal|refund|refunded|credited\s+back|returned)\b',
  caseSensitive: false,
);

/// How long after a payment money for it can still come back.
const _backWithin = Duration(days: 7);

/// The payment [sms] gives back, when it's money coming back ("reversed",
/// "refunded"): one paid out in a spend category in the 7 days before [at],
/// for the same amount, that hasn't had its money back already. Of those,
/// the one paid to the same payee, then the one read from the same bank as
/// [from] (where the money back was read, as [_sourceOf] says), then the
/// newest. Null when there's none.
Future<Txn?> reversedPaymentOf(
  AppDatabase db,
  SmsTxn sms,
  DateTime at,
  String text, {
  String? from,
}) async {
  if (sms.type != TxnType.credit || !_moneyBack.hasMatch(text)) return null;
  final since = at.subtract(_backWithin);
  final rows =
      await (db.select(db.txns)
            ..where(
              (t) =>
                  t.deletedAt.isNull() &
                  t.amountPaise.equals(sms.amountPaise) &
                  t.occurredAt.isBetweenValues(
                    since.subtract(_backBefore),
                    at.add(_backBefore),
                  ),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]))
          .get();
  final open = [
    for (final t in rows)
      if (t.type == TxnType.debit &&
          isSpendCategory(t.categoryId) &&
          !t.occurredAt.isBefore(since) &&
          !t.occurredAt.isAfter(at))
        t,
  ];
  // Money already back for one of them, oldest first, takes the newest
  // payment in its category it can be for: paid before it, or within the
  // hour after, as a reversal can come first.
  for (final back in rows) {
    if (back.type != TxnType.credit || !isSpendCategory(back.categoryId)) {
      continue;
    }
    final match = open
        .where(
          (paid) =>
              paid.categoryId == back.categoryId &&
              !paid.occurredAt.isAfter(back.occurredAt.add(_backBefore)),
        )
        .lastOrNull;
    if (match != null) open.remove(match);
  }
  if (open.isEmpty) return null;

  final payee = shopKey(sms.payee);
  final bankOf = <String, String>{};
  if (from != null) {
    final reads = await (db.select(
      db.pendingCaptures,
    )..where((p) => p.savedAs.isIn([for (final paid in open) paid.id]))).get();
    for (final read in reads) {
      bankOf[read.savedAs!] = _sourceOf(read.app, read.sender);
    }
  }
  int score(Txn paid) =>
      (payee != null && shopKey(paid.merchant) == payee ? 2 : 0) +
      (from != null && bankOf[paid.id] == from ? 1 : 0);
  return open.reduce((best, paid) {
    final (a, b) = (score(best), score(paid));
    if (a != b) return b > a ? paid : best;
    // Oldest first, so a tie goes to the newer.
    return paid;
  });
}

/// How long before its payment money back for it can already be read: a
/// bank's reversal can come in before the payment's own message.
const _backBefore = Duration(hours: 1);

/// Money back read just before [payment] (saved in [categoryId] at [at])
/// that went in Refund/cashback for want of the payment, moved into the
/// payment's category as money back, so the two cancel.
Future<void> _cancelEarlierBack(
  AppDatabase db,
  TxnRepository txns,
  SmsTxn payment,
  DateTime at,
  String categoryId,
) async {
  if (payment.type != TxnType.debit || !isSpendCategory(categoryId)) return;
  final back =
      await (db.select(db.txns)
            ..where(
              (t) =>
                  t.deletedAt.isNull() &
                  t.type.equalsValue(TxnType.credit) &
                  t.source.equalsValue(TxnSource.sms) &
                  t.categoryId.equals('refund') &
                  t.amountPaise.equals(payment.amountPaise) &
                  t.occurredAt.isBetweenValues(at.subtract(_backBefore), at),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
            ..limit(1))
          .getSingleOrNull();
  if (back == null) return;
  await txns.update(
    back.id,
    amountPaise: back.amountPaise,
    type: back.type,
    categoryId: categoryId,
    occurredAt: back.occurredAt,
    merchant: back.merchant ?? payment.payee,
    tag: null,
    payeeIsPerson: back.payeeIsPerson ?? payment.payeeIsPerson,
  );
}

/// What Penny did with a notification she read. [unread]: neither her rules
/// nor, for now, her AI could read it; it's read again later.
enum CaptureOutcome { waiting, saved, letGo, unread }

/// One notification Penny read, and what she did with it. [what] says what
/// it was, like "−₹250 · Swiggy", or why it was let go, like "an OTP".
/// [key] tells it apart from others without keeping its text. [sender] is
/// who sent an SMS; [categoryId] is where a payment went, or would go.
typedef CaptureRead = ({
  String key,
  String app,
  String? sender,
  DateTime at,
  CaptureOutcome outcome,
  String what,
  SmsTxn? sms,
  String? categoryId,
  String? entryId,
});

/// A let-go notification's key: a fingerprint, never its text.
String _letGoKey(Capture capture) => sha256
    .convert(utf8.encode('penny-let-go|${capture.app}|${capture.text}'))
    .toString();

/// Takes everything waiting in [source]. Under [CaptureMode.save] every
/// payment is saved straight away, in the category of the last entry to or
/// from the same name ([yourCategoryOf]), else its guessed one, else
/// [fallbackCategoryOf], unless it's one already read from somewhere else
/// ([repeatOf]). Under [CaptureMode.check] each is held to be checked. One
/// that's already an entry, like one typed by hand that day
/// ([sameEntryOf]), is never saved or held again. Anything that isn't a
/// payment is let go.
///
/// One from a bank, a wallet or a payment app that says money moved, but
/// that the rules can't read, goes to [ai] with its names hidden
/// ([readWithAi]). When the AI can't answer now, it's kept to be read again
/// next time, with the ones already kept.
///
/// Returns what Penny did with each, leaving out payments she had already
/// met.
Future<List<CaptureRead>> takeCaptures({
  required CaptureSource source,
  required AppDatabase db,
  required TxnRepository txns,
  required CaptureRepository captures,
  required CaptureMode mode,
  required DateTime now,
  AiClient? ai,
  bool retryUnread = true,
}) async {
  final waiting = await source.peek();
  final reads = <CaptureRead>[];
  final asking = ai != null && ai.isSetUp ? ai : null;
  final prefs = PrefsRepository(db);
  final earlier = asking == null
      ? const <UnreadCapture>[]
      : await prefs.unread();
  final again = retryUnread ? earlier : const <UnreadCapture>[];
  // Ones not asked about again this time are kept as they were.
  final stillUnread = <String, UnreadCapture>{
    if (!retryUnread)
      for (final capture in earlier) _letGoKey(capture): capture,
  };
  for (final capture in [...again, ...waiting.captures]) {
    try {
      var (:payment, :letGo) = explainCapture(capture);
      final sender = capture.app == 'sms' ? capture.title.trim() : null;
      CaptureRead read(
        CaptureOutcome outcome,
        String what, {
        String? key,
        DateTime? at,
        SmsTxn? sms,
        String? categoryId,
        String? entryId,
      }) => (
        key: key ?? _letGoKey(capture),
        app: capture.app,
        sender: sender,
        at: at ?? capture.at,
        outcome: outcome,
        what: what,
        sms: sms,
        categoryId: categoryId,
        entryId: entryId,
      );

      if (payment == null &&
          asking != null &&
          letGo == _letGo[IgnoreReason.unreadable] &&
          _moneyMoved.hasMatch(_textOf(capture))) {
        try {
          (:payment, :letGo) = await readWithAi(asking, capture);
          // What's logged says what happened, never what was read.
          debugPrint(
            payment != null
                ? 'Penny: her AI read a payment'
                : 'Penny: her AI found no payment',
          );
        } on AiException catch (error) {
          debugPrint("Penny: her AI couldn't answer (${error.failure.name})");
          stillUnread[_letGoKey(capture)] = capture;
          reads.add(read(CaptureOutcome.unread, 'Penny will try again'));
          continue;
        }
      }
      // A payment still to come is kept for Home's Coming up card.
      if (payment == null && letGo == _letGo[IgnoreReason.upcoming]) {
        if (parseUpcoming(_textOf(capture), now: capture.at)
            case final coming?) {
          await UpcomingRepository(db).keep(coming);
          letGo = 'coming up on ${DateFormat('d MMM').format(coming.dueOn)}';
        }
      }
      if (payment == null) {
        reads.add(read(CaptureOutcome.letGo, letGo ?? 'no payment in it'));
        continue;
      }
      if (await captures.isKnown(payment.dedupeKey)) continue;
      final at = occurredAtOf(payment, capture.at);
      // Money back for a payment cancels it: it goes in that payment's
      // category, under its name.
      var back = '';
      if (await reversedPaymentOf(
            db,
            payment,
            at,
            _textOf(capture),
            from: _sourceOf(capture.app, sender),
          )
          case final paid?) {
        payment = payment.backFor(
          payee: paid.merchant,
          categoryId: paid.categoryId,
          payeeIsPerson: paid.payeeIsPerson ?? false,
        );
        back = ' (money back)';
      } else if (await yourCategoryOf(db, payment) case final yours?) {
        // A name met before goes where the user put it.
        payment = payment.withCategory(yours);
      }
      // A payment already among the entries, or already read from
      // somewhere else, is kept as a copy of that one: known if shown
      // again, never saved or waiting twice, and never matched to another.
      final same =
          (mode == CaptureMode.save
              ? await repeatOf(
                  db,
                  payment,
                  at,
                  app: capture.app,
                  sender: sender,
                )
              : null) ??
          await sameEntryOf(db, payment, at, app: capture.app, sender: sender);
      if (same != null) {
        if (same.entryId case final entryId?) {
          await captures.recordSaved(
            payment,
            app: capture.app,
            at: at,
            entryId: entryId,
            sender: sender,
          );
        }
        reads.add(
          read(CaptureOutcome.letGo, same.what, key: payment.dedupeKey, at: at),
        );
        continue;
      }
      if (mode == CaptureMode.save) {
        final categoryId =
            payment.suggestedCategoryId ?? fallbackCategoryOf(payment);
        final entryId = await txns.add(
          amountPaise: payment.amountPaise,
          type: payment.type,
          categoryId: categoryId,
          occurredAt: at,
          merchant: payment.payee,
          source: TxnSource.sms,
          dedupeKey: payment.dedupeKey,
          payeeIsPerson: payment.payeeIsPerson,
        );
        await _cancelEarlierBack(db, txns, payment, at, categoryId);
        await captures.recordSaved(
          payment,
          app: capture.app,
          at: at,
          entryId: entryId,
          sender: sender,
        );
        reads.add(
          read(
            CaptureOutcome.saved,
            '${whatOf(payment)}$back',
            key: payment.dedupeKey,
            at: at,
            sms: payment,
            categoryId: categoryId,
            entryId: entryId,
          ),
        );
        continue;
      }
      await captures.hold(
        payment,
        app: capture.app,
        at: at,
        sender: sender,
        lookalike: await lookalikeOf(db, payment, at),
      );
      reads.add(
        read(
          CaptureOutcome.waiting,
          '${whatOf(payment)}$back',
          key: payment.dedupeKey,
          at: at,
          sms: payment,
          categoryId: payment.suggestedCategoryId,
        ),
      );
    } catch (error) {
      // One message that can't be read never holds up the rest. What's
      // logged says what went wrong, never what was read.
      debugPrint("Penny: couldn't read one (${error.runtimeType})");
      reads.add((
        key: _letGoKey(capture),
        app: capture.app,
        sender: capture.app == 'sms' ? capture.title.trim() : null,
        at: capture.at,
        outcome: CaptureOutcome.letGo,
        what: "Penny couldn't read this one",
        sms: null,
        categoryId: null,
        entryId: null,
      ));
    }
  }
  // A skipped one is let go after two months, as is the record of a saved
  // one.
  await captures.forgetOld(now.subtract(const Duration(days: 60)));
  if (asking != null) await prefs.setUnread([...stillUnread.values]);
  if (waiting.count > 0) await source.drop(waiting.count);
  return reads;
}

/// What Penny's notification says about the payments she just read. Null
/// when there's nothing to say: she only let things go.
PennyNotice? noticeFor(List<CaptureRead> reads) {
  final payments = [
    for (final read in reads)
      if (read.outcome case CaptureOutcome.saved || CaptureOutcome.waiting)
        read,
  ];
  final unread = reads.where((r) => r.outcome == CaptureOutcome.unread).length;
  if (payments.isEmpty) {
    if (unread == 0) return null;
    return (
      title: unread == 1
          ? "Penny couldn't read a payment message"
          : "Penny couldn't read $unread payment messages",
      text: "She'll try again next time you open her. It's on Home.",
      lines: const [],
    );
  }
  if (payments case [final one] when unread == 0) {
    final category = _categoryOf(one);
    return one.outcome == CaptureOutcome.saved
        ? (
            title: 'Penny saved ${one.what}',
            text: [
              '$category.',
              'Open Penny to change it or undo it.',
            ].join(' '),
            lines: const [],
          )
        : (
            title: 'Penny read ${one.what}',
            text: category == null
                ? "It's waiting on Home: pick a category, then add it."
                : "$category? It's waiting on Home: add it or skip it.",
            lines: const [],
          );
  }
  final saved = payments.where((p) => p.outcome == CaptureOutcome.saved);
  final held = payments.length - saved.length;
  return (
    title: payments.length == 1
        ? 'Penny read 1 payment'
        : 'Penny read ${payments.length} payments',
    text: [
      if (held > 0) '$held waiting on Home',
      if (saved.isNotEmpty) '${saved.length} saved',
      if (unread > 0) "$unread she couldn't read yet",
    ].join(', '),
    lines: [
      for (final read in payments.take(5))
        [read.what, ?_categoryOf(read)].join(' · '),
    ],
  );
}

/// Writes [reads] into "What Penny read".
Future<void> noteReads(PrefsRepository prefs, List<CaptureRead> reads) =>
    prefs.noteCaptures([
      for (final read in reads)
        (
          key: read.key,
          app: read.app,
          at: read.at,
          outcome: read.outcome.name,
          what: read.what,
        ),
    ]);

/// Takes payments from notifications into the user's own money as Penny
/// opens, comes back, or hears of more, and writes down what she read.
/// Never into the demo's: while it's on, they wait.
class CaptureIntake {
  CaptureIntake(this._ref);

  final Ref _ref;
  var _busy = false;
  var _again = false;
  Completer<void>? _running;

  /// What Penny did with each. A call while one is running makes it go
  /// round once more instead, and waits for it.
  Future<List<CaptureRead>> take() async {
    if (_busy) {
      _again = true;
      await _running?.future;
      return const [];
    }
    _busy = true;
    final running = _running = Completer<void>();
    final reads = <CaptureRead>[];
    try {
      do {
        _again = false;
        if (_ref.read(demoModeProvider)) break;
        final db = _ref.read(appDatabaseProvider);
        final round = await takeCaptures(
          source: _ref.read(notificationInboxProvider),
          db: db,
          txns: _ref.read(txnRepositoryProvider),
          captures: _ref.read(captureRepositoryProvider),
          mode: _ref.read(captureModeProvider),
          now: DateTime.now(),
          ai: _ref.read(aiClientProvider),
        );
        await noteReads(PrefsRepository(db), round);
        reads.addAll(round);
      } while (_again);
    } finally {
      _busy = false;
      running.complete();
    }
    return reads;
  }
}

/// How many days back from [today] the same day [months] months ago is: 30
/// on 11 Dec for one month, 61 on 11 Dec for two.
int lookBackDays(int months, DateTime today) {
  final day = dayStart(today);
  final since = DateTime(day.year, day.month - months, day.day);
  // Rounded, so a clock change on the way doesn't lose a day.
  return (day.difference(since).inHours / 24).round();
}

/// Reads the bank SMS of the last [days] days with the same rules as new
/// ones, a batch at a time, each read before the next is asked for so the
/// waiting file never overflows. How many money SMS Penny found that she
/// hadn't read before.
Future<int> lookBackAtSms({
  required NotificationInbox inbox,
  required CaptureIntake intake,
  required int days,
}) async {
  var found = 0;
  DateTime? after;
  for (var round = 0; round < 50; round++) {
    final batch = await inbox.lookBack(days: days, after: after);
    found += batch.kept;
    if (batch.kept > 0) await intake.take();
    if (batch.done || batch.until == null) break;
    after = batch.until;
  }
  return found;
}

final captureIntakeProvider = Provider<CaptureIntake>(CaptureIntake.new);

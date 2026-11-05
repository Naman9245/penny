import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/capture_repository.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/prefs_repository.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/money_kinds.dart';
import 'package:penny/services/notification_inbox.dart';
import 'package:penny/services/sms_parser.dart';

// Payments read from notifications, all on the phone: which notifications
// are payments, which of those are already here, what's done with the rest,
// and what Penny tells the user about it.

/// Why a notification isn't a payment, in words for "What Penny read".
const _letGo = {
  IgnoreReason.otp: 'an OTP',
  IgnoreReason.request: 'a request for money',
  IgnoreReason.upcoming: 'a payment not made yet',
  IgnoreReason.failed: 'a failed payment',
  IgnoreReason.offer: 'an offer',
  IgnoreReason.ownTransfer: 'a move between your own accounts',
  IgnoreReason.receipt: 'a receipt for a payment already made',
  IgnoreReason.balance: 'only a balance',
  IgnoreReason.unreadable: 'no payment in it',
};

/// [capture] read the way a shared SMS is: the payment in it, or why it was
/// let go. From the SMS app it counts only when it's from a bank, a wallet
/// or an investment: a sender code or a money brand's name, or a message
/// naming an account, card or wallet. So a friend's text about money isn't
/// taken.
({SmsTxn? payment, String? letGo}) explainCapture(Capture capture) {
  final fromSms = capture.app == 'sms';
  if (fromSms &&
      !isMoneySender(capture.title) &&
      !mentionsMoneyPlace(capture.text)) {
    return (payment: null, letGo: 'not from a bank');
  }
  // A payment app puts half of it in the title: "₹250 paid to Swiggy".
  final text = fromSms || capture.title.trim().isEmpty
      ? capture.text
      : '${capture.title}\n${capture.text}';
  return switch (parseSms(text, now: capture.at)) {
    final SmsTxn payment => (payment: payment, letGo: null),
    SmsIgnored(:final reason) => (payment: null, letGo: _letGo[reason]),
  };
}

/// [capture]'s payment, or null when it isn't one.
SmsTxn? readCapture(Capture capture) => explainCapture(capture).payment;

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

/// Its guessed category, like "🍔 Food", or null without one.
String? _categoryOf(SmsTxn sms) {
  final id = sms.suggestedCategoryId;
  if (id == null) return null;
  return '${categoryById(id).emoji} ${kindLabel(sms.type, id)}';
}

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

/// What Penny did with a notification she read.
enum CaptureOutcome { waiting, saved, letGo }

/// One notification Penny read, and what she did with it. [what] says what
/// it was, like "−₹250 · Swiggy", or why it was let go, like "an OTP".
/// [key] tells it apart from others without keeping its text.
typedef CaptureRead = ({
  String key,
  String app,
  DateTime at,
  CaptureOutcome outcome,
  String what,
  SmsTxn? sms,
  String? entryId,
});

/// A let-go notification's key: a fingerprint, never its text.
String _letGoKey(Capture capture) => sha256
    .convert(utf8.encode('penny-let-go|${capture.app}|${capture.text}'))
    .toString();

/// Takes everything waiting in [source]. Under [CaptureMode.save] a payment
/// is saved straight away when it's clear-cut: nothing it may already be,
/// and a category to go in. Every other payment is held to be checked, and
/// anything that isn't one is let go. Returns what Penny did with each,
/// leaving out payments she had already met.
Future<List<CaptureRead>> takeCaptures({
  required CaptureSource source,
  required AppDatabase db,
  required TxnRepository txns,
  required CaptureRepository captures,
  required CaptureMode mode,
  required DateTime now,
}) async {
  final waiting = await source.peek();
  final reads = <CaptureRead>[];
  for (final capture in waiting.captures) {
    final (:payment, :letGo) = explainCapture(capture);
    if (payment == null) {
      reads.add((
        key: _letGoKey(capture),
        app: capture.app,
        at: capture.at,
        outcome: CaptureOutcome.letGo,
        what: letGo ?? 'no payment in it',
        sms: null,
        entryId: null,
      ));
      continue;
    }
    if (await captures.isKnown(payment.dedupeKey)) continue;
    final at = occurredAtOf(payment, capture.at);
    final lookalike = await lookalikeOf(db, payment, at);
    final categoryId = payment.suggestedCategoryId;
    String? entryId;
    if (mode == CaptureMode.save && lookalike == null && categoryId != null) {
      entryId = await txns.add(
        amountPaise: payment.amountPaise,
        type: payment.type,
        categoryId: categoryId,
        occurredAt: at,
        merchant: payment.payee,
        source: TxnSource.sms,
        dedupeKey: payment.dedupeKey,
        payeeIsPerson: payment.payeeIsPerson,
      );
    } else {
      await captures.hold(
        payment,
        app: capture.app,
        at: at,
        lookalike: lookalike,
      );
    }
    reads.add((
      key: payment.dedupeKey,
      app: capture.app,
      at: at,
      outcome: entryId != null ? CaptureOutcome.saved : CaptureOutcome.waiting,
      what: whatOf(payment),
      sms: payment,
      entryId: entryId,
    ));
  }
  // A skipped one is let go after two months.
  await captures.forgetSkipped(now.subtract(const Duration(days: 60)));
  if (waiting.count > 0) await source.drop(waiting.count);
  return reads;
}

/// What Penny's notification says about the payments she just read. Null
/// when there's nothing to say: she only let things go.
PennyNotice? noticeFor(List<CaptureRead> reads) {
  final payments = [
    for (final read in reads)
      if (read.outcome != CaptureOutcome.letGo) read,
  ];
  if (payments.isEmpty) return null;
  if (payments case [final one]) {
    final category = _categoryOf(one.sms!);
    return one.outcome == CaptureOutcome.saved
        ? (
            title: 'Penny saved ${one.what}',
            text: '$category. Open Penny to change it or undo it.',
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
    title: 'Penny read ${payments.length} payments',
    text: [
      if (held > 0) '$held waiting on Home',
      if (saved.isNotEmpty) '${saved.length} saved',
    ].join(', '),
    lines: [
      for (final read in payments.take(5))
        [read.what, ?_categoryOf(read.sms!)].join(' · '),
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

  /// What Penny did with each. A call while one is running makes it go
  /// round once more instead.
  Future<List<CaptureRead>> take() async {
    if (_busy) {
      _again = true;
      return const [];
    }
    _busy = true;
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
        );
        await noteReads(PrefsRepository(db), round);
        reads.addAll(round);
      } while (_again);
    } finally {
      _busy = false;
    }
    return reads;
  }
}

final captureIntakeProvider = Provider<CaptureIntake>(CaptureIntake.new);

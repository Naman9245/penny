import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/capture_repository.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/money_kinds.dart';
import 'package:penny/services/notification_inbox.dart';
import 'package:penny/services/sms_parser.dart';

// Payments read from notifications, all on the phone: which notifications
// are payments, which of those are already here, and what's done with the
// rest.

/// A bank's sender ID, as a Messages app shows it: "AX-HDFCBK",
/// "JD-ICICIT-S".
final _senderId = RegExp(
  r'^[A-Z]{2}-[A-Z0-9]{3,9}(?:-[A-Z])?$',
  caseSensitive: false,
);

/// [capture] read as a payment, the way a shared SMS is, or null when it
/// isn't one. From the SMS app it counts only when it's from a bank: a
/// bank's sender ID, or a message naming an account or card. So a friend's
/// text about money isn't taken.
SmsTxn? readCapture(Capture capture) {
  final fromSms = capture.app == 'sms';
  if (fromSms &&
      !_senderId.hasMatch(capture.title.trim()) &&
      !mentionsAccount(capture.text)) {
    return null;
  }
  // A payment app puts half of it in the title: "₹250 paid to Swiggy".
  final text = fromSms || capture.title.trim().isEmpty
      ? capture.text
      : '${capture.title}\n${capture.text}';
  final read = parseSms(text, now: capture.at);
  return read is SmsTxn ? read : null;
}

/// When [sms] happened: the time it gives, or else when its notification
/// came, on the day it gives.
DateTime occurredAtOf(SmsTxn sms, DateTime notified) {
  final at = sms.occurredAt;
  if (at == null) return notified;
  if (sms.hasTime) return at;
  return dayStart(at) == dayStart(notified) ? notified : onDay(at, notified);
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

/// A payment saved straight from a notification, with what it was read as,
/// so an Undo can hold it to be checked instead.
typedef SavedCapture = ({String id, SmsTxn sms, String app, DateTime at});

/// Takes everything waiting in [source]. Under [CaptureMode.save] a payment
/// is saved straight away when it's clear-cut: nothing it may already be,
/// and a category to go in. Every other payment is held to be checked, and
/// anything that isn't one is let go. Returns what was saved.
Future<List<SavedCapture>> takeCaptures({
  required CaptureSource source,
  required AppDatabase db,
  required TxnRepository txns,
  required CaptureRepository captures,
  required CaptureMode mode,
  required DateTime now,
}) async {
  final waiting = await source.peek();
  final saved = <SavedCapture>[];
  for (final capture in waiting.captures) {
    final sms = readCapture(capture);
    if (sms == null || await captures.isKnown(sms.dedupeKey)) continue;
    final at = occurredAtOf(sms, capture.at);
    final lookalike = await lookalikeOf(db, sms, at);
    final categoryId = sms.suggestedCategoryId;
    if (mode == CaptureMode.save && lookalike == null && categoryId != null) {
      final id = await txns.add(
        amountPaise: sms.amountPaise,
        type: sms.type,
        categoryId: categoryId,
        occurredAt: at,
        merchant: sms.payee,
        source: TxnSource.sms,
        dedupeKey: sms.dedupeKey,
        payeeIsPerson: sms.payeeIsPerson,
      );
      saved.add((id: id, sms: sms, app: capture.app, at: at));
    } else {
      await captures.hold(sms, app: capture.app, at: at, lookalike: lookalike);
    }
  }
  // A skipped one is let go after two months.
  await captures.forgetSkipped(now.subtract(const Duration(days: 60)));
  if (waiting.count > 0) await source.drop(waiting.count);
  return saved;
}

/// Takes payments from notifications into the user's own money as Penny
/// opens, comes back, or hears of more. Never into the demo's: while it's
/// on, they wait.
class CaptureIntake {
  CaptureIntake(this._ref);

  final Ref _ref;
  var _busy = false;
  var _again = false;

  /// What was saved straight away. A call while one is running makes it go
  /// round once more instead.
  Future<List<SavedCapture>> take() async {
    if (_busy) {
      _again = true;
      return const [];
    }
    _busy = true;
    final saved = <SavedCapture>[];
    try {
      do {
        _again = false;
        if (_ref.read(demoModeProvider)) break;
        saved.addAll(
          await takeCaptures(
            source: _ref.read(notificationInboxProvider),
            db: _ref.read(appDatabaseProvider),
            txns: _ref.read(txnRepositoryProvider),
            captures: _ref.read(captureRepositoryProvider),
            mode: _ref.read(captureModeProvider),
            now: DateTime.now(),
          ),
        );
      } while (_again);
    } finally {
      _busy = false;
    }
    return saved;
  }
}

final captureIntakeProvider = Provider<CaptureIntake>(CaptureIntake.new);

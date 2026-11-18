import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/sms_parser.dart';

// Moves between your own accounts: money from the bank into a wallet like
// PayZapp, or back. Each move comes as two messages a minute or so apart,
// the wallet's ("Rs.2000 deducted from PayZapp Wallet") and the bank's
// ("credited … from VPA *3510@pzw"), and neither is money in or out.

/// How far apart a move's two messages can come.
const moveWindow = Duration(minutes: 15);

/// How far back Home looks for moves already saved as two entries.
const pastMovesLookBack = Duration(days: 90);

/// A wallet's UPI ID, whole or masked: "9876543210@pzw", "*3510@pzw".
/// PayZapp's, for now.
final _walletId = RegExp(r'([\w.*-]+)@(pzw)\b', caseSensitive: false);

/// The same in a preview, which hides most of it: "*3••••@pzw".
final _walletIdShown = RegExp(r'@pzw\b', caseSensitive: false);

/// A wallet saying money went into or out of it: "PayZapp Wallet", "from
/// your wallet".
final _walletSays = RegExp(
  r'\bpay\s?zapp\s+wallet\b'
  r'|\b(?:from|to|in|into)\s+(?:your\s+)?(?:[a-z]+\s+){0,2}wallet\b',
  caseSensitive: false,
);

/// A bank account, as a bank's message names one. PayZapp's own messages
/// end "-HDFC Bank", so "bank" alone doesn't tell.
final _bankAccount = RegExp(
  r'\ba/?c\b|\baccount\b|\bacct\b',
  caseSensitive: false,
);

/// Half of a move between your own accounts, as one message tells it: the
/// wallet's side or the bank's, how much, which way for that account, and
/// for the bank's, the wallet's UPI ID ([walletHandleOf]).
typedef MoveHalf = ({
  MoveSide side,
  int amountPaise,
  TxnType type,
  String? walletHandle,
});

/// A fingerprint of the wallet UPI ID in [text], the same for
/// "9876543210@pzw" and "*3210@pzw": its last four characters and the
/// wallet, never the ID. Null without one.
String? walletHandleOf(String text) {
  final match = _walletId.firstMatch(text);
  if (match == null) return null;
  final local = match.group(1)!.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  if (local.length < 4) return null;
  final tail = local.substring(local.length - 4).toLowerCase();
  final wallet = match.group(2)!.toLowerCase();
  return sha256.convert(utf8.encode('penny-wallet|$tail@$wallet')).toString();
}

/// [parse] of [text], read from [app], as half of a move between your own
/// accounts. The wallet's side says money went into or out of the wallet
/// with no shop named, like "Rs.2000 deducted from PayZapp Wallet"; the
/// bank's names a wallet's UPI ID, like "credited … from VPA *3510@pzw".
/// Null for anything else, like paying a shop from the wallet.
MoveHalf? moveHalfOf(String app, String text, SmsParse parse) {
  final handle = walletHandleOf(text);
  final wallet = app == 'payzapp' || _walletSays.hasMatch(text);
  return switch (parse) {
    SmsTxn(payee: null, :final amountPaise, :final type)
        when wallet && handle == null =>
      (
        side: MoveSide.wallet,
        amountPaise: amountPaise,
        type: type,
        walletHandle: null,
      ),
    SmsTxn(:final amountPaise, :final type) when handle != null && !wallet => (
      side: MoveSide.bank,
      amountPaise: amountPaise,
      type: type,
      walletHandle: handle,
    ),
    // Penny's rules already know it's one, like a wallet load.
    SmsIgnored(
      reason: IgnoreReason.ownTransfer,
      :final amountPaise?,
      :final type?,
    ) =>
      app != 'payzapp' && _bankAccount.hasMatch(text)
          ? (
              side: MoveSide.bank,
              amountPaise: amountPaise,
              type: type,
              walletHandle: handle,
            )
          : (
              side: MoveSide.wallet,
              amountPaise: amountPaise,
              type: type,
              walletHandle: null,
            ),
    _ => null,
  };
}

/// Which side of a move [read] was, by what it kept: where it came from and
/// its preview, whose words survive though its numbers are hidden. Null
/// when it could be neither.
MoveSide? sideOfRead(PendingCapture read) {
  final wallet = read.app == 'payzapp' || _walletSays.hasMatch(read.preview);
  if (wallet && read.payee == null && read.walletHandle == null) {
    return MoveSide.wallet;
  }
  if (!wallet &&
      (read.walletHandle != null || _walletIdShown.hasMatch(read.preview))) {
    return MoveSide.bank;
  }
  return null;
}

TxnType _otherWay(TxnType type) =>
    type == TxnType.debit ? TxnType.credit : TxnType.debit;

/// What Penny did with half of a move: [removedEntry] is an entry taken out
/// because the message it came from was the other half. [what] says it for
/// "What Penny read".
typedef MoveTaken = ({String what, String? removedEntry});

const _aMove = 'a move between your own accounts';

/// Takes [half] of a move, read at [at] as [key]. When its other half was
/// read already, both are kept as one move: an entry saved from the other
/// is taken out, and one waiting on Home is skipped. When the wallet's UPI
/// ID is one seen in a move before, it's a move alone. When Penny's rules
/// already knew it was one ([known]), it's kept for its other half to find.
/// Null otherwise: it's read as a payment.
Future<MoveTaken?> takeMove(
  AppDatabase db,
  TxnRepository txns, {
  required MoveHalf half,
  required String key,
  required DateTime at,
  required DateTime now,
  bool known = false,
}) => db.transaction(() async {
  if (await _moveOf(db, key) != null) return (what: _aMove, removedEntry: null);
  final other = _otherWay(half.type);

  final reads = [
    for (final read
        in await (db.select(db.pendingCaptures)..where(
              (p) =>
                  p.dedupeKey.equals(key).not() &
                  p.amountPaise.equals(half.amountPaise) &
                  p.type.equalsValue(other) &
                  p.occurredAt.isBetweenValues(
                    at.subtract(moveWindow),
                    at.add(moveWindow),
                  ),
            ))
            .get())
      if (sideOfRead(read) case final side? when side != half.side)
        if (await _moveOf(db, read.dedupeKey) == null) read,
  ];
  final kept =
      await (db.select(db.ownMoves)..where(
            (m) =>
                m.messageKey.equals(key).not() &
                m.pairedWith.isNull() &
                m.amountPaise.equals(half.amountPaise) &
                m.type.equalsValue(other) &
                m.side.equalsValue(half.side).not() &
                m.occurredAt.isBetweenValues(
                  at.subtract(moveWindow),
                  at.add(moveWindow),
                ),
          ))
          .get();
  Duration apart(DateTime when) => when.difference(at).abs();
  reads.sort((a, b) => apart(a.occurredAt).compareTo(apart(b.occurredAt)));
  final halves = [...kept]
    ..sort((a, b) => apart(a.occurredAt).compareTo(apart(b.occurredAt)));
  final read = reads.firstOrNull;
  final move = halves.firstOrNull;

  Future<void> keep(String? pairedWith, {String? handle}) => db
      .into(db.ownMoves)
      .insertOnConflictUpdate(
        OwnMovesCompanion.insert(
          messageKey: key,
          side: half.side,
          amountPaise: half.amountPaise,
          type: half.type,
          occurredAt: at,
          walletHandle: Value(half.walletHandle ?? handle),
          pairedWith: Value(pairedWith),
          readAt: now,
        ),
      );

  final readFirst =
      read != null &&
      (move == null || apart(read.occurredAt) <= apart(move.occurredAt));
  if (readFirst) {
    String? removed;
    if (read.savedAs case final entryId?) {
      if (await txns.findById(entryId) != null) {
        await txns.softDelete(entryId);
        removed = entryId;
      }
    } else if (read.skippedAt == null) {
      await (db.update(db.pendingCaptures)
            ..where((p) => p.dedupeKey.equals(read.dedupeKey)))
          .write(PendingCapturesCompanion(skippedAt: Value(now)));
    }
    await db
        .into(db.ownMoves)
        .insertOnConflictUpdate(
          OwnMovesCompanion.insert(
            messageKey: read.dedupeKey,
            side: sideOfRead(read)!,
            amountPaise: read.amountPaise,
            type: read.type,
            occurredAt: read.occurredAt,
            walletHandle: Value(read.walletHandle),
            pairedWith: Value(key),
            removedEntry: Value(removed),
            readAt: now,
          ),
        );
    await keep(read.dedupeKey, handle: read.walletHandle);
    return (
      what: removed == null
          ? _aMove
          : '$_aMove, so the ${_signed(read.type, read.amountPaise)} '
                'saved from the other half was taken out',
      removedEntry: removed,
    );
  }
  if (move != null) {
    await (db.update(db.ownMoves)
          ..where((m) => m.messageKey.equals(move.messageKey)))
        .write(OwnMovesCompanion(pairedWith: Value(key)));
    await keep(move.messageKey, handle: move.walletHandle);
    return (what: _aMove, removedEntry: null);
  }
  if (half.side == MoveSide.bank && await isYourWallet(db, half.walletHandle)) {
    await keep(null);
    return (what: '$_aMove, to or from a wallet of yours', removedEntry: null);
  }
  if (known) {
    await keep(null);
    return (what: _aMove, removedEntry: null);
  }
  return null;
});

String _signed(TxnType type, int paise) =>
    '${type == TxnType.debit ? '−' : '+'}${formatPaise(paise)}';

Future<OwnMove?> _moveOf(AppDatabase db, String key) => (db.select(
  db.ownMoves,
)..where((m) => m.messageKey.equals(key))).getSingleOrNull();

/// Whether [key] is a message already kept as half of a move.
Future<bool> isOwnMove(AppDatabase db, String key) async =>
    await _moveOf(db, key) != null;

/// Whether [handle] is a wallet's UPI ID seen in a move between your own
/// accounts before.
Future<bool> isYourWallet(AppDatabase db, String? handle) async {
  if (handle == null) return false;
  final seen =
      await (db.select(db.ownMoves)
            ..where((m) => m.walletHandle.equals(handle))
            ..limit(1))
          .getSingleOrNull();
  return seen != null;
}

/// Takes [entryId] out as your own money moving, as the user says it was,
/// with its other half when Penny read one, and remembers the wallet behind
/// it. Returns the entries taken out, for [putBackMove].
Future<List<String>> markOwnMove(
  AppDatabase db,
  TxnRepository txns,
  String entryId, {
  required DateTime now,
}) => db.transaction(() async {
  final entry = await txns.findById(entryId);
  if (entry == null) return const <String>[];
  await txns.softDelete(entryId);
  final read = await (db.select(
    db.pendingCaptures,
  )..where((p) => p.savedAs.equals(entryId))).getSingleOrNull();
  if (read == null) return [entryId];
  final side = sideOfRead(read) ?? MoveSide.bank;
  final at = read.occurredAt;
  final candidates =
      await (db.select(db.pendingCaptures)..where(
            (p) =>
                p.dedupeKey.equals(read.dedupeKey).not() &
                p.savedAs.isNotNull() &
                p.amountPaise.equals(read.amountPaise) &
                p.type.equalsValue(_otherWay(read.type)) &
                p.occurredAt.isBetweenValues(
                  at.subtract(moveWindow),
                  at.add(moveWindow),
                ),
          ))
          .get();
  PendingCapture? other;
  for (final candidate in candidates) {
    if (sideOfRead(candidate) case final s? when s != side) {
      if (await txns.findById(candidate.savedAs!) != null) {
        other = candidate;
        break;
      }
    }
  }
  final removed = [entryId];
  if (other != null) {
    await txns.softDelete(other.savedAs!);
    removed.add(other.savedAs!);
  }
  await _keepRead(db, read, side, pairedWith: other?.dedupeKey, now: now);
  if (other != null) {
    await _keepRead(
      db,
      other,
      sideOfRead(other)!,
      pairedWith: read.dedupeKey,
      now: now,
    );
  }
  return removed;
});

Future<void> _keepRead(
  AppDatabase db,
  PendingCapture read,
  MoveSide side, {
  required String? pairedWith,
  required DateTime now,
}) => db
    .into(db.ownMoves)
    .insertOnConflictUpdate(
      OwnMovesCompanion.insert(
        messageKey: read.dedupeKey,
        side: side,
        amountPaise: read.amountPaise,
        type: read.type,
        occurredAt: read.occurredAt,
        walletHandle: Value(read.walletHandle),
        pairedWith: Value(pairedWith),
        removedEntry: Value(read.savedAs),
        readAt: now,
      ),
    );

/// Undoes [markOwnMove] or [removePastMove]: brings back [entryIds] and
/// forgets them as a move.
Future<void> putBackMove(
  AppDatabase db,
  TxnRepository txns,
  List<String> entryIds,
) => db.transaction(() async {
  for (final id in entryIds) {
    await txns.restore(id);
  }
  await (db.delete(
    db.ownMoves,
  )..where((m) => m.removedEntry.isIn(entryIds))).go();
});

/// A move between your own accounts that Penny saved as two entries before
/// she knew to pair them: the wallet's side and the bank's.
typedef PastMove = ({
  String key,
  String walletEntry,
  String bankEntry,
  int amountPaise,
  DateTime at,

  /// From the wallet to the bank; else from the bank into the wallet.
  bool toBank,
});

/// Moves already saved as two entries since [since], newest first: one
/// read from the wallet's message with no shop named, and one from the
/// bank's naming the wallet's UPI ID, the other way, for the same amount
/// within [moveWindow]. Each entry is in one at most.
Future<List<PastMove>> pastMovesOf(AppDatabase db, DateTime since) async {
  final rows =
      await (db.select(db.pendingCaptures).join([
            innerJoin(
              db.txns,
              db.txns.id.equalsExp(db.pendingCaptures.savedAs),
            ),
          ])..where(
            db.txns.deletedAt.isNull() &
                db.pendingCaptures.occurredAt.isBiggerOrEqualValue(since),
          ))
          .map((row) => row.readTable(db.pendingCaptures))
          .get();
  final wallet = [
    for (final row in rows)
      if (sideOfRead(row) == MoveSide.wallet) row,
  ]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  final bank = [
    for (final row in rows)
      if (sideOfRead(row) == MoveSide.bank) row,
  ];
  final used = <String>{};
  final moves = <PastMove>[];
  for (final out in wallet) {
    Duration apart(PendingCapture row) =>
        row.occurredAt.difference(out.occurredAt).abs();
    final matches = [
      for (final row in bank)
        if (!used.contains(row.dedupeKey) &&
            row.amountPaise == out.amountPaise &&
            row.type == _otherWay(out.type) &&
            apart(row) <= moveWindow)
          row,
    ]..sort((a, b) => apart(a).compareTo(apart(b)));
    final match = matches.firstOrNull;
    if (match == null) continue;
    used.add(match.dedupeKey);
    moves.add((
      key: '${out.dedupeKey}|${match.dedupeKey}',
      walletEntry: out.savedAs!,
      bankEntry: match.savedAs!,
      amountPaise: out.amountPaise,
      at: out.occurredAt,
      toBank: out.type == TxnType.debit,
    ));
  }
  return moves;
}

/// Takes [move] out, both entries, as your own money moving. Undo with
/// [putBackMove] and its two entries.
Future<void> removePastMove(
  AppDatabase db,
  TxnRepository txns,
  PastMove move, {
  required DateTime now,
}) => db.transaction(() async {
  final [walletKey, bankKey] = move.key.split('|');
  final reads = await (db.select(
    db.pendingCaptures,
  )..where((p) => p.dedupeKey.isIn([walletKey, bankKey]))).get();
  for (final read in reads) {
    if (read.savedAs case final id?) await txns.softDelete(id);
    await _keepRead(
      db,
      read,
      read.dedupeKey == walletKey ? MoveSide.wallet : MoveSide.bank,
      pairedWith: read.dedupeKey == walletKey ? bankKey : walletKey,
      now: now,
    );
  }
});

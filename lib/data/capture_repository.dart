import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/services/sms_parser.dart';

/// Payments read from notifications that wait to be checked, and the ones
/// skipped. They stay on this phone and are never synced.
class CaptureRepository {
  CaptureRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  $PendingCapturesTable get _rows => _db.pendingCaptures;

  /// The ones waiting, newest first. Skipped ones aren't among them.
  Stream<List<PendingCapture>> watchWaiting() {
    final query = _db.select(_rows)
      ..where((p) => p.skippedAt.isNull())
      ..orderBy([(p) => OrderingTerm.desc(p.occurredAt)]);
    return query.watch();
  }

  /// Whether Penny has met this one already: waiting, skipped, or added,
  /// even if that entry was deleted since.
  Future<bool> isKnown(String dedupeKey) async {
    final held = await (_db.select(
      _rows,
    )..where((p) => p.dedupeKey.equals(dedupeKey))).getSingleOrNull();
    if (held != null) return true;
    final entry =
        await (_db.select(_db.txns)
              ..where((t) => t.dedupeKey.equals(dedupeKey))
              ..limit(1))
            .getSingleOrNull();
    return entry != null;
  }

  /// Keeps [sms], read from a notification of [app] and dated [at], to be
  /// checked. [lookalike] names an entry it may already be.
  Future<void> hold(
    SmsTxn sms, {
    required String app,
    required DateTime at,
    String? lookalike,
  }) {
    return _db
        .into(_rows)
        .insertOnConflictUpdate(
          PendingCapturesCompanion.insert(
            dedupeKey: sms.dedupeKey,
            app: app,
            amountPaise: sms.amountPaise,
            type: sms.type,
            payee: Value(sms.payee),
            payeeIsPerson: sms.payeeIsPerson,
            occurredAt: at,
            suggestedCategoryId: Value(sms.suggestedCategoryId),
            preview: sms.preview.text,
            previewSpans: jsonEncode([
              for (final span in sms.preview.spans)
                [span.start, span.end, span.kind.name],
            ]),
            lookalike: Value(lookalike),
            capturedAt: _clock(),
          ),
        );
  }

  /// Puts [row] back to wait, as an Undo does: back in if it was removed,
  /// and no longer skipped. (An upsert leaves out empty fields, so the skip
  /// is cleared on its own.)
  Future<void> putBack(PendingCapture row) => _db.transaction(() async {
    await _db.into(_rows).insert(row, mode: InsertMode.insertOrIgnore);
    await (_db.update(_rows)..where((p) => p.dedupeKey.equals(row.dedupeKey)))
        .write(const PendingCapturesCompanion(skippedAt: Value(null)));
  });

  /// Hides it from Home. It stays known, so the same notification doesn't
  /// bring it back.
  Future<void> skip(String dedupeKey) =>
      (_db.update(_rows)..where((p) => p.dedupeKey.equals(dedupeKey))).write(
        PendingCapturesCompanion(skippedAt: Value(_clock())),
      );

  /// Gone, once its entry is added. The entry keeps it known.
  Future<void> remove(String dedupeKey) =>
      (_db.delete(_rows)..where((p) => p.dedupeKey.equals(dedupeKey))).go();

  /// Forgets ones skipped before [before].
  Future<void> forgetSkipped(DateTime before) => (_db.delete(
    _rows,
  )..where((p) => p.skippedAt.isSmallerThanValue(before))).go();

  /// [row] as the review of a read SMS takes it.
  static SmsTxn toSms(PendingCapture row) {
    final spans = (jsonDecode(row.previewSpans) as List<dynamic>)
        .cast<List<dynamic>>();
    return SmsTxn(
      amountPaise: row.amountPaise,
      type: row.type,
      payee: row.payee,
      payeeIsPerson: row.payeeIsPerson,
      occurredAt: row.occurredAt,
      hasTime: true,
      suggestedCategoryId: row.suggestedCategoryId,
      dedupeKey: row.dedupeKey,
      preview: SmsPreview(row.preview, [
        for (final [start as int, end as int, kind as String] in spans)
          SmsSpan(start, end, SpanKind.values.byName(kind)),
      ]),
    );
  }
}

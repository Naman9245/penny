import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/db/app_database.dart';

/// One notification in "What Penny read": what she did with it ("waiting",
/// "saved" or "letGo"), and what it was or why she let it go. [key] tells
/// it apart without keeping its text.
typedef CaptureLogEntry = ({
  String key,
  String app,
  DateTime at,
  String outcome,
  String what,
});

/// Small settings kept on this phone. The note to Penny is backed up too.
class PrefsRepository {
  PrefsRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  /// The note's name here; sync knows it as "note".
  static const noteName = 'penny_note';

  /// The longest note Penny takes.
  static const maxNoteLength = 200;

  /// The fixed bills skipped this month. Stays on this phone: sync only
  /// carries the note.
  static const skippedBillsName = 'skipped_bills';

  /// The fixed bills skipped in [month], by their keys. Skips from another
  /// month don't count.
  Stream<Set<String>> watchSkippedBills(DateTime month) {
    final query = _db.select(_db.prefs)
      ..where((p) => p.name.equals(skippedBillsName));
    return query.watchSingleOrNull().map(
      (pref) => _skipped(pref?.value, month),
    );
  }

  /// Hides the fixed bill [key] for the rest of [month].
  Future<void> skipBill(DateTime month, String key) async {
    final pref = await (_db.select(
      _db.prefs,
    )..where((p) => p.name.equals(skippedBillsName))).getSingleOrNull();
    final keys = {..._skipped(pref?.value, month), key};
    await _db
        .into(_db.prefs)
        .insertOnConflictUpdate(
          PrefsCompanion.insert(
            name: skippedBillsName,
            value: jsonEncode({
              'month': monthKey(month),
              'keys': keys.toList()..sort(),
            }),
            updatedAt: _clock(),
            dirty: const Value(false),
          ),
        );
  }

  /// The last notifications Penny read, for "What Penny read". Stays on this
  /// phone: sync only carries the note.
  static const captureLogName = 'capture_log';

  /// How many "What Penny read" keeps.
  static const captureLogLength = 20;

  /// The last notifications Penny read, newest first.
  Stream<List<CaptureLogEntry>> watchCaptureLog() {
    final query = _db.select(_db.prefs)
      ..where((p) => p.name.equals(captureLogName));
    return query.watchSingleOrNull().map((pref) => _log(pref?.value));
  }

  /// Puts [entries], oldest first, at the top of the log, leaving out any
  /// it already has, and keeps the last [captureLogLength].
  Future<void> noteCaptures(List<CaptureLogEntry> entries) async {
    if (entries.isEmpty) return;
    final pref = await (_db.select(
      _db.prefs,
    )..where((p) => p.name.equals(captureLogName))).getSingleOrNull();
    final old = _log(pref?.value);
    final seen = {for (final entry in old) entry.key};
    final fresh = [
      for (final entry in entries.reversed)
        if (seen.add(entry.key)) entry,
    ];
    if (fresh.isEmpty) return;
    await _db
        .into(_db.prefs)
        .insertOnConflictUpdate(
          PrefsCompanion.insert(
            name: captureLogName,
            value: jsonEncode([
              for (final entry in [...fresh, ...old].take(captureLogLength))
                {
                  'key': entry.key,
                  'app': entry.app,
                  'at': entry.at.millisecondsSinceEpoch,
                  'outcome': entry.outcome,
                  'what': entry.what,
                },
            ]),
            updatedAt: _clock(),
            dirty: const Value(false),
          ),
        );
  }

  static List<CaptureLogEntry> _log(String? value) {
    if (value == null) return const [];
    try {
      return [
        for (final item in jsonDecode(value) as List<dynamic>)
          if (item case {
            'key': final String key,
            'app': final String app,
            'at': final int at,
            'outcome': final String outcome,
            'what': final String what,
          })
            (
              key: key,
              app: app,
              at: DateTime.fromMillisecondsSinceEpoch(at),
              outcome: outcome,
              what: what,
            ),
      ];
    } on FormatException {
      return const [];
    }
  }

  static Set<String> _skipped(String? value, DateTime month) {
    if (value == null) return const {};
    try {
      final json = jsonDecode(value);
      if (json
          case {'month': final String saved, 'keys': final List<dynamic> keys}
          when saved == monthKey(month)) {
        return {for (final key in keys) ?(key is String ? key : null)};
      }
    } on FormatException {
      // Unreadable: nothing skipped.
    }
    return const {};
  }

  /// What the user told Penny about their life on My needs, if anything.
  Stream<String?> watchNote() {
    final query = _db.select(_db.prefs)..where((p) => p.name.equals(noteName));
    return query.watchSingleOrNull().map(
      (pref) => pref == null || pref.value.isEmpty ? null : pref.value,
    );
  }

  /// Keeps [note], trimmed and cut to [maxNoteLength]. Empty clears it,
  /// kept as an empty note so clearing reaches the account's copy too.
  Future<void> setNote(String? note) async {
    var text = note?.trim() ?? '';
    if (text.length > maxNoteLength) {
      text = text.substring(0, maxNoteLength).trim();
    }
    await _db
        .into(_db.prefs)
        .insertOnConflictUpdate(
          PrefsCompanion.insert(
            name: noteName,
            value: text,
            updatedAt: _clock(),
            dirty: const Value(true),
          ),
        );
  }
}

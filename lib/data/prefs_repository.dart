import 'package:drift/drift.dart';
import 'package:penny/data/db/app_database.dart';

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

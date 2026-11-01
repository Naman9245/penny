import 'package:penny/data/db/app_database.dart';

/// Small settings kept on this phone.
class PrefsRepository {
  PrefsRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  static const _note = 'penny_note';

  /// The longest note Penny takes.
  static const maxNoteLength = 200;

  /// What the user told Penny about their life on My needs, if anything.
  Stream<String?> watchNote() {
    final query = _db.select(_db.prefs)..where((p) => p.name.equals(_note));
    return query.watchSingleOrNull().map((pref) => pref?.value);
  }

  /// Keeps [note], trimmed and cut to [maxNoteLength]. Empty removes it.
  Future<void> setNote(String? note) async {
    var text = note?.trim() ?? '';
    if (text.length > maxNoteLength) {
      text = text.substring(0, maxNoteLength).trim();
    }
    if (text.isEmpty) {
      await (_db.delete(_db.prefs)..where((p) => p.name.equals(_note))).go();
      return;
    }
    await _db
        .into(_db.prefs)
        .insertOnConflictUpdate(
          PrefsCompanion.insert(name: _note, value: text, updatedAt: _clock()),
        );
  }
}

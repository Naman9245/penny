import 'package:penny/data/sync/sync_remote.dart';

/// An account's copy in memory, keeping the server's rules: every change
/// gets the next number, and an edit no newer than the row's is dropped.
class FakeSyncRemote implements SyncRemote {
  final _tables = <String, Map<String, Map<String, Object?>>>{};
  var _seq = 0;

  /// While true, every call fails as if offline.
  bool offline = false;

  /// Every row sent from the phone, by table, in order.
  final sent = <String, List<Map<String, Object?>>>{};

  /// The copy's rows of [table], by id, or by name for the note.
  Map<String, Map<String, Object?>> rows(String table) =>
      _tables[table] ?? const {};

  /// Writes [row] as another phone would.
  void put(String table, Map<String, Object?> row) => _keep(table, row);

  @override
  Future<void> push(String table, List<Map<String, Object?>> rows) async {
    if (offline) throw const SyncException(SyncFailure.offline);
    (sent[table] ??= []).addAll(rows);
    for (final row in rows) {
      _keep(table, row);
    }
  }

  @override
  Future<List<Map<String, Object?>>> pull(
    String table, {
    required int after,
    required int limit,
  }) async {
    if (offline) throw const SyncException(SyncFailure.offline);
    final newer = [
      for (final row in rows(table).values)
        if ((row['seq']! as int) > after) row,
    ]..sort((a, b) => (a['seq']! as int).compareTo(b['seq']! as int));
    return newer.take(limit).toList();
  }

  void _keep(String table, Map<String, Object?> row) {
    final key = (table == 'prefs' ? row['name'] : row['id'])! as String;
    final copy = _tables.putIfAbsent(table, () => {});
    final old = copy[key];
    if (old != null &&
        !DateTime.parse(row['updated_at']! as String)
            .isAfter(DateTime.parse(old['updated_at']! as String))) {
      return;
    }
    copy[key] = {...row, 'seq': ++_seq};
  }
}

import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/prefs_repository.dart';
import 'package:penny/data/sync/sync_remote.dart';

/// Backs this phone's money up to the signed-in account's copy, and brings
/// other phones' changes down: it sends what changed here, then fetches
/// what changed there since last time. The newer edit of a row wins on both
/// sides, and deletes travel as marks, so every phone ends up the same.
///
/// The chat, Penny's reports and plans, and SMS fingerprints never go: they
/// aren't among the columns below.
class SyncEngine {
  SyncEngine(this._db, this._remote, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final SyncRemote _remote;
  final DateTime Function() _clock;

  /// Rows per request, each way.
  static const batch = 500;

  /// One full sync with [account]'s copy. Throws [SyncException]; what
  /// wasn't sent stays marked, so the next sync carries on.
  Future<void> sync(String account) async {
    await _bindTo(account);
    for (final kind in _kinds) {
      await _push(kind);
    }
    var settled = false;
    for (final kind in _kinds) {
      if (await _pull(kind, account)) settled = true;
    }
    // Settling a clash retired a row here; send that straight back.
    if (settled) {
      for (final kind in _kinds) {
        await _push(kind);
      }
    }
  }

  /// How many rows wait to be sent, as it changes.
  Stream<int> watchWaiting() {
    final counts = [
      for (final kind in _kinds)
        '(SELECT COUNT(*) FROM ${kind.table} WHERE dirty = 1${kind.only})',
    ];
    return _db
        .customSelect(
          'SELECT ${counts.join(' + ')} AS waiting',
          readsFrom: {for (final kind in _kinds) _tableOf(kind)},
        )
        .watchSingle()
        .map((row) => row.read<int>('waiting'));
  }

  /// Ties this phone's progress to [account]. Another account, or the first
  /// sync, starts over: everything here goes up, and the copy comes down
  /// from its start.
  Future<void> _bindTo(String account) async {
    final cursors = await _db.select(_db.syncCursors).get();
    if (cursors.isNotEmpty && cursors.every((c) => c.account == account)) {
      return;
    }
    await _db.transaction(() async {
      await _db.delete(_db.syncCursors).go();
      for (final kind in _kinds) {
        await _db.customUpdate(
          'UPDATE ${kind.table} SET dirty = 1 WHERE dirty = 0${kind.only}',
          updates: {_tableOf(kind)},
        );
      }
    });
  }

  /// Sends what changed here, a batch at a time, then marks it sent unless
  /// it changed again meanwhile.
  Future<void> _push(_Kind kind) async {
    final table = _tableOf(kind);
    for (var round = 0; round < 200; round++) {
      final rows = await _db
          .customSelect(
            'SELECT ${kind.columns.join(', ')} FROM ${kind.table} '
            'WHERE dirty = 1${kind.only} LIMIT $batch',
            readsFrom: {table},
          )
          .get();
      if (rows.isEmpty) return;
      final local = [for (final row in rows) row.data];
      await _remote.push(kind.table, [
        for (final row in local) kind.toRemote(row),
      ]);
      await _db.transaction(() async {
        for (final row in local) {
          await _db.customUpdate(
            'UPDATE ${kind.table} SET dirty = 0 '
            'WHERE ${kind.key} = ? AND updated_at = ?',
            variables: [
              Variable<Object>(row[kind.key]),
              Variable<Object>(row['updated_at']),
            ],
            updates: {table},
          );
        }
      });
      if (rows.length < batch) return;
    }
  }

  /// Fetches what changed in the copy since last time, oldest first, and
  /// keeps how far it got. Returns whether settling a clash retired a row
  /// here, which then needs sending.
  Future<bool> _pull(_Kind kind, String account) async {
    var after =
        (await (_db.select(
          _db.syncCursors,
        )..where((c) => c.kind.equals(kind.table))).getSingleOrNull())?.seq ??
        0;
    var settled = false;
    for (var round = 0; round < 1000; round++) {
      final rows = await _remote.pull(kind.table, after: after, limit: batch);
      await _db.transaction(() async {
        for (final row in rows) {
          if (await _apply(kind, row)) settled = true;
        }
        if (rows.isNotEmpty) after = (rows.last['seq']! as num).toInt();
        await _db
            .into(_db.syncCursors)
            .insertOnConflictUpdate(
              SyncCursorsCompanion.insert(
                kind: kind.table,
                account: account,
                seq: after,
              ),
            );
      });
      if (rows.length < batch) break;
    }
    return settled;
  }

  /// Writes one row from the copy, unless this phone's is as new.
  ///
  /// A live row that clashes with another live one here, like a second
  /// budget for the same category, leaves the newer of the two live and
  /// retires the other here, marked to send. Returns whether it did.
  Future<bool> _apply(_Kind kind, Map<String, Object?> remote) async {
    final table = _tableOf(kind);
    final values = kind.toLocal(remote);
    var dirty = 0;
    var settled = false;
    if (kind.unique.isNotEmpty && values['deleted_at'] == null) {
      final sameKey = [for (final column in kind.unique) '$column = ?'];
      final clash = await _db
          .customSelect(
            'SELECT id, updated_at FROM ${kind.table} '
            'WHERE deleted_at IS NULL AND id <> ? AND ${sameKey.join(' AND ')}',
            variables: [
              Variable<Object>(values['id']),
              for (final column in kind.unique)
                Variable<Object>(values[column]),
            ],
            readsFrom: {table},
          )
          .getSingleOrNull();
      if (clash != null) {
        settled = true;
        final theirs = (values['updated_at']! as int, values['id']! as String);
        final ours = (clash.read<int>('updated_at'), clash.read<String>('id'));
        // Retired now, but always after the loser's last edit, so the
        // newer-edit-wins rule carries the retirement everywhere.
        int retiredAt((int, String) loser) =>
            math.max(_seconds(_clock()), loser.$1 + 1);
        if (_newer(theirs, ours)) {
          final at = retiredAt(ours);
          await _db.customUpdate(
            'UPDATE ${kind.table} SET deleted_at = ?, updated_at = ?, '
            'dirty = 1 WHERE id = ?',
            variables: [Variable(at), Variable(at), Variable(ours.$2)],
            updates: {table},
          );
        } else {
          final at = retiredAt(theirs);
          values['deleted_at'] = at;
          values['updated_at'] = at;
          dirty = 1;
        }
      }
    }
    final columns = [...kind.columns, 'dirty'];
    final assignments = [
      for (final column in columns)
        if (column != kind.key) '$column = excluded.$column',
    ];
    await _db.customInsert(
      'INSERT INTO ${kind.table} (${columns.join(', ')}) '
      'VALUES (${List.filled(columns.length, '?').join(', ')}) '
      'ON CONFLICT(${kind.key}) DO UPDATE SET ${assignments.join(', ')} '
      'WHERE excluded.updated_at > ${kind.table}.updated_at',
      variables: [
        for (final column in kind.columns) Variable<Object>(values[column]),
        Variable(dirty),
      ],
      updates: {table},
    );
    return settled;
  }

  TableInfo<Table, Object?> _tableOf(_Kind kind) =>
      _db.allTables.firstWhere((table) => table.actualTableName == kind.table);
}

/// Whether ([updatedAt], id) [a] is newer than [b]; the id breaks a tie, so
/// two phones settle the same way.
bool _newer((int, String) a, (int, String) b) =>
    a.$1 > b.$1 || (a.$1 == b.$1 && a.$2.compareTo(b.$2) > 0);

/// Drift keeps dates as whole seconds since the epoch.
int _seconds(DateTime at) => at.millisecondsSinceEpoch ~/ 1000;

/// One synced table: its columns, the same on both sides, which hold dates
/// or yes/no, and what else only one live row may share.
class _Kind {
  const _Kind(
    this.table, {
    required this.columns,
    this.key = 'id',
    this.dates = const {'created_at', 'updated_at', 'deleted_at'},
    this.flags = const {},
    this.limits = const {},
    this.unique = const [],
    this.names = const {},
  });

  /// Its name, the same on the phone and the server.
  final String table;

  /// The columns that travel. Anything else stays on the phone.
  final List<String> columns;

  /// The column that names a row: its id, or a setting's name.
  final String key;
  final Set<String> dates;
  final Set<String> flags;

  /// Text the server keeps shorter, by column.
  final Map<String, int> limits;

  /// Columns only one live row may share, like a budget's category.
  final List<String> unique;

  /// The only rows that travel, by their name here and on the server; all
  /// rows when empty.
  final Map<String, String> names;

  /// The SQL that keeps a query to the rows that travel.
  String get only => names.isEmpty
      ? ''
      : " AND $key IN (${[for (final name in names.keys) "'$name'"].join(', ')})";

  Map<String, Object?> toRemote(Map<String, Object?> local) => {
    for (final column in columns)
      column: switch (local[column]) {
        null => null,
        final int seconds when dates.contains(column) =>
          DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000,
            isUtc: true,
          ).toIso8601String(),
        final int flag when flags.contains(column) => flag != 0,
        final String name when column == key && names.isNotEmpty =>
          names[name] ?? name,
        final String text when text.length > (limits[column] ?? text.length) =>
          text.substring(0, limits[column]),
        final value => value,
      },
  };

  Map<String, Object?> toLocal(Map<String, Object?> remote) => {
    for (final column in columns)
      column: switch (remote[column]) {
        null => null,
        final String text when dates.contains(column) => _seconds(
          DateTime.parse(text),
        ),
        final bool flag => flag ? 1 : 0,
        final String name when column == key && names.isNotEmpty =>
          names.entries
                  .where((entry) => entry.value == name)
                  .firstOrNull
                  ?.key ??
              name,
        final value => value,
      },
  };
}

const _stamps = {'created_at', 'updated_at', 'deleted_at'};

/// Every synced table, in the order they travel.
const _kinds = [
  _Kind(
    'txns',
    columns: [
      'id',
      'amount_paise',
      'type',
      'category_id',
      'merchant',
      'occurred_at',
      'source',
      'tag',
      'payee_is_person',
      'created_at',
      'updated_at',
      'deleted_at',
    ],
    dates: {..._stamps, 'occurred_at'},
    flags: {'payee_is_person'},
    limits: {'merchant': 500},
  ),
  _Kind(
    'budgets',
    columns: [
      'id',
      'budget_key',
      'amount_paise',
      'created_at',
      'updated_at',
      'deleted_at',
    ],
    unique: ['budget_key'],
  ),
  _Kind(
    'goals',
    columns: [
      'id',
      'title',
      'target_paise',
      'deadline',
      'created_at',
      'updated_at',
      'deleted_at',
    ],
    dates: {..._stamps, 'deadline'},
    limits: {'title': 200},
  ),
  _Kind(
    'goal_deposits',
    columns: [
      'id',
      'goal_id',
      'amount_paise',
      'occurred_at',
      'created_at',
      'updated_at',
      'deleted_at',
    ],
    dates: {..._stamps, 'occurred_at'},
  ),
  _Kind(
    'tag_rules',
    columns: [
      'id',
      'kind',
      'rule_key',
      'tag',
      'created_at',
      'updated_at',
      'deleted_at',
    ],
    unique: ['kind', 'rule_key'],
  ),
  _Kind(
    'prefs',
    key: 'name',
    columns: ['name', 'value', 'updated_at'],
    dates: {'updated_at'},
    names: {PrefsRepository.noteName: 'note'},
  ),
];

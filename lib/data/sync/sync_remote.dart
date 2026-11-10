import 'dart:async';
import 'dart:math' as math;

import 'package:penny/data/supabase_start.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The signed-in account's copy of its synced tables, as rows keyed by the
/// server's column names, with dates as ISO 8601 text.
abstract interface class SyncRemote {
  /// Sends [rows] of [table]. The copy keeps the newer edit of each row:
  /// returned are the rows it refused, as it has them, its own edit being
  /// as new.
  Future<List<Map<String, Object?>>> push(
    String table,
    List<Map<String, Object?>> rows,
  );

  /// Up to [limit] rows of [table] changed after change number [after],
  /// oldest change first, each with its `seq`.
  Future<List<Map<String, Object?>>> pull(
    String table, {
    required int after,
    required int limit,
  });
}

/// Why a sync stopped.
enum SyncFailure {
  /// No internet, or the server didn't answer in time. It retries later.
  offline,

  /// The server refused, or something unexpected went wrong.
  failed,
}

class SyncException implements Exception {
  const SyncException(this.failure, [this.detail]);

  final SyncFailure failure;
  final String? detail;

  @override
  String toString() => 'SyncException(${failure.name}, $detail)';
}

/// [SyncRemote] over Supabase's tables, as the signed-in user. Row-level
/// security keeps each account to its own rows.
class SupabaseSyncRemote implements SyncRemote {
  SupabaseSyncRemote([this._connect = startSupabase]);

  final Future<SupabaseClient> Function() _connect;

  static const _timeout = Duration(seconds: 30);

  /// Rows asked for by key at a time, keeping the address short.
  static const _keysPerFetch = 100;

  /// The column that names a row of [table] within its account: the note's
  /// name, or everything else's id. A second account on the same phone
  /// sends the same ids, so the copy keys rows by account and this. The
  /// account isn't sent; the server fills it in before looking for a clash.
  static String _keyOf(String table) => table == 'prefs' ? 'name' : 'id';

  @override
  Future<List<Map<String, Object?>>> push(
    String table,
    List<Map<String, Object?>> rows,
  ) => _guard(() async {
    final client = await _connect();
    final key = _keyOf(table);
    final kept = await client
        .from(table)
        .upsert(rows, onConflict: 'user_id,$key', defaultToNull: false)
        .select(key);
    // The copy's trigger drops an edit no newer than its own, and only the
    // rows it wrote come back.
    final keptKeys = {for (final row in kept) row[key]};
    final refused = [
      for (final row in rows)
        if (!keptKeys.contains(row[key])) row[key],
    ];
    final theirs = <Map<String, Object?>>[];
    for (var i = 0; i < refused.length; i += _keysPerFetch) {
      final some = refused.sublist(
        i,
        math.min(i + _keysPerFetch, refused.length),
      );
      final rows = await client.from(table).select().inFilter(key, some);
      theirs.addAll([for (final row in rows) Map<String, Object?>.of(row)]);
    }
    return theirs;
  });

  @override
  Future<List<Map<String, Object?>>> pull(
    String table, {
    required int after,
    required int limit,
  }) => _guard(() async {
    final client = await _connect();
    final rows = await client
        .from(table)
        .select()
        .gt('seq', after)
        .order('seq')
        .limit(limit);
    return [for (final row in rows) Map<String, Object?>.of(row)];
  });

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call().timeout(_timeout);
    } on TimeoutException {
      throw const SyncException(SyncFailure.offline);
    } on PostgrestException catch (error) {
      throw SyncException(SyncFailure.failed, error.message);
    } on AuthException catch (error) {
      throw SyncException(SyncFailure.failed, error.message);
    } on Exception catch (error) {
      // Socket and client errors: no connection.
      throw SyncException(SyncFailure.offline, '$error');
    }
  }
}

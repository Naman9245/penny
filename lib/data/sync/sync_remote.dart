import 'dart:async';

import 'package:penny/data/supabase_start.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The signed-in account's copy of its synced tables, as rows keyed by the
/// server's column names, with dates as ISO 8601 text.
abstract interface class SyncRemote {
  /// Sends [rows] of [table]. The copy keeps the newer edit of each row.
  Future<void> push(String table, List<Map<String, Object?>> rows);

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

  @override
  Future<void> push(String table, List<Map<String, Object?>> rows) =>
      _guard(() async {
        final client = await _connect();
        await client
            .from(table)
            .upsert(
              rows,
              // The note is one per account; everything else has its id.
              onConflict: table == 'prefs' ? 'user_id,name' : 'id',
              defaultToNull: false,
            );
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

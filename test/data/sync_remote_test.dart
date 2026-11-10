import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/sync/sync_remote.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late _Server server;
  late SupabaseClient client;
  late SupabaseSyncRemote remote;

  setUp(() async {
    server = await _Server.start();
    client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-key');
    remote = SupabaseSyncRemote(() async => client);
  });
  tearDown(() async {
    await client.dispose();
    await server.close();
  });

  const id = '0192f0c0-0000-7000-8000-00000000d001';
  Map<String, Object?> food(int paise, String updatedAt) => {
    'id': id,
    'amount_paise': paise,
    'type': 'debit',
    'category_id': 'food',
    'created_at': '2026-11-03T04:30:00.000Z',
    'updated_at': updatedAt,
    'deleted_at': null,
  };

  test(
    'a second account on this phone gets its own copy of the same rows',
    () async {
      server.account = 'account-1';
      expect(
        await remote.push('txns', [food(25000, '2026-11-03T04:30:00.000Z')]),
        isEmpty,
      );

      // The phone signs in to another account and sends the same row up.
      server.account = 'account-2';
      expect(
        await remote.push('txns', [food(25000, '2026-11-03T04:30:00.000Z')]),
        isEmpty,
      );

      expect(
        server.rows('txns').keys,
        unorderedEquals(['account-1/$id', 'account-2/$id']),
      );
      final upsert = server.requests.last;
      expect(upsert.uri.queryParameters['on_conflict'], 'user_id,id');
      // The account isn't sent: the server fills it in.
      expect(
        upsert.uri.queryParameters['columns'],
        allOf(startsWith('"id",'), isNot(contains('user_id'))),
      );
      expect(upsert.headers.value('prefer'), contains('missing=default'));
    },
  );

  test('the note is matched by account and name', () async {
    server.account = 'account-1';
    await remote.push('prefs', [
      {
        'name': 'note',
        'value': 'Student in a PG',
        'updated_at': '2026-11-03T04:30:00.000Z',
      },
    ]);

    expect(
      server.requests.last.uri.queryParameters['on_conflict'],
      'user_id,name',
    );
    expect(server.rows('prefs').keys, ['account-1/note']);
  });

  test(
    'an edit the copy has a newer one of comes back as the copy has it',
    () async {
      server.account = 'account-1';
      await remote.push('txns', [food(30000, '2026-11-03T06:30:00.000Z')]);

      final refused = await remote.push('txns', [
        food(40000, '2026-11-03T05:30:00.000Z'),
      ]);

      expect(refused, hasLength(1));
      expect(refused.single['amount_paise'], 30000);
      expect(server.requests.last.uri.queryParameters['id'], 'in.("$id")');
    },
  );
}

/// Just enough of the server's tables: rows keyed by the upsert's conflict
/// columns, each account's own, the account filled in by default, and an
/// edit no newer than the row's dropped. Touching another account's row is
/// refused, as row-level security does.
class _Server {
  _Server._(this._http) {
    _http.listen(_handle);
  }

  static Future<_Server> start() async =>
      _Server._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _http;
  final _tables = <String, Map<String, Map<String, Object?>>>{};

  /// Who the requests are signed in as.
  String account = '';

  /// Every request so far, oldest first.
  final requests = <HttpRequest>[];

  int get port => _http.port;

  Future<void> close() => _http.close(force: true);

  /// [table]'s rows, by "account/key".
  Map<String, Map<String, Object?>> rows(String table) =>
      _tables[table] ?? const {};

  Future<void> _handle(HttpRequest request) async {
    requests.add(request);
    final table = request.uri.pathSegments.last;
    final query = request.uri.queryParameters;
    final rows = _tables.putIfAbsent(table, () => {});
    final key = table == 'prefs' ? 'name' : 'id';
    Object? body;
    var status = HttpStatus.ok;
    if (request.method == 'POST') {
      final sent = jsonDecode(await utf8.decoder.bind(request).join()) as List;
      final conflict = query['on_conflict']!.split(',');
      final kept = <Map<String, Object?>>[];
      for (final row in sent.cast<Map<String, Object?>>()) {
        final full = {'user_id': account, ...row};
        final old = rows.values
            .where((r) => conflict.every((c) => r[c] == full[c]))
            .firstOrNull;
        if (old != null && old['user_id'] != account) {
          status = HttpStatus.forbidden;
          body = {
            'code': '42501',
            'message': 'new row violates row-level security policy',
          };
          break;
        }
        if (old != null &&
            !DateTime.parse(full['updated_at']! as String)
                .isAfter(DateTime.parse(old['updated_at']! as String))) {
          continue;
        }
        rows['$account/${full[key]}'] = full;
        kept.add({key: full[key]});
      }
      if (status == HttpStatus.ok) {
        status = HttpStatus.created;
        body = kept;
      }
    } else {
      final wanted = query[key]!
          .replaceFirst('in.(', '')
          .replaceFirst(RegExp(r'\)$'), '')
          .split(',')
          .map((value) => value.replaceAll('"', ''))
          .toSet();
      body = [
        for (final row in rows.values)
          if (row['user_id'] == account && wanted.contains(row[key])) row,
      ];
    }
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await request.response.close();
  }
}

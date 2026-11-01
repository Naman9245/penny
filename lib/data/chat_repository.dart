import 'package:drift/drift.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/chat.dart';
import 'package:uuid/uuid.dart';

/// The chat with Penny. It stays on this phone.
class ChatRepository {
  ChatRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  static const _uuid = Uuid();

  // In the order they were said. Stored times keep whole seconds only, so a
  // quick reply could tie with its question, and the phone's clock can move.
  static final _oldestFirst = <OrderClauseGenerator<$ChatMessagesTable>>[
    (m) => OrderingTerm.asc(m.rowId),
  ];

  /// Every message, oldest first.
  Stream<List<ChatMessage>> watch() {
    final query = _db.select(_db.chatMessages)..orderBy(_oldestFirst);
    return query.watch();
  }

  /// The last [count] messages, oldest first.
  Future<List<ChatMessage>> recent(int count) async {
    final query = _db.select(_db.chatMessages)
      ..orderBy([(m) => OrderingTerm.desc(m.rowId)])
      ..limit(count);
    return (await query.get()).reversed.toList();
  }

  Future<void> add(ChatRole role, String body) {
    return _db
        .into(_db.chatMessages)
        .insert(
          ChatMessagesCompanion.insert(
            id: _uuid.v7(),
            role: role,
            body: body,
            createdAt: _clock(),
          ),
        );
  }

  /// Empties the chat for good. It was never anywhere but this phone.
  Future<void> clear() => _db.delete(_db.chatMessages).go();
}

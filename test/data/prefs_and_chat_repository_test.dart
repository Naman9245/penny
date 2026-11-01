import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/chat_repository.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/prefs_repository.dart';
import 'package:penny/models/chat.dart';

void main() {
  late AppDatabase db;
  late DateTime clock;

  setUp(() {
    clock = DateTime(2026, 11, 2, 10);
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  group('the note to Penny', () {
    test('is kept trimmed and cut to the limit', () async {
      final prefs = PrefsRepository(db, clock: () => clock);
      expect(await prefs.watchNote().first, isNull);

      await prefs.setNote('  Student in a PG, metro daily  ');
      expect(await prefs.watchNote().first, 'Student in a PG, metro daily');

      await prefs.setNote('x' * 250);
      expect(await prefs.watchNote().first, hasLength(200));
    });

    test('an empty note removes it', () async {
      final prefs = PrefsRepository(db, clock: () => clock);
      await prefs.setNote('Hostel in Delhi');
      await prefs.setNote('   ');
      expect(await prefs.watchNote().first, isNull);
    });
  });

  group('the chat', () {
    test('comes back oldest first, and recent() takes the last few', () async {
      final chat = ChatRepository(db, clock: () => clock);
      for (var i = 1; i <= 5; i++) {
        clock = DateTime(2026, 11, 2, 10, i);
        await chat.add(i.isOdd ? ChatRole.user : ChatRole.penny, 'message $i');
      }

      final all = await chat.watch().first;
      expect(all.map((m) => m.body), [
        'message 1',
        'message 2',
        'message 3',
        'message 4',
        'message 5',
      ]);
      expect(all.first.role, ChatRole.user);

      final recent = await chat.recent(2);
      expect(recent.map((m) => m.body), ['message 4', 'message 5']);
    });

    test('clear empties it', () async {
      final chat = ChatRepository(db, clock: () => clock);
      await chat.add(ChatRole.user, 'Hi Penny');
      await chat.clear();
      expect(await chat.watch().first, isEmpty);
    });
  });
}

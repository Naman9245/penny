import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/features/chat/chat_controller.dart';
import 'package:penny/models/chat.dart';
import 'package:penny/models/penny_mood.dart';
import 'package:penny/services/penny_ai.dart';

import '../helpers/fake_ai.dart';

void main() {
  late AppDatabase db;
  late FakeAiClient ai;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ai = FakeAiClient(reply: (request) => 'About: ${request.turns.last.text}');
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        aiClientProvider.overrideWithValue(ai),
      ],
    );
    // Open with the month loaded, as the chat screen keeps it.
    container.listen(chatControllerProvider, (_, _) {});
    await container.read(chatMonthProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  ChatController chat() => container.read(chatControllerProvider.notifier);
  ChatState state() => container.read(chatControllerProvider);
  Future<List<(ChatRole, String)>> kept() async => [
    for (final message
        in await container.read(chatRepositoryProvider).recent(50))
      (message.role, message.body),
  ];

  test("keeps the message and Penny's reply", () async {
    await chat().send('  How do I save?  ');

    expect(await kept(), [
      (ChatRole.user, 'How do I save?'),
      (ChatRole.penny, 'About: How do I save?'),
    ]);
    expect(state().sending, isFalse);
    expect(state().failure, isNull);
    expect(state().callsLeftToday, 29);
  });

  test('Penny hears the chat so far', () async {
    await chat().send('First');
    await chat().send('Second');

    expect(ai.chats.last.turns, [
      (role: ChatRole.user, text: 'First'),
      (role: ChatRole.penny, text: 'About: First'),
      (role: ChatRole.user, text: 'Second'),
    ]);
  });

  test('Penny hears her mood on Home, and that there are no goals', () async {
    await chat().send('Hi');

    final sent = ai.chats.single;
    expect(sent.toJson()['goals'], isEmpty);
    // No budget yet, so Home shows her neutral.
    expect(sent.mood, PennyMood.neutral);
  });

  test('a blank message is not sent', () async {
    await chat().send('   ');
    expect(ai.chats, isEmpty);
    expect(await kept(), isEmpty);
  });

  test('a failure keeps the message, and retry asks about it again', () async {
    ai.failure = const AiException(AiFailure.busy);
    await chat().send('Hi');
    expect(state().failure?.failure, AiFailure.busy);
    expect(await kept(), [(ChatRole.user, 'Hi')]);

    ai.failure = null;
    await chat().retry();
    expect(state().failure, isNull);
    expect(ai.chats.last.turns, [(role: ChatRole.user, text: 'Hi')]);
    expect(await kept(), [
      (ChatRole.user, 'Hi'),
      (ChatRole.penny, 'About: Hi'),
    ]);
  });

  test('clear empties the chat and forgets the failure', () async {
    ai.failure = const AiException(AiFailure.slow);
    await chat().send('Hi');
    await chat().clear();

    expect(await kept(), isEmpty);
    expect(state().failure, isNull);
  });
}

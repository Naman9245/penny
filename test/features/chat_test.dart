import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/chat_repository.dart';
import 'package:penny/data/goal_repository.dart';
import 'package:penny/data/prefs_repository.dart';
import 'package:penny/data/rules_repository.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/features/chat/chat_screen.dart';
import 'package:penny/models/chat.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/models/your_rules.dart';
import 'package:penny/services/penny_ai.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_ai.dart';

void main() {
  final month = monthStart(DateTime.now());

  Future<void> seedMonth(TxnRepository repo) async {
    await repo.add(
      amountPaise: 30000,
      type: TxnType.debit,
      categoryId: 'food',
      occurredAt: DateTime(month.year, month.month, 1, 9),
      merchant: 'Swiggy',
    );
  }

  Future<void> openChat(WidgetTester tester) async {
    routerOf(tester).push('/chat');
    await tester.pumpAndSettle();
  }

  Future<void> say(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const ValueKey('chat-input')), text);
    await tester.tap(find.byKey(const ValueKey('chat-send')));
    await tester.pumpAndSettle();
  }

  testWidgets("Home's Penny card opens the chat, and an idea gets a reply", (
    tester,
  ) async {
    final ai = FakeAiClient(reply: (_) => 'Swiggy is the big one. Cook more.');
    final db = await pumpApp(
      tester,
      seed: seedMonth,
      seedDb: (db) =>
          RulesRepository(db)
              .set(RuleKind.shop, shopKey('Swiggy')!, TxnTag.wasteful),
      ai: ai,
    );

    await tester.tap(find.byKey(const ValueKey('penny-card')));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);

    await tester.tap(find.text('Where am I wasting money?'));
    await tester.pumpAndSettle();

    expect(find.text('Where am I wasting money?'), findsOneWidget);
    expect(find.text('Swiggy is the big one. Cook more.'), findsOneWidget);
    expect(find.text('29 more messages today'), findsOneWidget);
    expect(find.textContaining("I'm Penny"), findsNothing);

    // Penny hears the question with this month, and My needs' tag on it.
    final sent = ai.chats.single;
    expect(sent.turns, [
      (role: ChatRole.user, text: 'Where am I wasting money?'),
    ]);
    expect(sent.month.month, month);
    expect(sent.tags, {groupId(sent.month, shop: 'Swiggy'): TxnTag.wasteful});
    await closeApp(tester, db);
  });

  testWidgets('Penny hears about the goals too', (tester) async {
    final ai = FakeAiClient(reply: (_) => 'You can do it!');
    final db = await pumpApp(
      tester,
      seed: seedMonth,
      seedDb: (db) async {
        final goals = GoalRepository(db);
        final id = await goals.add(
          title: 'Delhi trip',
          targetPaise: 1500000,
          deadline: DateTime.now().add(const Duration(days: 70)),
        );
        await goals.deposit(id, 300000);
      },
      ai: ai,
    );
    await openChat(tester);
    await say(tester, 'How do I reach my Delhi trip?');

    final goal = ai.chats.single.goals.single;
    expect(goal.title, 'Delhi trip');
    expect(goal.targetPaise, 1500000);
    expect(goal.savedPaise, 300000);
    expect(goal.reached, isFalse);
    expect(goal.perWeekPaise, greaterThan(0));

    // And "See what Penny sends" lists them.
    final seeSent = find.byKey(const ValueKey('chat-see-sent'));
    await tester.ensureVisible(seeSent);
    await tester.pumpAndSettle();
    await tester.tap(seeSent);
    await tester.pumpAndSettle();
    expect(find.text('Your goals'), findsOneWidget);
    expect(find.byKey(const ValueKey('sent-goals-0')), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('Penny is typing until her reply comes', (tester) async {
    final ai = FakeAiClient(reply: (_) => 'Haan, bilkul!')
      ..hold = Completer<void>();
    final db = await pumpApp(tester, seed: seedMonth, ai: ai);
    await openChat(tester);

    await say(tester, 'Kya main Swiggy kam kar sakta hoon?');
    expect(find.text('Kya main Swiggy kam kar sakta hoon?'), findsOneWidget);
    expect(find.byKey(const ValueKey('penny-typing')), findsOneWidget);
    // Nothing more to send, or clear, until she answers.
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('chat-input')))
          .controller!
          .text,
      isEmpty,
    );
    expect(find.byKey(const ValueKey('clear-chat')), findsNothing);

    ai.hold!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('penny-typing')), findsNothing);
    expect(find.text('Haan, bilkul!'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('a message Penny could not answer can be asked again', (
    tester,
  ) async {
    final ai = FakeAiClient(
      failure: const AiException(AiFailure.dailyLimit, limit: 30),
    );
    final db = await pumpApp(tester, seed: seedMonth, ai: ai);
    await openChat(tester);

    await say(tester, 'How do I save?');
    expect(
      find.text('Penny can answer 30 messages a day. Try again tomorrow.'),
      findsOneWidget,
    );

    ai
      ..failure = null
      ..reply = (_) => 'Start with a weekly cap.';
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chat-problem')), findsNothing);
    expect(find.text('Start with a weekly cap.'), findsOneWidget);
    // The same message, kept once.
    expect(ai.chats, hasLength(2));
    expect(ai.chats.last.turns, [
      (role: ChatRole.user, text: 'How do I save?'),
    ]);
    expect(find.text('How do I save?'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('Clear chat asks first, then empties it', (tester) async {
    final db = await pumpApp(
      tester,
      seedDb: (db) async {
        final chat = ChatRepository(db);
        await chat.add(ChatRole.user, 'How can I spend less on food?');
        await chat.add(ChatRole.penny, 'Cook twice a week.');
      },
      ai: FakeAiClient(reply: (_) => 'Hi!'),
    );
    await openChat(tester);
    expect(find.text('Cook twice a week.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('clear-chat')));
    await tester.pumpAndSettle();
    expect(find.text('Clear the chat?'), findsOneWidget);
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();
    expect(find.text('Cook twice a week.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('clear-chat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-clear-chat')));
    await tester.pumpAndSettle();
    expect(find.text('Cook twice a week.'), findsNothing);
    expect(
      find.text('How can I spend less on food?'),
      findsOneWidget,
      reason: 'back as an idea to tap',
    );
    expect(find.byKey(const ValueKey('clear-chat')), findsNothing);
    await closeApp(tester, db);
  });

  testWidgets('"See what Penny sends" shows the month and the note', (
    tester,
  ) async {
    final db = await pumpApp(
      tester,
      seed: seedMonth,
      seedDb: (db) => PrefsRepository(db).setNote('Student in a PG'),
      ai: FakeAiClient(reply: (_) => 'Hi!'),
    );
    await openChat(tester);

    await tester.tap(find.byKey(const ValueKey('chat-see-sent')));
    await tester.pumpAndSettle();
    expect(find.text('What Penny sends'), findsOneWidget);
    expect(find.text('Swiggy'), findsOneWidget);
    expect(find.text('Student in a PG'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('a build without Penny\'s server says so and sends nothing', (
    tester,
  ) async {
    final db = await pumpApp(tester, seed: seedMonth);
    await openChat(tester);

    expect(find.text("Penny's AI isn't set up in this build yet."), findsOne);
    expect(find.byKey(const ValueKey('chat-input')), findsNothing);
    await tester.tap(find.text('Where am I wasting money?'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('penny-typing')), findsNothing);
    expect(find.textContaining("I'm Penny"), findsOneWidget);
    await closeApp(tester, db);
  });
}

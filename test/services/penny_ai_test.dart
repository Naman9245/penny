import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/chat.dart';
import 'package:penny/models/month_insight.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/goal_plan.dart';
import 'package:penny/services/insight_builder.dart';
import 'package:penny/services/penny_ai.dart';

import '../helpers/txn_factory.dart';

void main() {
  final request = buildInsightRequest(
    month: DateTime(2026, 10),
    txns: [
      txn(300, DateTime(2026, 10, 2), merchant: 'Swiggy'),
      txn(900, DateTime(2026, 10, 4), categoryId: 'rent'),
      txn(80, DateTime(2026, 10, 5)),
    ],
    now: DateTime(2026, 11, 2),
  );

  test('error replies become plain reasons', () {
    expect(aiExceptionFor(0, null).failure, AiFailure.offline);

    final limit = aiExceptionFor(429, {'error': 'daily_limit', 'limit': 10});
    expect(limit.failure, AiFailure.dailyLimit);
    expect(limit.message, contains('10 times a day'));

    expect(aiExceptionFor(429, {'error': 'busy'}).failure, AiFailure.busy);
    expect(aiExceptionFor(503, {'error': 'busy'}).failure, AiFailure.busy);
    expect(
      aiExceptionFor(503, {'error': 'not_configured'}).failure,
      AiFailure.serverNotReady,
    );
    expect(aiExceptionFor(504, {'error': 'too_slow'}).failure, AiFailure.slow);
    expect(
      aiExceptionFor(502, {'error': 'bad_answer'}).failure,
      AiFailure.badAnswer,
    );
    expect(aiExceptionFor(500, 'oops').failure, AiFailure.unavailable);
    expect(
      aiExceptionFor(502, {'error': 'ai_unavailable'}).failure,
      AiFailure.unavailable,
    );
  });

  test('every failure has words to show', () {
    for (final failure in AiFailure.values) {
      expect(AiException(failure).message, isNotEmpty);
    }
  });

  test('reads the answer, dropping ids that were never sent', () {
    final answer = answerFrom({
      'insight': {
        'tags': {'s1': 'necessary', 's2': 'wasteful', 's7': 'wasteful'},
        'habits': [
          {
            'title': 'Delivery',
            'groups': ['s2'],
            'cut': 'half',
            'tip': 'Cook.',
          },
        ],
        'summary': 'Nice month!',
        'incomeNote': '',
      },
      'model': 'gemini-3.8-flash',
      'callsLeftToday': 9,
    }, request)!;

    expect(answer.insight.tags, {
      's1': TxnTag.necessary,
      's2': TxnTag.wasteful,
    });
    expect(answer.insight.habits.single.cut, Cut.half);
    expect(answer.model, 'gemini-3.8-flash');
    expect(answer.callsLeftToday, 9);
  });

  test('anything else is no answer', () {
    expect(answerFrom('hello', request), isNull);
    expect(answerFrom({'insight': {}}, request), isNull);
    expect(answerFrom({'model': 'm'}, request), isNull);
  });

  test('a build without the server says so before trying', () async {
    final client = SupabaseAiClient(url: '', publishableKey: '');
    expect(client.isSetUp, isFalse);
    final notSetUp = throwsA(
      isA<AiException>().having(
        (e) => e.failure,
        'failure',
        AiFailure.notSetUp,
      ),
    );
    await expectLater(client.analyzeMonth(request), notSetUp);
    await expectLater(
      client.chat(
        ChatRequest(
          month: request,
          tags: const {},
          turns: const [(role: ChatRole.user, text: 'Hi')],
        ),
      ),
      notSetUp,
    );
  });

  group('goal plans', () {
    final planRequest = GoalPlanRequest(
      goalId: 'g1',
      month: request,
      tags: const {},
      goal: const {
        'title': 'Delhi trip',
        'target': 15000,
        'saved': 3000,
        'weeksLeft': 15,
        'perWeek': 800,
        'perMonth': 3477,
      },
      inputHash: 'hash',
    );

    test('a plan comes back with only the groups that were sent', () {
      final answer = planAnswerFrom({
        'plan': {
          'cuts': [
            {
              'title': 'Fewer delivery nights',
              'groups': ['s1', 's9'],
              'cut': 'half',
              'tip': 'Cook twice a week.',
            },
          ],
          'summary': 'Delhi is within reach!',
        },
        'model': 'gemini-3.5-flash-lite',
        'callsLeftToday': 8,
      }, planRequest)!;

      expect(answer.plan.cuts.single.groupIds, ['s1']);
      expect(answer.plan.summary, 'Delhi is within reach!');
      expect(answer.callsLeftToday, 8);
      expect(planAnswerFrom({'model': 'm'}, planRequest), isNull);
      expect(planAnswerFrom('plan', planRequest), isNull);
    });

    test('a build without the server says so before trying', () async {
      final client = SupabaseAiClient(url: '', publishableKey: '');
      await expectLater(
        client.planGoal(planRequest),
        throwsA(
          isA<AiException>().having(
            (e) => e.failure,
            'failure',
            AiFailure.notSetUp,
          ),
        ),
      );
    });
  });

  test('goals go to the chat in rupees, with their date', () {
    final chat = ChatRequest(
      month: request,
      tags: const {},
      turns: const [(role: ChatRole.user, text: 'Hi')],
      goals: [
        (
          title: 'Delhi trip',
          targetPaise: 1500000,
          savedPaise: 300050,
          deadline: DateTime(2027, 2, 15),
          perWeekPaise: 80000,
          reached: false,
        ),
      ],
    );
    expect(chat.toJson()['goals'], [
      {
        'title': 'Delhi trip',
        'target': 15000,
        'saved': 3001,
        'deadline': '2027-02-15',
        'perWeek': 800,
        'reached': false,
      },
    ]);
    expect(
      ChatRequest(
        month: request,
        tags: const {},
        turns: const [(role: ChatRole.user, text: 'Hi')],
      ).toJson().containsKey('goals'),
      isFalse,
    );
  });

  group('the chat', () {
    ChatMessage said(ChatRole role, String body) => ChatMessage(
      id: body,
      role: role,
      body: body,
      createdAt: DateTime(2026, 11, 2),
    );

    test('sends the month as the report would, tags by name, and turns', () {
      final json = ChatRequest(
        month: request,
        tags: {'s1': TxnTag.wasteful, 's2': TxnTag.necessary},
        turns: const [(role: ChatRole.user, text: 'How do I save?')],
      ).toJson();

      expect(json, {
        'v': 1,
        'month': request.body,
        'tags': {'s1': 'wasteful', 's2': 'necessary'},
        'messages': [
          {'role': 'user', 'text': 'How do I save?'},
        ],
      });
    });

    test('turns: back-to-back messages join, and Penny never goes first', () {
      expect(
        chatTurns([
          said(ChatRole.penny, 'Hello!'),
          said(ChatRole.user, 'Hi'),
          said(ChatRole.user, 'How do I save?'),
          said(ChatRole.penny, 'Cook more.'),
          said(ChatRole.user, '   '),
          said(ChatRole.user, 'Thanks'),
        ]),
        [
          (role: ChatRole.user, text: 'Hi\nHow do I save?'),
          (role: ChatRole.penny, text: 'Cook more.'),
          (role: ChatRole.user, text: 'Thanks'),
        ],
      );
    });

    test('turns: only the last few, each cut to what the server takes', () {
      final turns = chatTurns([
        for (var i = 0; i < 20; i++)
          said(i.isEven ? ChatRole.user : ChatRole.penny, 'm$i'),
        said(ChatRole.user, 'x' * 1500),
      ]);

      // The last 12 start with Penny's m9, so that one goes too.
      expect(turns, hasLength(11));
      expect(turns.first, (role: ChatRole.user, text: 'm10'));
      expect(turns.last.text, hasLength(1000));
    });

    test('reads a reply, and nothing else', () {
      final answer = chatAnswerFrom({
        'reply': '  Cook twice a week.  ',
        'model': 'gemini-3.5-flash-lite',
        'callsLeftToday': 28,
      })!;
      expect(answer.reply, 'Cook twice a week.');
      expect(answer.callsLeftToday, 28);

      expect(
        chatAnswerFrom({'reply': 'Hi', 'callsLeftToday': 'many'})!
            .callsLeftToday,
        isNull,
      );
      expect(chatAnswerFrom({'reply': '   '}), isNull);
      expect(chatAnswerFrom({'reply': 5}), isNull);
      expect(chatAnswerFrom('Cook twice a week.'), isNull);
    });
  });
}

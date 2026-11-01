import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/month_insight.dart';
import 'package:penny/models/txn_enums.dart';
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
      AiFailure.notSetUp,
    );
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
    await expectLater(
      client.analyzeMonth(request),
      throwsA(
        isA<AiException>().having(
          (e) => e.failure,
          'failure',
          AiFailure.notSetUp,
        ),
      ),
    );
  });
}

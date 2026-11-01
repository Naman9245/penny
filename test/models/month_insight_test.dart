import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/month_insight.dart';
import 'package:penny/models/txn_enums.dart';

void main() {
  test('reads an answer, keeping only what makes sense', () {
    final insight = MonthInsight.fromJson(
      {
        'tags': {
          's1': 'wasteful',
          's2': 'necessary',
          's9': 'wasteful',
          's3': 'meh',
        },
        'habits': [
          {
            'title': ' Delivery ',
            'groups': ['s1', 's9'],
            'cut': 'half',
            'tip': 'Cook.',
          },
          {
            'title': 'Odd',
            'groups': ['s1'],
            'cut': 'most',
            'tip': '',
          },
          {
            'title': 'Ghost',
            'groups': ['s9'],
            'cut': 'stop',
            'tip': '',
          },
          'not a habit',
        ],
        'summary': 'Busy month!',
      },
      groupIds: {'s1', 's2', 's3'},
    )!;

    expect(insight.tags, {'s1': TxnTag.wasteful, 's2': TxnTag.necessary});
    expect(insight.habits, hasLength(1));
    expect(insight.habits.single.title, 'Delivery');
    expect(insight.habits.single.groupIds, ['s1']);
    expect(insight.habits.single.cut, Cut.half);
    expect(insight.summary, 'Busy month!');
    expect(insight.incomeNote, '');
  });

  test('anything but an object is no answer', () {
    expect(MonthInsight.fromJson('nope'), isNull);
    expect(MonthInsight.fromJson(null), isNull);
    expect(MonthInsight.fromJson(const <String, Object?>{})!.habits, isEmpty);
  });

  test('survives a round trip', () {
    const insight = MonthInsight(
      tags: {'s1': TxnTag.wasteful},
      habits: [
        InsightHabit(
          title: 'Stacked subscriptions',
          groupIds: ['s1'],
          cut: Cut.threeQuarters,
          tip: 'Keep one.',
        ),
      ],
      summary: 'Nice!',
      incomeNote: 'Steady as ever.',
      earnIdeas: ['Tutor juniors.', 'Freelance design.'],
    );
    final back = MonthInsight.fromJson(insight.toJson())!;
    expect(back.tags, insight.tags);
    expect(back.habits.single.cut, Cut.threeQuarters);
    expect(back.habits.single.title, 'Stacked subscriptions');
    expect(back.incomeNote, 'Steady as ever.');
    expect(back.earnIdeas, ['Tutor juniors.', 'Freelance design.']);
  });

  test('earning ideas: three at most, blanks and non-text dropped', () {
    final insight = MonthInsight.fromJson({
      'earnIdeas': ['  Tutor juniors.  ', '', 5, 'Freelance.', 'Campus job.'],
    })!;
    expect(insight.earnIdeas, ['Tutor juniors.']);
    expect(
      MonthInsight.fromJson(const <String, Object?>{})!.earnIdeas,
      isEmpty,
    );
  });

  test('cuts save whole quarters', () {
    expect(Cut.values.map((c) => c.quarters), [4, 3, 2, 1]);
    expect(Cut.fromWire('three_quarters'), Cut.threeQuarters);
    expect(Steadiness.fromWire('most_months'), Steadiness.mostMonths);
  });
}

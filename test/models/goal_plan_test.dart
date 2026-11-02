import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/goal_plan.dart';
import 'package:penny/models/month_insight.dart';

void main() {
  test('reads a plan, keeping only cuts that make sense', () {
    final plan = GoalPlan.fromJson(
      {
        'cuts': [
          {
            'title': ' Fewer delivery nights ',
            'groups': ['s1', 's9'],
            'cut': 'half',
            'tip': 'Cook twice a week.',
          },
          {
            'title': 'Odd',
            'groups': ['s2'],
            'cut': 'most',
            'tip': '',
          },
          {
            'title': 'Ghost',
            'groups': ['s9'],
            'cut': 'stop',
            'tip': '',
          },
          'not a cut',
        ],
        'summary': ' Delhi is within reach! ',
      },
      groupIds: {'s1', 's2'},
    )!;

    expect(plan.cuts, hasLength(1));
    expect(plan.cuts.single.title, 'Fewer delivery nights');
    expect(plan.cuts.single.groupIds, ['s1']);
    expect(plan.cuts.single.cut, Cut.half);
    expect(plan.summary, 'Delhi is within reach!');
  });

  test('anything but an object is no plan', () {
    expect(GoalPlan.fromJson('nope'), isNull);
    expect(GoalPlan.fromJson(const <String, Object?>{})!.cuts, isEmpty);
  });

  test('survives a round trip', () {
    const plan = GoalPlan(
      cuts: [
        InsightHabit(
          title: 'One streaming plan',
          groupIds: ['s3'],
          cut: Cut.stop,
          tip: 'Pause the one you open least.',
        ),
      ],
      summary: 'You can do it!',
    );
    final back = GoalPlan.fromJson(plan.toJson())!;
    expect(back.cuts.single.groupIds, ['s3']);
    expect(back.cuts.single.cut, Cut.stop);
    expect(back.cuts.single.tip, 'Pause the one you open least.');
    expect(back.summary, 'You can do it!');
  });

  test('rent, bills, subscriptions and education are paid in one go', () {
    expect(
      [
        for (final category in spendCategories)
          if (category.oneGo) category.id,
      ],
      ['bills', 'rent', 'subscriptions', 'education'],
    );
  });
}

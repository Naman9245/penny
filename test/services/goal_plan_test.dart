import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/goal_plan.dart';
import 'package:penny/models/month_insight.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/models/your_rules.dart';
import 'package:penny/services/goal_math.dart';
import 'package:penny/services/goal_plan.dart';

import '../helpers/txn_factory.dart';

void main() {
  // The 20th of November: October is the last full month.
  final now = DateTime(2026, 11, 20, 18);

  Goal goal({int rupees = 15000, DateTime? deadline}) => Goal(
    id: 'g1',
    title: 'Delhi trip',
    targetPaise: rupees * 100,
    // 87 days from the 20th of November: 13 weeks.
    deadline: deadline ?? DateTime(2027, 2, 15),
    createdAt: DateTime(2026, 11),
    updatedAt: DateTime(2026, 11),
  );

  GoalProgress progress({int savedRupees = 3000, Goal? of}) => GoalProgress(
    goal: of ?? goal(),
    savedPaise: savedRupees * 100,
    reachedOn: null,
  );

  final october = [
    txn(2400, DateTime(2026, 10, 3), merchant: 'Swiggy'),
    txn(
      649,
      DateTime(2026, 10, 5),
      categoryId: 'subscriptions',
      merchant: 'Netflix',
    ),
    txn(9000, DateTime(2026, 10, 1), categoryId: 'rent'),
  ];

  GoalPlanRequest? plan(
    List<Txn> txns, {
    DateTime? at,
    GoalProgress? of,
    YourRules rules = YourRules.none,
  }) => buildGoalPlanRequest(
    progress: of ?? progress(),
    txns: txns,
    now: at ?? now,
    rules: rules,
  );

  test('a plan goes by last month, with the goal in rupees', () {
    final request = plan([
      ...october,
      txn(500, DateTime(2026, 11, 2), merchant: 'Swiggy'),
    ])!;

    expect(request.month.month, DateTime(2026, 10));
    expect(request.goalId, 'g1');
    expect(request.goal, {
      'title': 'Delhi trip',
      'target': 15000,
      'saved': 3000,
      // ₹12,000 over 87 days, rounded up to the rupee.
      'weeksLeft': 13,
      'perWeek': 966,
      'perMonth': 4196,
    });
    final json = request.toJson();
    expect(json['v'], 1);
    expect(json['month'], request.month.body);
  });

  test("with no full month, this month will do after two weeks", () {
    final november = [
      txn(300, DateTime(2026, 11, 2), merchant: 'Swiggy'),
      txn(200, DateTime(2026, 11, 3), merchant: 'Swiggy'),
      txn(80, DateTime(2026, 11, 4)),
    ];
    expect(plan(november)!.month.month, DateTime(2026, 11));
    expect(plan(november, at: DateTime(2026, 11, 13)), isNull);
    expect(plan(const []), isNull);
  });

  test('nothing to plan once a goal is reached or its date has passed', () {
    final reached = GoalProgress(
      goal: goal(),
      savedPaise: 1500000,
      reachedOn: DateTime(2026, 11, 10),
    );
    expect(plan(october, of: reached), isNull);
    final missed = progress(of: goal(deadline: DateTime(2026, 11, 1)));
    expect(plan(october, of: missed), isNull);
  });

  test("the user's own needs go along as tags", () {
    final request = plan(
      october,
      rules: const YourRules(categories: {'rent': TxnTag.necessary}),
    )!;
    final rent = request.month.groupKeys.entries
        .firstWhere((e) => e.value.contains('cat|rent'))
        .key;
    expect(request.tags, {rent: TxnTag.necessary});
  });

  test('the fingerprint follows the target and date, not the money', () {
    final base = goalFingerprint(goal());
    expect(goalFingerprint(goal(rupees: 20000)), isNot(base));
    expect(goalFingerprint(goal(deadline: DateTime(2027, 3, 1))), isNot(base));
    expect(plan(october, of: progress(savedRupees: 9000))!.inputHash, base);
  });

  group('the plan in numbers', () {
    SavedGoalPlan saved(DateTime month, List<InsightHabit> cuts) =>
        SavedGoalPlan(
          goalId: 'g1',
          month: month,
          inputHash: 'hash',
          groupKeys: const {
            's1': ['shop|food|swiggy'],
            's2': ['shop|subscriptions|netflix'],
          },
          plan: GoalPlan(cuts: cuts, summary: ''),
          model: 'gemini-3.5-flash-lite',
          createdAt: now,
        );

    const halveDelivery = InsightHabit(
      title: '',
      groupIds: ['s1'],
      cut: Cut.half,
      tip: 'Cook twice a week.',
    );
    const dropStreaming = InsightHabit(
      title: 'One streaming plan',
      groupIds: ['s2'],
      cut: Cut.stop,
      tip: '',
    );

    test('each cut saves its share of a full month', () {
      final views = planCutViews(
        saved(DateTime(2026, 10), const [halveDelivery, dropStreaming]),
        october,
        now,
      );
      expect(views.map((v) => v.savePaise), [120000, 64900]);
      // A cut Penny left untitled is named after its shops.
      expect(views.first.title, 'Swiggy');
      expect(views.last.title, 'One streaming plan');
      expect(planSavingPaise(views), 184900);
    });

    test("a month still going is counted as a whole one", () {
      final views = planCutViews(
        saved(DateTime(2026, 11), const [halveDelivery]),
        [txn(1000, DateTime(2026, 11, 4), merchant: 'Swiggy')],
        now,
      );
      // ₹1,000 in 20 days is ₹1,500 over November's 30; half is ₹750.
      expect(views.single.savePaise, 75000);
    });
  });
}

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/goal_plan_repository.dart';
import 'package:penny/data/goal_repository.dart';
import 'package:penny/models/goal_plan.dart';
import 'package:penny/models/month_insight.dart';

void main() {
  late AppDatabase db;
  late GoalRepository goals;
  late GoalPlanRepository plans;
  late DateTime clock;

  setUp(() {
    clock = DateTime(2026, 11, 2, 10);
    db = AppDatabase(NativeDatabase.memory());
    goals = GoalRepository(db, clock: () => clock);
    plans = GoalPlanRepository(db, clock: () => clock);
  });

  tearDown(() => db.close());

  Future<String> delhiTrip() => goals.add(
    title: '  Delhi   trip ',
    targetPaise: 1500000,
    deadline: DateTime(2027, 2, 15, 18, 30),
  );

  const plan = GoalPlan(
    cuts: [
      InsightHabit(
        title: 'Fewer delivery nights',
        groupIds: ['s1'],
        cut: Cut.half,
        tip: 'Cook twice a week.',
      ),
    ],
    summary: 'Delhi is within reach!',
  );

  test('a goal keeps a tidy title and its deadline as a day', () async {
    await delhiTrip();
    final goal = (await goals.watchGoals().first).single;
    expect(goal.title, 'Delhi trip');
    expect(goal.targetPaise, 1500000);
    expect(goal.deadline, DateTime(2027, 2, 15));

    await goals.update(
      goal.id,
      title: 'x' * 50,
      targetPaise: 2000000,
      deadline: DateTime(2027, 3, 1),
    );
    final changed = (await goals.watchGoals().first).single;
    expect(changed.title, hasLength(GoalRepository.maxTitleLength));
    expect(changed.targetPaise, 2000000);
  });

  test('goals come soonest deadline first', () async {
    await delhiTrip();
    await goals.add(
      title: 'Headphones',
      targetPaise: 300000,
      deadline: DateTime(2026, 12, 1),
    );
    expect((await goals.watchGoals().first).map((g) => g.title), [
      'Headphones',
      'Delhi trip',
    ]);
  });

  test('money goes in and out, and a deleted entry can come back', () async {
    final id = await delhiTrip();
    await goals.deposit(id, 300000);
    clock = DateTime(2026, 11, 9);
    final out = await goals.deposit(id, -50000);

    var deposits = await goals.watchDeposits().first;
    expect(deposits.map((d) => d.amountPaise), [300000, -50000]);
    expect(deposits.last.occurredAt, DateTime(2026, 11, 9));

    await goals.deleteDeposit(out);
    deposits = await goals.watchDeposits().first;
    expect(deposits.map((d) => d.amountPaise), [300000]);

    await goals.restoreDeposit(out);
    expect(await goals.watchDeposits().first, hasLength(2));
  });

  test('deleting a goal takes its money and plan with it', () async {
    final id = await delhiTrip();
    final other = await goals.add(
      title: 'Headphones',
      targetPaise: 300000,
      deadline: DateTime(2026, 12, 1),
    );
    await goals.deposit(id, 300000);
    await goals.deposit(other, 10000);
    await plans.save(
      goalId: id,
      month: DateTime(2026, 10),
      inputHash: 'hash',
      groupKeys: const {
        's1': ['shop|food|swiggy'],
      },
      plan: plan,
      model: 'gemini-3.5-flash-lite',
    );

    await goals.delete(id);

    expect((await goals.watchGoals().first).single.id, other);
    expect((await goals.watchDeposits().first).single.goalId, other);
    expect(await plans.watch(id).first, isNull);
    // Soft deletes, so sync can carry them later.
    expect(await db.select(db.goals).get(), hasLength(2));
  });

  test(
    'a plan comes back as it was saved, and a new one replaces it',
    () async {
      final id = await delhiTrip();
      await plans.save(
        goalId: id,
        month: DateTime(2026, 10),
        inputHash: 'first',
        groupKeys: const {
          's1': ['shop|food|swiggy'],
        },
        plan: plan,
        model: 'gemini-3.5-flash-lite',
      );

      final saved = (await plans.watch(id).first)!;
      expect(saved.month, DateTime(2026, 10));
      expect(saved.inputHash, 'first');
      expect(saved.groupKeys, {
        's1': ['shop|food|swiggy'],
      });
      expect(saved.plan.cuts.single.cut, Cut.half);
      expect(saved.plan.summary, 'Delhi is within reach!');
      expect(saved.createdAt, clock);

      await plans.save(
        goalId: id,
        month: DateTime(2026, 11),
        inputHash: 'second',
        groupKeys: const {},
        plan: const GoalPlan(cuts: [], summary: 'Nothing to cut.'),
        model: 'gemini-3.5-flash-lite',
      );
      final replaced = (await plans.watch(id).first)!;
      expect(replaced.inputHash, 'second');
      expect(replaced.plan.cuts, isEmpty);
      expect(await db.select(db.goalPlans).get(), hasLength(1));
    },
  );
}

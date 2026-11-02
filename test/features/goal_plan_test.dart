import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/goal_repository.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/features/goals/goal_screen.dart';
import 'package:penny/models/goal_plan.dart';
import 'package:penny/models/month_insight.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/goal_plan.dart';
import 'package:penny/services/penny_ai.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_ai.dart';

void main() {
  final lastMonth = prevMonth(monthStart(DateTime.now()));
  DateTime on(int day) => DateTime(lastMonth.year, lastMonth.month, day, 13);

  // Last month: ₹2,400 of delivery, a ₹649 streaming plan and rent.
  Future<void> seedMonth(TxnRepository repo) async {
    await repo.add(
      amountPaise: 240000,
      type: TxnType.debit,
      categoryId: 'food',
      occurredAt: on(3),
      merchant: 'Swiggy',
    );
    await repo.add(
      amountPaise: 64900,
      type: TxnType.debit,
      categoryId: 'subscriptions',
      occurredAt: on(5),
      merchant: 'Netflix',
    );
    await repo.add(
      amountPaise: 900000,
      type: TxnType.debit,
      categoryId: 'rent',
      occurredAt: on(1),
    );
  }

  // ₹15,000 in 90 days: ₹5,070 a month, rounded up to the rupee.
  late String goalId;
  Future<void> seedGoal(AppDatabase db) async {
    goalId = await GoalRepository(db).add(
      title: 'Delhi trip',
      targetPaise: 1500000,
      deadline: DateTime.now().add(const Duration(days: 90)),
    );
  }

  GoalPlan pennyPlan(GoalPlanRequest request) => GoalPlan(
    cuts: [
      InsightHabit(
        title: 'Fewer delivery nights',
        groupIds: [groupId(request.month, shop: 'Swiggy')],
        cut: Cut.half,
        tip: 'Cook twice a week.',
      ),
      InsightHabit(
        title: 'One streaming plan',
        groupIds: [
          groupId(request.month, shop: 'Netflix', categoryId: 'subscriptions'),
        ],
        cut: Cut.stop,
        tip: 'Pause it for a month.',
      ),
    ],
    summary: 'Delhi is within reach!',
  );

  Future<void> openGoal(WidgetTester tester) async {
    routerOf(tester).push('/goals/$goalId');
    await tester.pumpAndSettle();
  }

  // A goal's page is a lazy list: rows further down only exist once
  // scrolled to.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find
          .descendant(
            of: find.byType(GoalScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> planWithPenny(WidgetTester tester) async {
    final ask = find.byKey(const ValueKey('plan-goal'));
    await reveal(tester, ask);
    await tester.tap(ask);
    await tester.pumpAndSettle();
  }

  testWidgets('Plan with Penny: cuts with what each saves a month', (
    tester,
  ) async {
    final ai = FakeAiClient(plan: pennyPlan);
    final db = await pumpApp(tester, seed: seedMonth, seedDb: seedGoal, ai: ai);
    await openGoal(tester);
    await planWithPenny(tester);

    final sent = ai.plans.single;
    expect(sent.month.month, lastMonth);
    expect(sent.goal['title'], 'Delhi trip');
    expect(sent.goal['perMonth'], 5070);
    expect(find.text('Delhi is within reach!'), findsOneWidget);

    await reveal(tester, find.byKey(const ValueKey('plan-total')));
    expect(find.text('About ₹1,200 a month'), findsOneWidget);
    expect(find.text('About ₹649 a month'), findsOneWidget);
    expect(
      find.text('About ₹1,849 of the ₹5,070 a month you need.'),
      findsOneWidget,
    );

    final seeSent = find.byKey(const ValueKey('plan-see-sent'));
    await reveal(tester, seeSent);
    await tester.tap(seeSent);
    await tester.pumpAndSettle();
    expect(find.text('Your goal'), findsOneWidget);
    expect(find.byKey(const ValueKey('sent-goal')), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('a changed goal marks the plan as old', (tester) async {
    final db = await pumpApp(
      tester,
      seed: seedMonth,
      seedDb: seedGoal,
      ai: FakeAiClient(plan: pennyPlan),
    );
    await openGoal(tester);
    await planWithPenny(tester);
    expect(find.text('Your goal changed since Penny planned.'), findsNothing);

    routerOf(tester).push('/goals/$goalId/edit');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal-target')));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('key-⌫')));
    for (final digit in '20000'.split('')) {
      await tester.tap(find.byKey(ValueKey('key-$digit')));
    }
    await tester.tap(find.byKey(const ValueKey('key-done')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-goal')));
    await tester.pumpAndSettle();

    await reveal(tester, find.text('Your goal changed since Penny planned.'));
    await closeApp(tester, db);
  });

  testWidgets('with no spending yet, Penny says what she needs', (
    tester,
  ) async {
    final db = await pumpApp(tester, seedDb: seedGoal, ai: FakeAiClient());
    await openGoal(tester);
    await reveal(tester, find.byKey(const ValueKey('plan-ask')));
    expect(
      find.text(
        'Log two weeks of spending first, so Penny has something to go by.',
      ),
      findsOneWidget,
    );
    await closeApp(tester, db);
  });

  testWidgets('the daily limit for plans is its own', (tester) async {
    final db = await pumpApp(
      tester,
      seed: seedMonth,
      seedDb: seedGoal,
      ai: FakeAiClient(
        failure: const AiException(AiFailure.dailyLimit, limit: 10),
      ),
    );
    await openGoal(tester);
    await planWithPenny(tester);
    expect(
      find.text('Penny can plan 10 times a day. Try again tomorrow.'),
      findsOneWidget,
    );
    await closeApp(tester, db);
  });
}

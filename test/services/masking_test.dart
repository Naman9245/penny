import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/chat.dart';
import 'package:penny/services/goal_math.dart';
import 'package:penny/services/goal_plan.dart';
import 'package:penny/services/insight_builder.dart';
import 'package:penny/services/penny_ai.dart';

import '../helpers/txn_factory.dart';

// Long numbers (phone, account and card numbers) are hidden before anything
// leaves the phone, the same way the server hides them again.
void main() {
  final now = DateTime(2026, 11, 20, 18);

  test('long numbers go, amounts with commas stay', () {
    expect(maskLongNumbers('call 98765 43210'), 'call •••');
    expect(maskLongNumbers('card 4111-1111-1111-1111'), 'card •••');
    expect(maskLongNumbers('acc 123456789012'), 'acc •••');
    expect(
      maskLongNumbers('rent 15000, earn 1,20,000'),
      'rent 15000, earn 1,20,000',
    );
    expect(maskLongNumbers('12345678 is eight'), '12345678 is eight');
  });

  test("the note goes with them hidden", () {
    final request = buildInsightRequest(
      month: DateTime(2026, 10),
      txns: [txn(250, DateTime(2026, 10, 2))],
      now: now,
      note: 'PG in Bengaluru, call me on 98765 43210',
    );
    expect(request.body['note'], 'PG in Bengaluru, call me on •••');
  });

  test("a goal's title goes with them hidden, in a plan and the chat", () {
    final goal = Goal(
      id: 'g1',
      title: 'Fees 4111 1111 1111',
      targetPaise: 1500000,
      deadline: DateTime(2027, 2, 15),
      createdAt: DateTime(2026, 11),
      updatedAt: DateTime(2026, 11),
      dirty: false,
    );
    final progress = GoalProgress(
      goal: goal,
      savedPaise: 300000,
      reachedOn: null,
    );
    final plan = buildGoalPlanRequest(
      progress: progress,
      // A plan needs a few spends to go by.
      txns: [
        txn(2400, DateTime(2026, 10, 3), merchant: 'Swiggy'),
        txn(649, DateTime(2026, 10, 5), categoryId: 'subscriptions'),
        txn(9000, DateTime(2026, 10, 1), categoryId: 'rent'),
      ],
      now: now,
    )!;
    expect(plan.goal['title'], 'Fees •••');

    final chat = ChatRequest(
      month: plan.month,
      tags: const {},
      goals: [chatGoalOf(progress, now)],
      turns: const [
        (role: ChatRole.user, text: 'My account 123456789012 got charged'),
        (role: ChatRole.penny, text: 'Oh no, what happened?'),
        (role: ChatRole.user, text: 'I spend 5000 on food'),
      ],
    ).toJson();
    final goals = (chat['goals']! as List).cast<Map<String, Object?>>();
    expect(goals.single['title'], 'Fees •••');
    final messages = (chat['messages']! as List).cast<Map<String, Object?>>();
    expect(
      [for (final m in messages) m['text']],
      [
        'My account ••• got charged',
        'Oh no, what happened?',
        'I spend 5000 on food',
      ],
    );
  });
}

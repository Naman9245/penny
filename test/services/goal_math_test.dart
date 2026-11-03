import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/services/goal_math.dart';

void main() {
  final today = DateTime(2026, 11, 2, 15);
  var next = 0;

  Goal goal({int rupees = 15000, DateTime? deadline, String id = 'g1'}) => Goal(
    id: id,
    title: 'Delhi trip',
    targetPaise: rupees * 100,
    // 105 days from the 2nd of November: 15 weeks.
    deadline: deadline ?? DateTime(2027, 2, 15),
    createdAt: DateTime(2026, 11),
    updatedAt: DateTime(2026, 11),
  );

  GoalDeposit money(int rupees, DateTime at, {String goalId = 'g1'}) =>
      GoalDeposit(
        id: 'd${next++}',
        goalId: goalId,
        amountPaise: rupees * 100,
        occurredAt: at,
        createdAt: at,
        updatedAt: at,
      );

  GoalProgress progressOf(List<GoalDeposit> deposits, {Goal? of}) =>
      goalProgress([of ?? goal()], deposits).single;

  test('money in and out adds up, and only for its own goal', () {
    final progress = progressOf([
      money(5000, DateTime(2026, 11, 1)),
      money(-1000, DateTime(2026, 11, 2)),
      money(9999, DateTime(2026, 11, 2), goalId: 'other'),
    ]);
    expect(progress.savedPaise, 400000);
    expect(progress.toGoPaise, 1100000);
    expect(progress.progress, closeTo(4 / 15, 0.0001));
    expect(progress.reached, isFalse);
  });

  test('the day it was reached is the last time money crossed the target', () {
    final reached = progressOf([
      money(10000, DateTime(2026, 11, 1)),
      money(6000, DateTime(2026, 11, 5, 20)),
    ]);
    expect(reached.reachedOn, DateTime(2026, 11, 5));
    expect(reached.toGoPaise, 0);
    expect(reached.progress, 1);

    final droppedBack = progressOf([
      money(16000, DateTime(2026, 11, 1)),
      money(-2000, DateTime(2026, 11, 3)),
    ]);
    expect(droppedBack.reached, isFalse);

    final again = progressOf([
      money(16000, DateTime(2026, 11, 1)),
      money(-2000, DateTime(2026, 11, 3)),
      money(1000, DateTime(2026, 11, 8)),
    ]);
    expect(again.reachedOn, DateTime(2026, 11, 8));
  });

  test('what is still needed each week and month, to the rupee above', () {
    final progress = progressOf([money(3000, DateTime(2026, 11, 1))]);
    expect(progress.daysLeft(today), 105);
    expect(progress.weeksLeft(today), 15);
    // ₹12,000 over 15 weeks is ₹800; over 105 days, ₹3,476.19 a month.
    expect(progress.perWeekPaise(today), 80000);
    expect(progress.perMonthPaise(today), 347700);
  });

  test('close to the deadline, a week needs all that is left', () {
    final soon = progressOf(
      const [],
      of: goal(deadline: DateTime(2026, 11, 5)),
    );
    expect(soon.weeksLeft(today), 1);
    expect(soon.perWeekPaise(today), 1500000);
  });

  test('a reached or missed goal needs nothing more', () {
    final reached = progressOf([money(15000, DateTime(2026, 11, 1))]);
    expect(reached.perWeekPaise(today), 0);

    final missed = progressOf([
      money(100, DateTime(2026, 10, 1)),
    ], of: goal(deadline: DateTime(2026, 10, 31)));
    expect(missed.isMissed(today), isTrue);
    expect(missed.perWeekPaise(today), 0);
    expect(missed.perMonthPaise(today), 0);
  });

  test('Penny celebrates a goal on the day it was reached', () {
    GoalProgress reachedOn(DateTime day) => progressOf([money(15000, day)]);
    expect(justReached([reachedOn(DateTime(2026, 11, 2, 9))], today), isTrue);
    // Like the mood calendar, where only that day is sky blue.
    expect(justReached([reachedOn(DateTime(2026, 11, 1, 22))], today), isFalse);
    expect(justReached(const [], today), isFalse);
  });

  test("she names the goal reached today, not yesterday's", () {
    final both = goalProgress(
      [goal(id: 'a'), goal(id: 'b')],
      [
        money(15000, DateTime(2026, 11, 2, 9), goalId: 'b'),
        money(15000, DateTime(2026, 11, 1, 22), goalId: 'a'),
      ],
    );
    expect(justReachedGoal(both, today)?.goal.id, 'b');
    expect(justReachedGoal(both.take(1), today), isNull);
  });

  test('saved in a month counts money in, less taken out', () {
    final deposits = [
      money(500, DateTime(2026, 10, 31, 23)),
      money(3000, DateTime(2026, 11, 1)),
      money(-200, DateTime(2026, 11, 2)),
      money(700, DateTime(2026, 12, 1)),
    ];
    expect(
      savedBetween(deposits, DateTime(2026, 11), DateTime(2026, 12)),
      280000,
    );
  });
}

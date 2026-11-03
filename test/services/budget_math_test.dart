import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/budget.dart';
import 'package:penny/models/penny_mood.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/budget_math.dart';

import '../helpers/txn_factory.dart';

void main() {
  // November has 30 days; the 10th is a third of the way through.
  final month = DateTime(2026, 11);
  final tenth = DateTime(2026, 11, 10, 20);
  DateTime on(int day, [int hour = 12]) => DateTime(2026, 11, day, hour);

  BudgetStatus status(Budget budget, List<Txn> txns, {DateTime? now}) =>
      budgetStatus(
        budget: budget,
        monthTxns: txns,
        month: month,
        now: now ?? tenth,
      );

  // ₹9,000 of everyday budget, all of it for food: a share of ₹300 a day.
  const budget = Budget(byCategory: {'food': 900000});

  Map<int, PennyMood> moods(
    List<Txn> txns, {
    Budget budget = budget,
    Set<DateTime> goalDays = const {},
  }) => dayMoods(
    budget: budget,
    monthTxns: txns,
    month: month,
    now: tenth,
    firstEntry: on(1),
    goalDays: goalDays,
  );

  /// Penny on Home on the 10th: the 10th's square on the calendar.
  PennyMood today(List<Txn> txns, {Budget budget = budget}) =>
      moods(txns, budget: budget)[10] ?? PennyMood.neutral;

  group('where the month stands', () {
    test('only budgeted everyday categories count, never one-go ones', () {
      final month = status(
        const Budget(byCategory: {'food': 600000, 'rent': 800000}),
        [
          txn(400, on(2)),
          txn(150, on(3), categoryId: 'travel'), // No budget.
          txn(8000, on(1), categoryId: 'rent'),
          txn(15000, on(1), type: TxnType.credit, categoryId: 'pocket_money'),
        ],
      );
      expect(month.everydaySpentPaise, 40000);
      expect(month.spentIn('rent'), 800000);
      expect(month.spentIn('travel'), 15000);
      expect(month.spentIn('pocket_money'), 0);
      expect(month.daysLeft, 20);
    });

    test("today's spending and share, as Home shows them", () {
      final month = status(budget, [
        txn(250, on(10, 9)),
        txn(100, on(10, 10), categoryId: 'travel'), // No budget.
        txn(400, on(9)),
      ]);
      expect(month.todaySpentPaise, 25000);
      expect(month.everydaySpentPaise, 65000);
      expect(month.sharePaise, 30000);
    });

    test('an everyday category over or near its budget is named', () {
      const split = Budget(
        byCategory: {'food': 200000, 'fun': 100000, 'rent': 800000},
      );
      expect(status(split, [txn(500, on(4))]).categoryNote, isNull);
      expect(
        status(split, [txn(1800, on(4))]).categoryNote,
        'Food is near its budget',
      );
      expect(
        status(split, [
          txn(1800, on(4)),
          txn(1200, on(5), categoryId: 'fun'),
        ]).categoryNote,
        'Fun is over its budget',
      );
    });

    test('rent going over its budget is noted, never named as the mood', () {
      const rent = Budget(byCategory: {'food': 900000, 'rent': 800000});
      final paid = status(rent, [txn(8000, on(1), categoryId: 'rent')]);
      expect(paid.oneGoNote, isNull);
      final over = status(rent, [txn(8500, on(1), categoryId: 'rent')]);
      expect(over.oneGoNote, 'Rent & PG went ₹500 over its budget');
      expect(over.categoryNote, isNull);
    });

    test('a month that is over counts every day', () {
      final done = status(budget, [
        txn(8000, on(29)),
      ], now: DateTime(2026, 12, 3));
      expect(done.day, 30);
      expect(done.daysLeft, 0);
    });
  });

  group("each day's mood, and today's on Home", () {
    test('no budget at all leaves Penny neutral, with no days', () {
      expect(today([txn(5000, on(2))], budget: Budget.none), PennyMood.neutral);
      expect(moods([txn(5000, on(2))], budget: Budget.none), isEmpty);
    });

    test('each day against its share: 1× happy, 1.5× worried, more sad', () {
      final days = moods([
        txn(300, on(2)),
        txn(301, on(3)),
        txn(450, on(4)),
        txn(451, on(5)),
        txn(8000, on(7), categoryId: 'rent'),
        txn(5000, on(8), categoryId: 'shopping'),
      ]);
      expect(days[2], PennyMood.happy);
      expect(days[3], PennyMood.worried);
      expect(days[4], PennyMood.worried);
      expect(days[5], PennyMood.sad);
      // Nothing spent is a good day; rent and categories without a budget
      // stay out.
      expect(days[6], PennyMood.happy);
      expect(days[7], PennyMood.happy);
      expect(days[8], PennyMood.happy);
    });

    test("Home goes by today's spending too", () {
      expect(today(const []), PennyMood.happy);
      expect(today([txn(300, on(10, 9))]), PennyMood.happy);
      expect(today([txn(301, on(10, 9))]), PennyMood.worried);
      expect(today([txn(451, on(10, 9))]), PennyMood.sad);
    });

    test('85% of the everyday budget worries every day after, over it '
        'saddens them', () {
      // Spent on the 4th, so the 10th spent nothing itself.
      expect(today([txn(7649, on(4))]), PennyMood.happy);
      expect(today([txn(7650, on(4))]), PennyMood.worried);
      expect(today([txn(9001, on(4))]), PennyMood.sad);

      final days = moods([txn(2000, on(2)), txn(6000, on(6))]);
      // Under 85% until the 6th, which is sad by its own spending.
      expect(days[3], PennyMood.happy);
      expect(days[6], PennyMood.sad);
      expect(days[7], PennyMood.worried);
      expect(days[10], PennyMood.worried);
    });

    test('a category over its amount saddens the days after; near it is '
        'only a note', () {
      const split = Budget(byCategory: {'food': 200000, 'fun': 700000});
      expect(today([txn(1800, on(4))], budget: split), PennyMood.happy);
      expect(today([txn(2001, on(4))], budget: split), PennyMood.sad);
    });

    test('rent never changes the mood, even over its budget', () {
      const rent = Budget(byCategory: {'food': 900000, 'rent': 800000});
      expect(
        today([txn(8500, on(10, 9), categoryId: 'rent')], budget: rent),
        PennyMood.happy,
      );
    });

    test('no mood before the first entry or after today', () {
      final days = dayMoods(
        budget: budget,
        monthTxns: [txn(100, on(2))],
        month: month,
        now: tenth,
        firstEntry: on(2),
      );
      expect(days.keys, [2, 3, 4, 5, 6, 7, 8, 9, 10]);
    });

    test('today has a mood before anything is logged', () {
      expect(
        dayMoods(budget: budget, monthTxns: const [], month: month, now: tenth),
        {10: PennyMood.happy},
      );
    });

    test('a day a goal was reached celebrates, budget or not', () {
      final goalDay = {DateTime(2026, 11, 8)};
      expect(moods(const [], goalDays: goalDay)[8], PennyMood.celebrating);
      expect(moods(const [], budget: Budget.none, goalDays: goalDay), {
        8: PennyMood.celebrating,
      });
    });

    test('the month sums up as the mood most days had', () {
      expect(moodSummary(const {}), isNull);
      final summary = moodSummary({
        1: PennyMood.sad,
        2: PennyMood.happy,
        3: PennyMood.sad,
        4: PennyMood.celebrating,
        5: PennyMood.celebrating,
        6: PennyMood.celebrating,
      })!;
      // Goal days don't count towards "mostly".
      expect(summary.mostly, PennyMood.sad);
      expect(summary.counts, {
        PennyMood.sad: 2,
        PennyMood.happy: 1,
        PennyMood.celebrating: 3,
      });
      // A tie goes to the kinder mood.
      expect(
        moodSummary({1: PennyMood.sad, 2: PennyMood.worried})!.mostly,
        PennyMood.worried,
      );
      expect(
        moodSummary({1: PennyMood.celebrating})!.mostly,
        PennyMood.celebrating,
      );
    });

    test('the daily share is to the rupee', () {
      expect(dailySharePaise(900000, month), 30000);
      expect(dailySharePaise(800000, month), 26700);
    });
  });

  group('the numbers behind a day', () {
    test('the month so far is named when it made the day worse', () {
      String? note(List<Txn> txns, int day, {Budget budget = budget}) =>
          monthNoteOn(budget: budget, monthTxns: txns, date: on(day, 0));

      final big = [txn(8000, on(4)), txn(100, on(6))];
      // The 4th is sad by its own spending; the 6th is worried by the month.
      expect(note(big, 4), isNull);
      expect(note(big, 6), 'Everyday budget so far: ₹8,100 of ₹9,000');
      expect(note(big, 3), isNull);

      const split = Budget(byCategory: {'food': 200000, 'fun': 700000});
      final food = [txn(2100, on(3))];
      expect(note(food, 3, budget: split), isNull);
      expect(note(food, 5, budget: split), 'Food so far: ₹2,100 of ₹2,000');

      expect(note(big, 6, budget: Budget.none), isNull);
    });

    test("a day's spending splits the way Penny counts it", () {
      final spend = splitDaySpending(
        const Budget(byCategory: {'food': 900000, 'rent': 800000}),
        [
          txn(250, on(3)),
          txn(100, on(3), categoryId: 'travel'), // No budget.
          txn(8000, on(3), categoryId: 'rent'),
          txn(60, on(3), categoryId: 'bills'), // One go, no budget.
          txn(1000, on(3), type: TxnType.credit, categoryId: 'pocket_money'),
        ],
      );
      expect(spend, (counted: 25000, noBudget: 10000, oneGo: 806000));
    });
  });

  test('days left read naturally', () {
    expect(daysLeftLabel(18), '18 days left');
    expect(daysLeftLabel(1), '1 day left');
    expect(daysLeftLabel(0), 'Last day');
  });
}

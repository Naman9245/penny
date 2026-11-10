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

    test('what came back comes off its category; investing never counts', () {
      final month = status(budget, [
        txn(900, on(2)),
        txn(600, on(3), type: TxnType.credit), // Friends paid back for food.
        txn(5000, on(4), categoryId: 'invest'),
        txn(100, on(5), type: TxnType.credit, categoryId: 'travel'),
      ]);
      expect(month.spentIn('food'), 30000);
      expect(month.everydaySpentPaise, 30000);
      // Never below zero, with nothing spent on travel.
      expect(month.spentIn('travel'), 0);
      expect(month.spentIn('invest'), 0);
    });

    test("a payback leaves a day's own spending as it was paid", () {
      final day = status(budget, [
        txn(900, on(10)),
        txn(600, on(10, 21), type: TxnType.credit),
      ]);
      expect(day.todaySpentPaise, 90000);
      expect(day.everydaySpentPaise, 30000);
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

    test('the month so far never colours a quiet day', () {
      // Spent on the 4th, so the 10th spent nothing itself.
      expect(today([txn(7650, on(4))]), PennyMood.happy);
      expect(today([txn(9001, on(4))]), PennyMood.happy);

      final days = moods([txn(2000, on(2)), txn(6000, on(6))]);
      expect(days[3], PennyMood.happy);
      expect(days[6], PennyMood.sad);
      expect(days[7], PennyMood.happy);
      expect(days[10], PennyMood.happy);
    });

    test('a category over its budget never saddens a day with nothing spent',
        () {
      const split = Budget(byCategory: {'food': 200000, 'fun': 700000});
      final over = [txn(2174, on(4))];
      expect(moods(over, budget: split)[4], PennyMood.sad);
      expect(today(over, budget: split), PennyMood.happy);
    });

    test('money back later never changes the day it was paid for', () {
      final txns = [
        txn(8100, on(1)),
        txn(3000, on(2), type: TxnType.credit),
        txn(5000, on(3), categoryId: 'invest'),
      ];
      final days = moods(txns);
      expect(days[1], PennyMood.sad);
      expect(days[2], PennyMood.happy);
      expect(days[3], PennyMood.happy);
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

    test("the month goes by its average day against the share", () {
      // ₹150 a day: ₹4,500 for groceries over November's 30 days.
      const groceries = Budget(byCategory: {'groceries': 450000});
      MonthMood? month0(List<Txn> txns, {Budget budget = groceries}) {
        final days = dayMoods(
          budget: budget,
          monthTxns: txns,
          month: month,
          now: tenth,
          firstEntry: on(6),
        );
        return monthMood(
          budget: budget,
          monthTxns: txns,
          month: month,
          moods: days,
        );
      }

      // ₹2,573 over the 6th to the 10th: ₹515 a day, well over ₹150.
      final spent = [
        txn(1500, on(6), categoryId: 'groceries'),
        txn(674, on(7), categoryId: 'groceries'),
        txn(399, on(8), categoryId: 'groceries'),
        txn(300, on(9), categoryId: 'people'), // No budget.
      ];
      final sad = month0(spent)!;
      expect(sad.mood, PennyMood.sad);
      expect(sad.spentPaise, 257300);
      expect(sad.days, 5);
      expect(sad.averagePaise, 51500);
      expect(sad.counts, {PennyMood.sad: 3, PennyMood.happy: 2});
      expect(sad.categoryNotes, isEmpty);

      // Within the share on average, though one day went over.
      final fine = month0([txn(600, on(6), categoryId: 'groceries')])!;
      expect(fine.mood, PennyMood.happy);
      expect(fine.averagePaise, 12000);
      expect(fine.counts, {PennyMood.sad: 1, PennyMood.happy: 4});

      // Up to one and a half times the share is worried.
      expect(
        month0([txn(1125, on(6), categoryId: 'groceries')])!.mood,
        PennyMood.worried,
      );

      // A category over its own budget is named, then one near it.
      const split = Budget(
        byCategory: {'groceries': 200000, 'food': 100000, 'fun': 200000},
      );
      final notes = month0([
        txn(2174, on(6), categoryId: 'groceries'),
        txn(900, on(7), categoryId: 'food'),
      ], budget: split)!.categoryNotes;
      expect(notes, ['Groceries: ₹2,174 of ₹2,000', 'Food: ₹900 of ₹1,000']);

      expect(month0(spent, budget: Budget.none), isNull);
    });

    test("Home's line is about today", () {
      expect(
        homeLine(PennyMood.happy, todaySpentPaise: 0),
        'Nothing spent today. Nice!',
      );
      expect(
        homeLine(PennyMood.happy, todaySpentPaise: 10000),
        "Today's within your share. Keep it up!",
      );
      expect(
        homeLine(PennyMood.worried, todaySpentPaise: 20000),
        "Today's a bit over your share.",
      );
      expect(
        homeLine(PennyMood.sad, todaySpentPaise: 50000),
        "Today went well over your share. Let's plan a fix!",
      );
      expect(
        homeLine(PennyMood.neutral, todaySpentPaise: 0),
        PennyMood.neutral.line,
      );
    });

    test('the daily share is to the rupee', () {
      expect(dailySharePaise(900000, month), 30000);
      expect(dailySharePaise(800000, month), 26700);
    });
  });

  group('the numbers behind a day', () {
    test("a day's spending splits the way Penny counts it", () {
      final spend = splitDaySpending(
        const Budget(byCategory: {'food': 900000, 'rent': 800000}),
        [
          txn(250, on(3)),
          txn(100, on(3), categoryId: 'travel'), // No budget.
          txn(8000, on(3), categoryId: 'rent'),
          txn(60, on(3), categoryId: 'bills'), // One go, no budget.
          txn(1000, on(3), type: TxnType.credit, categoryId: 'pocket_money'),
          txn(120, on(3), type: TxnType.credit), // Paid back for food.
          txn(1000, on(3), categoryId: 'invest'),
        ],
      );
      expect(spend, (
        counted: 25000,
        noBudget: 10000,
        oneGo: 806000,
        cameBack: 12000,
        invested: 100000,
      ));
    });
  });

  group('where the month is heading', () {
    // ₹9,000 of everyday budget over November's 30 days; on the 10th.
    String? forecast(List<Txn> txns, {Budget budget = budget, int day = 10}) =>
        status(budget, txns, now: on(day, 20)).forecast;

    test('within the everyday budget: what will be left', () {
      expect(
        forecast([txn(2000, on(4))]),
        "At ₹200 a day, you'll end with ₹3,000 of your everyday budget to "
        'spare',
      );
      expect(
        forecast([txn(3000, on(4))]),
        "At ₹300 a day, you'll end right at your everyday budget",
      );
    });

    test('faster than the budget: the day it runs out', () {
      expect(
        forecast([txn(4000, on(4))]),
        'At ₹400 a day, your everyday budget runs out around 23 Nov',
      );
    });

    test('already over: by how much it will end over', () {
      expect(
        forecast([txn(9500, on(4))]),
        "At ₹950 a day, you'll end about ₹19,500 over your everyday budget",
      );
    });

    test('with no everyday budget, where spending leads', () {
      expect(
        forecast([
          txn(3800, on(4)),
          // Paid in one go, so it's no pace.
          txn(8000, on(1), categoryId: 'rent'),
        ], budget: Budget.none),
        'At ₹380 a day, about ₹11,400 this month',
      );
    });

    test('paybacks come off the pace; investing is no spending', () {
      expect(
        forecast([
          txn(3000, on(4)),
          txn(1000, on(5), type: TxnType.credit),
          txn(5000, on(6), categoryId: 'invest'),
        ]),
        "At ₹200 a day, you'll end with ₹3,000 of your everyday budget to "
        'spare',
      );
    });

    test('only from the 3rd to the second-last day, with spending', () {
      final spent = [txn(500, on(1))];
      expect(forecast(spent, day: 2), isNull);
      expect(forecast(spent, day: 3), isNotNull);
      expect(forecast([txn(500, on(1))], day: 29), isNotNull);
      expect(forecast(spent, day: 30), isNull);
      expect(forecast(const []), isNull);
    });
  });

  test('days left read naturally', () {
    expect(daysLeftLabel(18), '18 days left');
    expect(daysLeftLabel(1), '1 day left');
    expect(daysLeftLabel(0), 'Last day');
  });
}

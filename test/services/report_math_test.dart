import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/report_math.dart';

import '../helpers/txn_factory.dart';

void main() {
  // November 2026 starts on a Sunday; "now" is Saturday the 7th, so the
  // month so far has 5 weekdays and 2 weekend days.
  final now = DateTime(2026, 11, 7, 12);
  DateTime nov(int day, int hour) => DateTime(2026, 11, day, hour);

  final october = [
    txn(300, DateTime(2026, 10, 10, 21), merchant: 'Swiggy'),
    txn(8000, DateTime(2026, 10, 1, 10), categoryId: 'rent'),
    txn(
      15000,
      DateTime(2026, 10, 1, 9),
      type: TxnType.credit,
      categoryId: 'salary',
    ),
  ];
  final november = [
    txn(20000, nov(1, 9), type: TxnType.credit, categoryId: 'salary'),
    txn(8000, nov(1, 10), categoryId: 'rent'), // Sunday morning
    txn(200, nov(2, 23), merchant: 'Swiggy'), // Monday late night
    txn(150, nov(3, 13), merchant: 'Zomato'), // Tuesday afternoon
    // ₹50 back from Swiggy.
    txn(50, nov(4, 12), type: TxnType.credit, merchant: 'Swiggy'),
    txn(1000, nov(5, 10), categoryId: 'invest', merchant: 'Groww'),
    txn(
      500,
      nov(6, 19), // Friday evening
      merchant: 'Asha Rao',
      categoryId: 'other',
      payeeIsPerson: true,
    ),
    txn(50, nov(7, 8), merchant: 'Chai Point'), // Saturday morning
  ];
  final report = MoneyReport.of(
    month: DateTime(2026, 11),
    txns: [...october, ...november],
    now: now,
  );

  test('the month adds up as Home counts it', () {
    expect(report.totals.spentPaise, 885000);
    expect(report.totals.gotPaise, 2000000);
    expect(report.totals.investedPaise, 100000);
    expect(report.totals.leftPaise, 1015000);
  });

  test('each category: its spending, share, count and biggest shop', () {
    final ids = [for (final c in report.categories) c.categoryId];
    expect(ids, ['rent', 'other', 'food']);
    final food = report.categories.last;
    expect(food.spentPaise, 35000, reason: 'money back comes off');
    expect(food.count, 3);
    expect(food.topShop, 'Swiggy');
    expect(food.share, closeTo(350 / 8850, 1e-9));
    expect(report.categories.first.topShop, 'Rent & PG');
  });

  test('top shops and people, and the biggest spends', () {
    expect(
      [for (final s in report.shops) s.name],
      ['Rent & PG', 'Asha Rao', 'Swiggy', 'Zomato', 'Chai Point'],
    );
    expect(report.shops[1].isPerson, isTrue);
    expect(report.shops[2].isPerson, isFalse);
    expect(
      [for (final b in report.biggest) b.paise ~/ 100],
      [8000, 500, 200, 150, 50],
    );
    expect(report.biggest.first.at, nov(1, 10));
  });

  test('month by month, and money kept so far', () {
    expect([for (final m in report.history) m.month], [
      DateTime(2026, 10),
      DateTime(2026, 11),
    ]);
    expect(report.history.first.spentPaise, 830000);
    expect(report.history.first.leftPaise, 670000);
    expect(report.savedSoFarPaise, 670000 + 1015000);
  });

  test('categories against last month, biggest change first', () {
    expect([
      for (final c in report.changes) (c.categoryId, c.nowPaise, c.beforePaise),
    ], [('other', 50000, 0), ('food', 35000, 30000)]);
  });

  test('shops paid for the first time', () {
    expect(report.newShops.toSet(), {'Zomato', 'Asha Rao', 'Chai Point'});
  });

  test('when the money goes', () {
    final p = report.patterns;
    expect(p.byWeekdayPaise, [20000, 15000, 0, 0, 50000, 5000, 800000]);
    expect(p.byPartPaise, {
      DayPart.morning: 805000,
      DayPart.afternoon: 15000,
      DayPart.evening: 50000,
      DayPart.lateNight: 20000,
    });
    expect(p.weekendAveragePaise, 805000 ~/ 2);
    expect(p.weekdayAveragePaise, 85000 ~/ 5);
    expect(p.smallCount, 1);
    expect(p.smallPaise, 5000);
  });

  test('a month that is over counts all its days', () {
    final past = MoneyReport.of(
      month: DateTime(2026, 10),
      txns: october,
      now: now,
    );
    // October 2026: 22 weekdays, 9 weekend days; Swiggy on Saturday the 10th.
    expect(past.patterns.weekdayAveragePaise, 800000 ~/ 22);
    expect(past.patterns.weekendAveragePaise, 30000 ~/ 9);
  });

  test('with no month before, nothing to compare', () {
    final first = MoneyReport.of(
      month: DateTime(2026, 10),
      txns: [...october, ...november],
      now: now,
    );
    expect(first.history, hasLength(1));
    expect(first.changes, isEmpty);
    expect(first.newShops, isEmpty);
  });

  test('history goes back 12 months at most', () {
    final long = MoneyReport.of(
      month: DateTime(2026, 11),
      txns: [txn(10, DateTime(2024, 3, 5)), ...november],
      now: now,
    );
    expect(long.history, hasLength(historyMonths));
    expect(long.history.first.month, DateTime(2025, 12));
  });

  test('day parts', () {
    expect(DayPart.of(DateTime(2026, 1, 1, 4, 59)), DayPart.lateNight);
    expect(DayPart.of(DateTime(2026, 1, 1, 5)), DayPart.morning);
    expect(DayPart.of(DateTime(2026, 1, 1, 12)), DayPart.afternoon);
    expect(DayPart.of(DateTime(2026, 1, 1, 17)), DayPart.evening);
    expect(DayPart.of(DateTime(2026, 1, 1, 22)), DayPart.lateNight);
  });
}

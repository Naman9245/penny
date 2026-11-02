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
  DateTime on(int day) => DateTime(2026, 11, day, 12);

  BudgetStatus status(Budget budget, List<Txn> txns, {DateTime? now}) =>
      budgetStatus(
        budget: budget,
        monthTxns: txns,
        month: month,
        now: now ?? tenth,
      );

  PennyMood mood(Budget budget, List<Txn> txns) => status(budget, txns).mood;

  const budget = Budget(everydayPaise: 900000); // ₹9,000

  test('everyday spending leaves out what is paid in one go, and income', () {
    final month = status(Budget.none, [
      txn(400, on(2)),
      txn(150, on(3), categoryId: 'travel'),
      txn(8000, on(1), categoryId: 'rent'),
      txn(299, on(4), categoryId: 'subscriptions'),
      txn(15000, on(1), type: TxnType.credit, categoryId: 'pocket_money'),
    ]);
    expect(month.everydaySpentPaise, 55000);
    expect(month.spentIn('rent'), 800000);
    expect(month.spentIn('pocket_money'), 0);
    expect(month.daysLeft, 20);
  });

  test('no budget at all leaves Penny neutral', () {
    expect(mood(Budget.none, [txn(5000, on(2))]), PennyMood.neutral);
  });

  test('at or under the pace is happy, ahead of it neutral', () {
    // A third of ₹9,000 is ₹3,000.
    expect(mood(budget, [txn(3000, on(4))]), PennyMood.happy);
    expect(mood(budget, [txn(3001, on(4))]), PennyMood.neutral);
    expect(mood(budget, const []), PennyMood.happy);
  });

  test('85% of the budget is worried, over it sad', () {
    expect(mood(budget, [txn(7649, on(4))]), PennyMood.neutral);
    expect(mood(budget, [txn(7650, on(4))]), PennyMood.worried);
    expect(mood(budget, [txn(9001, on(4))]), PennyMood.sad);
  });

  test('a cap near its limit worries Penny, over it saddens her', () {
    const caps = Budget(everydayPaise: 900000, caps: {'food': 200000});
    expect(mood(caps, [txn(1700, on(4))]), PennyMood.worried);
    expect(mood(caps, [txn(2001, on(4))]), PennyMood.sad);
    // Caps alone, all well under: happy.
    expect(
      mood(const Budget(caps: {'food': 200000}), [txn(500, on(4))]),
      PennyMood.happy,
    );
  });

  test('the cap behind the mood is named', () {
    const caps = Budget(caps: {'food': 200000, 'fun': 100000, 'rent': 800000});
    expect(status(caps, [txn(500, on(4))]).capNote, isNull);
    expect(status(caps, [txn(1800, on(4))]).capNote, 'Food is near its cap');
    expect(
      status(caps, [
        txn(1800, on(4)),
        txn(1200, on(5), categoryId: 'fun'),
      ]).capNote,
      'Fun is over its cap',
    );
    // Rent at its cap is no worry.
    expect(
      status(caps, [txn(8000, on(1), categoryId: 'rent')]).capNote,
      isNull,
    );
  });

  test('rent using its whole cap is fine; only going over it counts', () {
    const caps = Budget(everydayPaise: 900000, caps: {'rent': 800000});
    expect(mood(caps, [txn(8000, on(1), categoryId: 'rent')]), PennyMood.happy);
    expect(mood(caps, [txn(8500, on(1), categoryId: 'rent')]), PennyMood.sad);
  });

  test('a month that is over counts every day', () {
    final done = status(budget, [
      txn(8000, on(29)),
    ], now: DateTime(2026, 12, 3));
    expect(done.day, 30);
    expect(done.daysLeft, 0);
    expect(done.mood, PennyMood.worried);
  });

  test('days left read naturally', () {
    expect(daysLeftLabel(18), '18 days left');
    expect(daysLeftLabel(1), '1 day left');
    expect(daysLeftLabel(0), 'Last day');
  });
}

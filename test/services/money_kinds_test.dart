import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/budget.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/merchant_categories.dart';
import 'package:penny/services/money_kinds.dart';

import '../helpers/txn_factory.dart';

void main() {
  final at = DateTime(2026, 11, 4, 12);

  test('every entry is one of four kinds', () {
    const debit = TxnType.debit;
    const credit = TxnType.credit;
    expect(MoneyKind.of(debit, 'food'), MoneyKind.spent);
    expect(MoneyKind.of(debit, 'rent'), MoneyKind.spent);
    expect(MoneyKind.of(debit, 'invest'), MoneyKind.invested);
    expect(MoneyKind.of(credit, 'salary'), MoneyKind.got);
    expect(MoneyKind.of(credit, 'food'), MoneyKind.paidBack);
    expect(MoneyKind.of(credit, 'other'), MoneyKind.paidBack);
    // Nothing comes back from investing; money in from there is money in.
    expect(MoneyKind.of(credit, 'invest'), MoneyKind.got);
    // A category from a newer version goes by its direction.
    expect(MoneyKind.of(debit, 'pets'), MoneyKind.spent);
    expect(MoneyKind.of(credit, 'pets'), MoneyKind.got);
  });

  test('one table of entries gives every total', () {
    final totals = MoneyTotals.of([
      txn(900, at), // Dinner for three.
      txn(600, at, type: TxnType.credit), // Two friends paid their share.
      txn(200, at, categoryId: 'travel'),
      txn(500, at, type: TxnType.credit, categoryId: 'travel'), // More back.
      txn(1000, at, categoryId: 'invest'),
      txn(15000, at, type: TxnType.credit, categoryId: 'pocket_money'),
    ]);

    expect(totals.spentIn('food'), 30000);
    // Never below zero.
    expect(totals.spentIn('travel'), 0);
    expect(totals.spentPaise, 30000);
    expect(totals.paidBackPaise, 110000);
    expect(totals.gotPaise, 1500000);
    expect(totals.investedPaise, 100000);
    // Everything in, less everything out: the extra ₹300 back is money left.
    expect(totals.leftPaise, 1500000 + 110000 - 110000 - 100000);
    expect(totals.spentByCategory, {'food': 30000, 'travel': 0});
  });

  test('category totals: net spending, income and what was put away', () {
    final totals = categoryTotalsOf([
      (type: TxnType.debit, categoryId: 'food', paise: 90000, count: 3),
      (type: TxnType.credit, categoryId: 'food', paise: 60000, count: 2),
      (type: TxnType.credit, categoryId: 'fun', paise: 20000, count: 1),
      (type: TxnType.debit, categoryId: 'invest', paise: 100000, count: 1),
      (type: TxnType.credit, categoryId: 'salary', paise: 500000, count: 1),
    ]);

    expect(
      [
        for (final t in totals)
          '${t.kind.name} ${t.categoryId} ${t.totalPaise} ${t.count} '
              '${t.paidBackPaise}',
      ],
      [
        'got salary 500000 1 0',
        'invested invest 100000 1 0',
        'spent food 30000 3 60000',
        // Only paid back so far this month.
        'spent fun 0 0 20000',
      ],
    );
  });

  test('a payback says what it was for', () {
    expect(kindLabel(TxnType.credit, 'food'), 'Food · paid back');
    expect(kindLabel(TxnType.debit, 'food'), 'Food');
    expect(kindLabel(TxnType.debit, 'invest'), 'Mutual funds & SIP');
    expect(kindLabel(TxnType.credit, 'salary'), 'Salary/stipend');
  });

  test('investing is a tile of its own, never a spend category', () {
    final tiles = categoriesFor(TxnType.debit);
    expect(tiles.map((c) => c.id), contains('invest'));
    expect(tiles.last.id, 'other');
    expect(isSpendCategory('invest'), isFalse);
    expect(spendCategories.map((c) => c.id), isNot(contains('invest')));
    expect(categoryById('invest').label, 'Mutual funds & SIP');
  });

  test('investing apps and SIPs are recognised, each kind apart', () {
    final cases = {
      'GROWW': 'invest',
      'INDmoney': 'invest',
      'Kuvera': 'invest',
      'Zerodha Coin': 'invest',
      'Zerodha Broking': 'stocks',
      'Upstox': 'stocks',
      'Angel One': 'stocks',
      'Fixed Deposit booking': 'deposits',
      'PPF Account': 'deposits',
    };
    for (final MapEntry(key: payee, value: category) in cases.entries) {
      expect(
        suggestCategory(type: TxnType.debit, text: '', payee: payee),
        category,
        reason: payee,
      );
    }
    expect(
      suggestCategory(
        type: TxnType.debit,
        text: 'Rs 1000 debited towards SIP of Axis Mutual Fund',
      ),
      'invest',
    );
    // Money back from a fund isn't a spend, so it gets no spend category.
    expect(
      suggestCategory(type: TxnType.credit, text: 'Groww redemption'),
      isNull,
    );
  });

  test('every kind of investing is put away, each a tile of its own', () {
    expect(MoneyKind.of(TxnType.debit, 'stocks'), MoneyKind.invested);
    expect(MoneyKind.of(TxnType.debit, 'deposits'), MoneyKind.invested);
    expect(isSpendCategory('stocks'), isFalse);
    expect(isInvestCategory('deposits'), isTrue);
    const sums = <CategorySum>[
      (type: TxnType.debit, categoryId: 'invest', paise: 100000, count: 1),
      (type: TxnType.debit, categoryId: 'stocks', paise: 50000, count: 2),
      (type: TxnType.debit, categoryId: 'deposits', paise: 20000, count: 1),
      (type: TxnType.credit, categoryId: 'salary', paise: 500000, count: 1),
    ];
    expect(
      [
        for (final total in categoryTotalsOf(sums))
          if (total.kind == MoneyKind.invested)
            (total.categoryId, total.totalPaise, total.count),
      ],
      [('invest', 100000, 1), ('stocks', 50000, 2), ('deposits', 20000, 1)],
    );
    final money = MoneyTotals.fromSums(sums);
    expect(money.investedPaise, 170000);
    expect(money.spentPaise, 0);
    expect(money.leftPaise, 330000);
  });

  test("Penny's guesses for the newer categories", () {
    final byPayee = {
      'Indian Oil': 'fuel',
      'HP Petrol Pump': 'fuel',
      'Indane Gas': 'home',
      'Pepperfry': 'home',
      'Looks Salon': 'care',
      'Cult.fit': 'care',
      'Bajaj Finserv': 'emi',
      'Temple Trust': 'gifts',
      'Ketto': 'gifts',
    };
    for (final MapEntry(key: payee, value: category) in byPayee.entries) {
      expect(
        suggestCategory(type: TxnType.debit, text: '', payee: payee),
        category,
        reason: payee,
      );
    }
    expect(
      suggestCategory(
        type: TxnType.debit,
        text: 'Rs.590 debited from A/c XX4821 for annual fee of your debit card',
      ),
      'charges',
    );
    expect(
      suggestCategory(
        type: TxnType.debit,
        text: 'Rs.5,000 debited from A/c XX4821 towards your loan EMI',
      ),
      'emi',
    );
    // A bill that mentions its charges is still a bill.
    expect(
      suggestCategory(
        type: TxnType.debit,
        text: 'Rs.1,240 paid for BESCOM electricity incl. charges',
      ),
      'bills',
    );
  });

  test('the everyday budget has Fuel, Home and Care in it, not EMIs', () {
    const budget = Budget(
      byCategory: {
        'fuel': 100000,
        'home': 50000,
        'care': 30000,
        'emi': 500000,
        'charges': 10000,
        'family': 300000,
      },
    );
    expect(budget.everydayPaise, 180000);
    expect(budget.oneGoPaise, 810000);
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/budget.dart';
import 'package:penny/models/month_insight.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/models/your_rules.dart';
import 'package:penny/services/insight_builder.dart';

import '../helpers/txn_factory.dart';

void main() {
  final october = DateTime(2026, 10);
  final afterOctober = DateTime(2026, 11, 5);

  InsightRequest build(
    List txns, {
    DateTime? now,
    DateTime? month,
    YourRules rules = YourRules.none,
    String? note,
  }) => buildInsightRequest(
    month: month ?? october,
    txns: txns.cast(),
    now: now ?? afterOctober,
    rules: rules,
    note: note,
  );

  Map<String, Object?> spendNamed(InsightRequest request, String? name) =>
      request.spends.firstWhere((s) => s['name'] == name);

  test('one group per shop and category, biggest first', () {
    final request = build([
      txn(300, DateTime(2026, 10, 2), merchant: 'swiggy'),
      txn(250, DateTime(2026, 10, 9), merchant: ' Swiggy  '),
      txn(120, DateTime(2026, 10, 3), merchant: 'Swiggy', categoryId: 'fun'),
      txn(900, DateTime(2026, 10, 4), categoryId: 'rent'),
      txn(80, DateTime(2026, 10, 5)),
      txn(40, DateTime(2026, 10, 6)),
    ]);

    expect(request.spends.map((s) => [s['id'], s['category'], s['total']]), [
      ['s1', 'rent', 900],
      ['s2', 'food', 550],
      ['s3', 'food', 120],
      ['s4', 'fun', 120],
    ]);
    final swiggy = request.spends[1];
    // Named as the latest entry spells it.
    expect(swiggy['name'], 'Swiggy');
    expect(swiggy['entries'], 2);
    expect(swiggy['biggest'], 300);
    // Food with no shop name: its own group, sent without a name.
    expect(request.spends[2]['name'], isNull);
    expect(request.groupKeys['s2'], ['shop|food|swiggy']);
    expect(request.groupKeys['s3'], ['cat|food']);
    expect(request.spendCount, 6);
  });

  test('people reach Penny only as aliases', () {
    final request = build([
      txn(
        500,
        DateTime(2026, 10, 2),
        merchant: 'Asha Rao',
        payeeIsPerson: true,
      ),
      // Typed by hand with no word Penny knows: it may be a person.
      txn(400, DateTime(2026, 10, 3), merchant: 'Vikram K'),
      // Typed, but a shop Penny knows, or a place.
      txn(300, DateTime(2026, 10, 4), merchant: 'Swiggy'),
      txn(200, DateTime(2026, 10, 5), merchant: 'Canteen'),
      // The SMS said it's a shop.
      txn(
        100,
        DateTime(2026, 10, 6),
        merchant: 'Sharma Sweets',
        payeeIsPerson: false,
      ),
      // Typed things and jobs: only the words Penny knows go along.
      txn(
        2000,
        DateTime(2026, 10, 7),
        categoryId: 'rent',
        merchant: 'For Cook',
      ),
      txn(
        1012,
        DateTime(2026, 10, 8),
        categoryId: 'shopping',
        merchant: 'Creatine',
      ),
      txn(
        150,
        DateTime(2026, 10, 9),
        categoryId: 'shopping',
        merchant: 'Gift for Priya',
      ),
    ]);

    expect(request.spends.map((s) => [s['name'], s['person']]), [
      ['Cook', false],
      ['Creatine', false],
      ['Person 1', true],
      ['Person 2', true],
      ['Swiggy', false],
      ['Canteen', false],
      ['Gift', false],
      ['Sharma Sweets', false],
    ]);
    final sent = jsonEncode(request.body).toLowerCase();
    expect(sent, isNot(contains('asha')));
    expect(sent, isNot(contains('vikram')));
    expect(sent, isNot(contains('priya')));
  });

  test('digits never ride along in a shop name', () {
    expect(cleanShopName('Shop 98765 43210'), 'Shop');
    expect(cleanShopName('D-Mart, HSR #12'), 'D-Mart HSR');
    expect(cleanShopName('12345'), isNull);
    expect(cleanShopName('A' * 40), hasLength(32));
  });

  test('past months show trends and repeats per group', () {
    DateTime on(int month) => DateTime(2026, month, 3);
    final request = build([
      for (final month in [7, 8, 9, 10])
        txn(649, on(month), merchant: 'Netflix', categoryId: 'subscriptions'),
      txn(1200, on(9), merchant: 'Swiggy'),
      txn(800, on(10), merchant: 'Swiggy'),
      txn(500, on(9), merchant: 'Zomato'),
    ]);

    final netflix = spendNamed(request, 'Netflix');
    expect(netflix['lastMonth'], 649);
    expect(netflix['monthsSeen'], 3);
    final swiggy = spendNamed(request, 'Swiggy');
    expect(swiggy['lastMonth'], 1200);
    expect(swiggy['monthsSeen'], 1);
    // Zomato had no spend in October, so it isn't a group.
    expect(request.spends.where((s) => s['name'] == 'Zomato'), isEmpty);
    expect(request.body['lastMonth'], {'spent': 2349, 'got': 0});
  });

  test('small shops beyond the top 28 join their category', () {
    final request = build([
      for (var i = 1; i <= 35; i++)
        txn(1000 - i, DateTime(2026, 10, 1 + i % 28), merchant: 'Shop $i'),
    ]);

    // 28 named shops plus one food group for the rest.
    expect(request.spends, hasLength(29));
    final rest = request.spends.firstWhere((s) => s['name'] == null);
    expect(rest['entries'], 7);
    final restId = rest['id']! as String;
    expect(request.groupKeys[restId], contains('shop|food|shop 35'));
    expect(request.groupKeys[restId], contains('cat|food'));
  });

  test('income goes by category only, with how steady it is', () {
    final request = build([
      for (var month = 5; month <= 10; month++) ...[
        txn(
          5000,
          DateTime(2026, month, 1),
          type: TxnType.credit,
          categoryId: 'pocket_money',
          merchant: 'Papa',
        ),
        txn(100, DateTime(2026, month, 2)),
      ],
      txn(
        2000,
        DateTime(2026, 10, 9),
        type: TxnType.credit,
        categoryId: 'freelance',
        merchant: 'Acme Labs Pvt Ltd',
      ),
    ]);

    expect(request.income, [
      {
        'id': 'i1',
        'category': 'pocket_money',
        'entries': 1,
        'total': 5000,
        'monthsWithIncome': 6,
        'monthsTracked': 6,
        'steadiness': 'steady',
      },
      {
        'id': 'i2',
        'category': 'freelance',
        'entries': 1,
        'total': 2000,
        'monthsWithIncome': 1,
        'monthsTracked': 6,
        'steadiness': 'now_and_then',
      },
    ]);
    expect(jsonEncode(request.body), isNot(contains('Papa')));
    expect(request.body['got'], 7000);
  });

  test('steadiness needs three months of data', () {
    expect(steadinessOf(2, 2), Steadiness.tooEarly);
    expect(steadinessOf(3, 3), Steadiness.steady);
    expect(steadinessOf(4, 6), Steadiness.mostMonths);
    expect(steadinessOf(3, 6), Steadiness.nowAndThen);
  });

  test('a month in progress says how far in it is', () {
    final spends = [
      for (var day = 1; day <= 3; day++) txn(100, DateTime(2026, 11, day)),
    ];
    final current = build(
      spends,
      month: DateTime(2026, 11),
      now: DateTime(2026, 11, 3, 18),
    );
    expect(current.body['monthComplete'], isFalse);
    expect(current.body['daysCounted'], 3);

    final done = build(
      spends,
      month: DateTime(2026, 11),
      now: DateTime(2026, 12, 1),
    );
    expect(done.body['monthComplete'], isTrue);
    expect(done.body['daysCounted'], 30);
  });

  test('the fingerprint follows the money, not tags or the date', () {
    final base = [
      txn(300, DateTime(2026, 10, 2), merchant: 'Swiggy'),
      txn(900, DateTime(2026, 10, 4), categoryId: 'rent'),
      txn(80, DateTime(2026, 10, 5)),
    ];
    final first = build(base);

    expect(build(base).inputHash, first.inputHash);
    // Asked mid-month, then again once it's over.
    expect(build(base, now: DateTime(2026, 10, 20)).inputHash, first.inputHash);
    final tagged = [
      ...base.take(2),
      txn(80, DateTime(2026, 10, 5), tag: TxnTag.necessary),
    ];
    expect(build(tagged).inputHash, first.inputHash);
    final changed = [...base.take(2), txn(85, DateTime(2026, 10, 5))];
    expect(build(changed).inputHash, isNot(first.inputHash));
  });

  test('your own tag is sent when the whole group shares it', () {
    final request = build([
      txn(
        300,
        DateTime(2026, 10, 2),
        merchant: 'Swiggy',
        tag: TxnTag.necessary,
      ),
      txn(
        200,
        DateTime(2026, 10, 3),
        merchant: 'Swiggy',
        tag: TxnTag.necessary,
      ),
      txn(150, DateTime(2026, 10, 4), merchant: 'Zomato', tag: TxnTag.wasteful),
      txn(100, DateTime(2026, 10, 5), merchant: 'Zomato'),
    ]);
    expect(spendNamed(request, 'Swiggy')['yourTag'], 'necessary');
    expect(spendNamed(request, 'Zomato')['yourTag'], isNull);
  });

  test('My needs rules settle a group before Penny sees it', () {
    final txns = [
      txn(300, DateTime(2026, 10, 2), merchant: 'Swiggy'),
      txn(200, DateTime(2026, 10, 3), merchant: 'Swiggy'),
      txn(900, DateTime(2026, 10, 4), categoryId: 'rent'),
      txn(150, DateTime(2026, 10, 5), merchant: 'Zomato'),
      txn(
        100,
        DateTime(2026, 10, 6),
        merchant: 'Zomato',
        tag: TxnTag.necessary,
      ),
    ];
    const rules = YourRules(
      categories: {'rent': TxnTag.necessary, 'food': TxnTag.wasteful},
      shops: {'swiggy': TxnTag.necessary},
    );
    final request = build(txns, rules: rules);

    expect(spendNamed(request, 'Swiggy')['yourTag'], 'necessary');
    expect(spendNamed(request, null)['yourTag'], 'necessary'); // rent
    // One Zomato order is the user's own need, the other a food rule's
    // waste: no single call for the group.
    expect(spendNamed(request, 'Zomato')['yourTag'], isNull);
    // Rules are the user's calls, not money, so they don't change the
    // fingerprint.
    expect(request.inputHash, build(txns).inputHash);
  });

  test('the note goes along, and a new note means a new look', () {
    final txns = [
      txn(300, DateTime(2026, 10, 2), merchant: 'Swiggy'),
      txn(900, DateTime(2026, 10, 4), categoryId: 'rent'),
      txn(80, DateTime(2026, 10, 5)),
    ];
    final plain = build(txns);
    expect(plain.body.containsKey('note'), isFalse);
    expect(build(txns, note: '   ').body.containsKey('note'), isFalse);

    final noted = build(txns, note: '  Student in a PG  ');
    expect(noted.body['note'], 'Student in a PG');
    expect(noted.inputHash, isNot(plain.inputHash));
  });

  test('the budget goes along in rupees, and a new one means a new look', () {
    final txns = [
      txn(300, DateTime(2026, 10, 2), merchant: 'Swiggy'),
      txn(900, DateTime(2026, 10, 4), categoryId: 'rent'),
      txn(80, DateTime(2026, 10, 5)),
    ];
    InsightRequest withBudget(Budget budget) => buildInsightRequest(
      month: october,
      txns: txns,
      now: afterOctober,
      budget: budget,
    );
    final plain = build(txns);
    expect(plain.body.containsKey('budget'), isFalse);

    final budgeted = withBudget(
      const Budget(byCategory: {'rent': 900000, 'food': 300040, 'fun': 100000}),
    );
    // Each category's amount as a cap, in the categories' own order, and
    // the everyday part of their total as the everyday budget.
    expect(budgeted.body['budget'], {
      'everyday': 4000,
      'caps': [
        {'category': 'food', 'cap': 3000},
        {'category': 'rent', 'cap': 9000},
        {'category': 'fun', 'cap': 1000},
      ],
    });
    expect(budgeted.inputHash, isNot(plain.inputHash));
    // Only rent: nothing everyday, and a budget of paise is still a rupee.
    expect(withBudget(const Budget(byCategory: {'rent': 40})).body['budget'], {
      'everyday': null,
      'caps': [
        {'category': 'rent', 'cap': 1},
      ],
    });
  });

  test('paybacks and investing go as totals, never as groups', () {
    final plain = [
      txn(900, DateTime(2026, 10, 2), merchant: 'Pizza Hut'),
      txn(
        15000,
        DateTime(2026, 10, 1),
        type: TxnType.credit,
        categoryId: 'pocket_money',
      ),
    ];
    final request = build([
      ...plain,
      txn(
        600,
        DateTime(2026, 10, 3),
        type: TxnType.credit,
        merchant: 'Asha Rao',
        payeeIsPerson: true,
      ),
      txn(
        1000,
        DateTime(2026, 10, 5),
        categoryId: 'invest',
        merchant: 'Groww SIP',
      ),
      // Last month: ₹500 spent, ₹200 of it back.
      txn(500, DateTime(2026, 9, 9)),
      txn(200, DateTime(2026, 9, 12), type: TxnType.credit),
    ]);

    // Spent and got as Home counts them.
    expect(request.body['spent'], 300);
    expect(request.body['got'], 15000);
    expect(request.body['lastMonth'], {'spent': 300, 'got': 0});
    expect(request.body['paidBack'], [
      {'category': 'food', 'total': 600},
    ]);
    expect(request.body['invested'], 1000);
    // The spend group is what was paid; investing and paybacks are no group.
    expect(request.spends.single['total'], 900);
    expect(request.income.single['category'], 'pocket_money');
    expect(request.spendCount, 1);
    final sent = jsonEncode(request.body);
    expect(sent, isNot(contains('Asha')));
    expect(sent, isNot(contains('Groww')));

    // A month without either is sent just as before.
    final before = build(plain);
    expect(before.body.containsKey('paidBack'), isFalse);
    expect(before.body.containsKey('invested'), isFalse);
  });

  test('Penny needs three spends before you can ask', () {
    final two = [
      txn(100, DateTime(2026, 10, 1)),
      txn(100, DateTime(2026, 10, 2)),
      txn(5000, DateTime(2026, 10, 3), type: TxnType.credit),
    ];
    expect(build(two).canAsk, isFalse);
    expect(build([...two, txn(100, DateTime(2026, 10, 4))]).canAsk, isTrue);
  });

  test('entries outside the six months are ignored', () {
    final request = build([
      txn(100, DateTime(2026, 4, 30), merchant: 'Swiggy'),
      txn(100, DateTime(2026, 11, 1), merchant: 'Swiggy'),
      txn(100, DateTime(2026, 10, 31, 23, 59), merchant: 'Swiggy'),
    ]);
    expect(request.spends.single['entries'], 1);
    expect(insightHistoryStart(october), DateTime(2026, 5));
  });
}
